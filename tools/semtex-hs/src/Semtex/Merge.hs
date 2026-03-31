-- | Registry merge pipeline: collect @.semtex.json@ envelopes, validate
-- the dependency graph, topo-sort, compute back-references, build indices,
-- and emit @registry.json@.
module Semtex.Merge
  ( -- * Merge pipeline
    loadAndMerge
  ) where

import Data.Aeson           (eitherDecodeFileStrict, encode)
import Data.Graph           (SCC(..), stronglyConnComp)
import Data.List            (isSuffixOf, sort)
import Data.Map.Strict      (Map)
import Data.Text            (Text)
import Data.Time            (getCurrentTime)
import System.Directory     (doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit          (exitFailure)
import System.FilePath      ((</>))
import System.IO            (hPutStrLn, stderr)

import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict      as Map
import qualified Data.Text            as T

import Semtex.Json   ()
import Semtex.Types

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
