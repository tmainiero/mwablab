-- | Registry merge pipeline: collect @.semtex.json@ envelopes, validate
-- the dependency graph, topo-sort, compute back-references, build indices,
-- and emit @registry.json@.
--
-- v2 adds atom-level merging with UIDs, symbol tracking, and auto-inferred
-- dependencies alongside the legacy concept pipeline.
module Semtex.Merge
  ( -- * Merge pipeline (v1)
    loadAndMerge
    -- * Merge pipeline (v2 atoms)
  , mergeAtoms
  ) where

import Data.Aeson           (eitherDecodeFileStrict, encode)
import Data.Graph           (SCC(..), stronglyConnComp)
import Data.List            (isSuffixOf, sort)
import Data.Map.Strict      (Map)
import Data.Set             (Set)
import Data.Text            (Text)
import Data.Time            (getCurrentTime)
import System.Directory     (doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit          (exitFailure)
import System.FilePath      ((</>))
import System.IO            (hPutStrLn, stderr)

import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict      as Map
import qualified Data.Set             as Set
import qualified Data.Text            as T

import Semtex.Json   ()
import Semtex.Types
import Semtex.Uid           (assignUids, initialUid)
import Semtex.SymbolTrack   (buildSymbolTable,
                             scanUsages, inferDependencies, validateSymbols)

-- ---------------------------------------------------------------------------
-- Public entry point
-- ---------------------------------------------------------------------------

-- | Run the full merge pipeline for @dir@.
--
-- Recursively discovers all @.semtex.json@ files under @dir@, decodes them
-- as 'Envelope' values, validates the dependency graph, topologically sorts
-- the concept DAG, computes back-references, builds auxiliary indices, and
-- writes @registry.json@ to @dir@.  Progress and errors are printed to
-- @stdout@ and @stderr@ respectively.  Calls 'exitFailure' on any fatal
-- error (missing dependency target or cycle in the dependency graph).
loadAndMerge :: FilePath -> IO ()
loadAndMerge dir = do
  -- 1. Discover files.
  files <- findSemtexFiles dir

  -- 2. Load envelopes.
  envelopes <- traverse loadEnvelope files

  -- 3. Collect concepts; warn on duplicates (last writer wins).
  let allPairs :: [(ConceptId, Concept)]
      allPairs =
        concatMap
          (\e -> map (\c -> (conceptId c, c)) (envelopeConcepts e))
          envelopes

  concepts <- buildConceptMap allPairs

  -- 4. Validate dependency targets.
  let missingDeps :: [(ConceptId, ConceptId)]
      missingDeps =
        [ (cid, dep)
        | (cid, c) <- Map.toList concepts
        , dep      <- conceptDepends c
        , not (Map.member dep concepts)
        ]

  mapM_ (\(cid, dep) ->
    hPutStrLn stderr
      (  "error: concept '"
      ++ T.unpack cid
      ++ "' depends on unknown '"
      ++ T.unpack dep
      ++ "'"
      )
    ) missingDeps

  -- 5. Topological sort with cycle detection.
  --    'stronglyConnComp' returns SCCs in reverse topological order
  --    (dependents before dependencies).  Reversing the AcyclicSCC nodes
  --    gives dependency-first order, matching Python post-order DFS output.
  let sccs :: [SCC ConceptId]
      sccs =
        stronglyConnComp
          [ (cid, cid, conceptDepends c)
          | (cid, c) <- Map.toList concepts
          ]

      cycles :: [[ConceptId]]
      cycles = [ns | CyclicSCC ns <- sccs]

      topoOrder :: [ConceptId]
      topoOrder = [n | AcyclicSCC n <- sccs]

  mapM_ (\ns -> case ns of
    []    -> pure ()
    (n:_) -> hPutStrLn stderr
               ("error: cycle detected involving '" ++ T.unpack n ++ "'")
    ) cycles

  -- 6. Exit on any fatal error.
  if not (null missingDeps) || not (null cycles)
    then exitFailure
    else pure ()

  -- 7. Compute back-references.
  --    backRefMap.(dep) = list of concepts that depend on dep.
  let backRefMap :: Map ConceptId [ConceptId]
      backRefMap =
        Map.fromListWith (++)
          [ (dep, [cid])
          | (cid, c) <- Map.toList concepts
          , dep      <- conceptDepends c
          , Map.member dep concepts
          ]

      conceptsWithBackRefs :: Map ConceptId Concept
      conceptsWithBackRefs =
        Map.mapWithKey
          (\cid c -> c { conceptBackRefs = Map.findWithDefault [] cid backRefMap })
          concepts

  -- 8. Build indices.
  --    For stacks and nlab indices, last writer wins when a tag is cited by
  --    more than one concept (same policy as the Python implementation).
  let stacksIndex :: Map Tag ConceptId
      stacksIndex =
        Map.fromList
          [ (tag, cid)
          | (cid, c) <- Map.toList conceptsWithBackRefs
          , tag      <- conceptStacksRefs c
          ]

      nlabIndex :: Map Tag ConceptId
      nlabIndex =
        Map.fromList
          [ (tag, cid)
          | (cid, c) <- Map.toList conceptsWithBackRefs
          , tag      <- conceptNlabRefs c
          ]

      symbolTable :: Map Text SymbolEntry
      symbolTable =
        Map.fromList
          [ ( conceptName c
            , SymbolEntry
                { symConcept = conceptId c
                , symLangs   = conceptImplements c
                }
            )
          | c <- Map.elems conceptsWithBackRefs
          ]

      dependencyDag :: Map ConceptId [ConceptId]
      dependencyDag = Map.map conceptDepends conceptsWithBackRefs

  -- 9. Build registry and write to disk.
  now <- getCurrentTime
  let registry :: Registry
      registry = Registry
        { regVersion       = 1
        , regGenerated     = now
        , regConcepts      = conceptsWithBackRefs
        , regDependencyDag = dependencyDag
        , regTopoOrder     = topoOrder
        , regStacksIndex   = stacksIndex
        , regNlabIndex     = nlabIndex
        , regSymbolTable   = symbolTable
        }
      outPath :: FilePath
      outPath = dir </> "registry.json"

  BL.writeFile outPath (encode registry)

  -- 10. Print summary.
  putStrLn
    (  "  registry: "
    ++ outPath
    ++ " ("
    ++ show (Map.size conceptsWithBackRefs)
    ++ " concepts, "
    ++ show (length topoOrder)
    ++ " in topo order)"
    )

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- | Recursively walk @dir@, collecting all files whose names end in
-- @\".semtex.json\"@, returning paths sorted lexicographically.
--
-- Uses only 'System.Directory' primitives; no additional packages are needed.
findSemtexFiles :: FilePath -> IO [FilePath]
findSemtexFiles top = fmap sort (go top)
  where
    go :: FilePath -> IO [FilePath]
    go d = do
      entries <- listDirectory d
      fmap concat (mapM (processEntry d) entries)

    processEntry :: FilePath -> String -> IO [FilePath]
    processEntry d name = do
      let path = d </> name
      isDir  <- doesDirectoryExist path
      isFile <- doesFileExist       path
      if isDir
        then go path
        else if isFile && ".semtex.json" `isSuffixOf` name
          then pure [path]
          else pure []

-- | Decode a single @.semtex.json@ file as an 'Envelope'.
--
-- Uses 'eitherDecodeFileStrict', which reads the file into a strict
-- 'Data.ByteString.ByteString' before parsing.  On failure, the error
-- message is printed to @stderr@ and 'exitFailure' is called.
loadEnvelope :: FilePath -> IO Envelope
loadEnvelope path = do
  result <- eitherDecodeFileStrict path
  case result of
    Left err -> do
      hPutStrLn stderr ("error: could not parse '" ++ path ++ "': " ++ err)
      exitFailure
    Right envelope -> pure envelope

-- | Build a 'Map' from a flat association list, printing a @stderr@ warning
-- for each 'ConceptId' that appears more than once.  The last occurrence of
-- a duplicate key is kept (last-writer-wins), which matches the Python
-- reference implementation.
buildConceptMap :: [(ConceptId, Concept)] -> IO (Map ConceptId Concept)
buildConceptMap pairs = do
  -- Detect which IDs appear more than once.
  let occurrences :: Map ConceptId [FilePath]
      occurrences =
        Map.fromListWith (++) [(cid, [conceptFile c]) | (cid, c) <- pairs]

  mapM_ (\(cid, fps) ->
    hPutStrLn stderr
      ("warning: duplicate concept '" ++ T.unpack cid ++ "' in " ++ lastOf fps)
    )
    [(cid, fps) | (cid, fps) <- Map.toList occurrences, length fps > 1]

  -- Build the map from the reversed list so that Map.fromList retains the
  -- first entry it sees, which corresponds to the last occurrence in the
  -- original list (last-writer-wins).
  pure (Map.fromList (reverse pairs))

-- | Return the last element of a non-empty list, or the empty string if the
-- list is empty.  Used for reporting the file path of the latest duplicate.
lastOf :: [String] -> String
lastOf []     = ""
lastOf [x]    = x
lastOf (_:xs) = lastOf xs

-- ---------------------------------------------------------------------------
-- v2 atom-level merge
-- ---------------------------------------------------------------------------

-- | Merge a list of atoms into a v2 registry.
--
-- Steps:
--   1. Assign UIDs to atoms that don't have one.
--   2. Build the symbol table.
--   3. Scan for symbol usages.
--   4. Infer dependency edges.
--   5. Validate (newmath on type macros, duplicate instances).
--   6. Compute back-references.
--   7. Topological sort.
--   8. Build and write the registry.
mergeAtoms
  :: FilePath          -- ^ Output directory for registry.json
  -> Set Text          -- ^ Known type macro names
  -> Set Text          -- ^ Known instance macro names
  -> Maybe RegistryV2  -- ^ Previous registry (for UID continuity)
  -> [Atom]            -- ^ All atoms from all files
  -> IO RegistryV2
mergeAtoms outDir typeMacros instanceNames mPrevReg atoms = do
  -- 1. Assign UIDs.
  let startUid = case mPrevReg of
        Just prev -> reg2NextUid prev
        Nothing   -> initialUid
  let (nextUidVal, atomsWithUids) = assignUids startUid atoms

  -- 2. Build symbol table.
  let symTable = buildSymbolTable typeMacros instanceNames atomsWithUids

  -- 3. Scan usages.
  let atomsWithUsages = scanUsages instanceNames atomsWithUids

  -- 4. Validate.
  let errors = validateSymbols typeMacros atomsWithUsages
  mapM_ (\err -> hPutStrLn stderr ("error: " ++ show err)) errors
  if not (null errors)
    then do
      hPutStrLn stderr "fatal: symbol validation errors, aborting"
      exitFailure
    else pure ()

  -- 5. Infer dependencies.
  let depEdges = inferDependencies symTable atomsWithUsages

  -- 6. Compute back-references.
  let backRefs :: Map Uid [Uid]
      backRefs = Map.fromListWith (++)
        [ (dep, [uid])
        | (uid, deps) <- Map.toList depEdges
        , dep <- deps
        ]

  let atomsWithBackRefs = map (\a ->
        case atomUid a of
          Just uid -> a { atomBackRefs = Map.findWithDefault [] uid backRefs }
          Nothing  -> a
        ) atomsWithUsages

  -- 7. Topological sort on atom UIDs.
  let sccs = stronglyConnComp
        [ (uid, uid, deps)
        | a <- atomsWithBackRefs
        , Just uid <- [atomUid a]
        , let deps = Map.findWithDefault [] uid depEdges
        ]
      topoOrder = [n | AcyclicSCC n <- sccs]
      atomCycles = [ns | CyclicSCC ns <- sccs]

  mapM_ (\ns -> case ns of
    [] -> pure ()
    (Uid n : _) -> hPutStrLn stderr
      ("warning: cycle in atom deps involving '" ++ T.unpack n ++ "'")
    ) atomCycles

  -- 8. Build atom map.
  let atomMap :: Map Uid Atom
      atomMap = Map.fromList
        [ (uid, a)
        | a <- atomsWithBackRefs
        , Just uid <- [atomUid a]
        ]

  -- 9. Build stacks/nlab indices at atom level.
  let stacksIdx = Map.fromList
        [ (tag, uid)
        | a <- atomsWithBackRefs
        , Just uid <- [atomUid a]
        , tag <- atomStacksRefs a
        ]
      nlabIdx = Map.fromList
        [ (tag, uid)
        | a <- atomsWithBackRefs
        , Just uid <- [atomUid a]
        , tag <- atomNlabRefs a
        ]

  -- 10. Build legacy concept structures for backward compat.
  let conceptDag = Map.empty  -- TODO: extract from concept-level deps
      conceptMap = Map.empty  -- TODO: rebuild from atoms
      imMap = Map.fromList
        [ (imName im, im)
        | name <- Set.toList instanceNames
        , let im = InstanceMacro name Nothing "" Nothing
        ]

  now <- getCurrentTime
  let registry = RegistryV2
        { reg2Version = 2
        , reg2Generated = now
        , reg2NextUid = nextUidVal
        , reg2Atoms = atomMap
        , reg2Concepts = conceptMap
        , reg2InstanceMacros = imMap
        , reg2TypeMacros = typeMacros
        , reg2SymbolDeps = depEdges
        , reg2BackRefs = backRefs
        , reg2ConceptDag = conceptDag
        , reg2TopoOrder = topoOrder
        , reg2StacksIndex = stacksIdx
        , reg2NlabIndex = nlabIdx
        }

  -- Write registry.
  let regPath = outDir </> "registry.json"
  BL.writeFile regPath (encode registry)
  putStrLn ("  registry v2: " ++ regPath
            ++ " (" ++ show (Map.size atomMap) ++ " atoms, "
            ++ show (length topoOrder) ++ " in topo order)")

  pure registry
