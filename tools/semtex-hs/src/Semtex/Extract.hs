-- | TeX file extraction for the semtex semantic preprocessor.
--
-- Reads a @.tex@ file line-by-line with a state machine and produces an
-- 'Envelope' containing all 'Concept' records found in that file.  The
-- approach mirrors @extract_file@ and @cmd_extract@ in the Python reference
-- implementation.
--
-- Each @\\concept{id}{Name}@ line opens a new concept block.  Subsequent
-- lines within the block contribute metadata via the macro vocabulary defined
-- in @src/spec/preamble.tex@.  A new @\\concept@ (or end-of-file) closes
-- the current block and starts the next.
{-# OPTIONS_GHC -Wall -Wcompat #-}

module Semtex.Extract
  ( -- * Extraction
    extractFile
  , extractFiles
  ) where

import Data.List            (foldl')
import Data.Map.Strict      (Map)
import Data.Text            (Text)
import System.Directory     (doesFileExist)
import System.FilePath      (replaceExtension)
import System.IO            (hPutStrLn, stderr)

import qualified Data.Aeson              as Aeson
import qualified Data.ByteString.Lazy    as BSL
import qualified Data.Map.Strict         as Map
import qualified Data.Text               as T
import qualified Data.Text.IO            as TIO

import Semtex.Extract.Parser
  ( extractAxiom
  , extractConcept
  , extractDepends
  , extractImplements
  , extractLabel
  , extractNewMath
  , extractNewTerm
  , extractNlabRef
  , extractStacksRef
  , extractUses
  )
import Semtex.Json  ()
import Semtex.Types (Concept(..), Envelope(..))

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

-- | Accumulates metadata for the concept block currently being parsed.
data ConceptBuilder = ConceptBuilder
  { cbId         :: !Text
  , cbName       :: !Text
  , cbFile       :: !FilePath
  , cbDepends    :: ![Text]
  , cbUses       :: ![Text]
  , cbAxioms     :: ![Text]
  , cbImplements :: !(Map Text [Text])
  , cbStacksRefs :: ![Text]
  , cbNlabRefs   :: ![Text]
  , cbTerms      :: ![Text]
  , cbSymbols    :: ![Text]
  , cbLabels     :: ![Text]
  }

-- | Top-level state threaded through the line-by-line fold.
data ExtractState = ExtractState
  { esCurrent   :: !(Maybe ConceptBuilder)
    -- ^ The concept block currently being parsed, if any.
  , esCompleted :: ![Concept]
    -- ^ Fully-built concepts accumulated in reverse source order.
  }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- | Append @new@ items to @existing@, skipping any already present.
-- Preserves insertion order and matches the Python dedup behaviour.
appendUnique :: Eq a => [a] -> [a] -> [a]
appendUnique existing new = existing ++ filter (`notElem` existing) new

-- | Fold a list of @(lang, mod)@ pairs into the implements map, appending
-- each module only if it is not already listed for that language.
insertImplements :: Map Text [Text] -> [(Text, Text)] -> Map Text [Text]
insertImplements = foldl' go
  where
    go m (lang, modName) =
      Map.insertWith (\_ old -> appendUnique old [modName]) lang [modName] m

-- ---------------------------------------------------------------------------
-- State-machine transitions
-- ---------------------------------------------------------------------------

-- | Convert a completed 'ConceptBuilder' into a 'Concept'.
-- 'conceptBackRefs' is left empty; it is populated later by the Merge pass.
finalize :: ConceptBuilder -> Concept
finalize cb = Concept
  { conceptId         = cbId         cb
  , conceptName       = cbName       cb
  , conceptFile       = cbFile       cb
  , conceptDepends    = cbDepends    cb
  , conceptUses       = cbUses       cb
  , conceptAxioms     = cbAxioms     cb
  , conceptImplements = cbImplements cb
  , conceptStacksRefs = cbStacksRefs cb
  , conceptNlabRefs   = cbNlabRefs   cb
  , conceptTerms      = cbTerms      cb
  , conceptSymbols    = cbSymbols    cb
  , conceptLabels     = cbLabels     cb
  , conceptBackRefs   = []
  }

-- | Process a single line, updating the extraction state.
--
-- Priority mirrors the Python implementation:
--
-- 1. If the line contains @\\concept@, close any open builder, push the
--    finalised concept to 'esCompleted', and open a fresh builder.
-- 2. If there is no open builder, skip the line.
-- 3. Otherwise apply all metadata extractors and fold results into the
--    current builder.
processLine :: FilePath -> ExtractState -> Text -> ExtractState
processLine fp st line =
  case extractConcept line of
    Just (cid, name) ->
      -- Close the current block (if any) and open a new one.
      let completed = case esCurrent st of
            Nothing -> esCompleted st
            Just cb -> finalize cb : esCompleted st
          fresh = ConceptBuilder
            { cbId         = cid
            , cbName       = name
            , cbFile       = fp
            , cbDepends    = []
            , cbUses       = []
            , cbAxioms     = []
            , cbImplements = Map.empty
            , cbStacksRefs = []
            , cbNlabRefs   = []
            , cbTerms      = []
            , cbSymbols    = []
            , cbLabels     = []
            }
      in ExtractState (Just fresh) completed

    Nothing ->
      case esCurrent st of
        Nothing -> st   -- no open block; ignore the line
        Just cb ->
          let -- Labels: filter out concept: and axiom: prefixes
              rawLabels = extractLabel line
              newLabels = filter (\l ->
                    not (T.isPrefixOf "concept:" l)
                 && not (T.isPrefixOf "axiom:"   l)) rawLabels
              cb' = cb
                { cbDepends    = appendUnique (cbDepends    cb) (extractDepends    line)
                , cbUses       = appendUnique (cbUses       cb) (extractUses       line)
                , cbAxioms     = appendUnique (cbAxioms     cb) (extractAxiom      line)
                , cbImplements = insertImplements (cbImplements cb) (extractImplements line)
                , cbStacksRefs = appendUnique (cbStacksRefs cb) (extractStacksRef  line)
                , cbNlabRefs   = appendUnique (cbNlabRefs   cb) (extractNlabRef    line)
                , cbTerms      = appendUnique (cbTerms      cb) (extractNewTerm    line)
                , cbSymbols    = appendUnique (cbSymbols    cb) (extractNewMath    line)
                , cbLabels     = appendUnique (cbLabels     cb) newLabels
                }
          in st { esCurrent = Just cb' }

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- | Read a @.tex@ file and extract all concept metadata from it.
--
-- The file is processed line-by-line using 'processLine'.  The resulting
-- 'Envelope' lists concepts in source order.
--
-- __Example__:
--
-- > env <- extractFile "src/spec/category.tex"
-- > print (length (envelopeConcepts env))
extractFile :: FilePath -> IO Envelope
extractFile fp = do
  content <- TIO.readFile fp
  let ls      = T.lines content
      initial = ExtractState Nothing []
      final   = foldl' (processLine fp) initial ls
      concepts = case esCurrent final of
        Nothing -> reverse (esCompleted final)
        Just cb -> reverse (finalize cb : esCompleted final)
  pure (Envelope fp concepts)

-- | Extract all given @.tex@ files, writing a @.semtex.json@ alongside each.
--
-- For each path:
--
-- * If the file does not exist, a warning is printed to stderr and the path
--   is skipped.
-- * Otherwise 'extractFile' is called, the 'Envelope' is serialised to JSON,
--   and the result is written to @\<stem\>.semtex.json@ in the same directory.
-- * A summary line @\"  extracted: \<path\> (\<n\> concepts)\"@ is printed to
--   stdout.
extractFiles :: [FilePath] -> IO ()
extractFiles fps = mapM_ go fps
  where
    go fp = do
      exists <- doesFileExist fp
      if not exists
        then hPutStrLn stderr ("semtex: warning: file not found: " ++ fp)
        else do
          env <- extractFile fp
          let outPath  = replaceExtension fp ".semtex.json"
              n        = length (envelopeConcepts env)
          BSL.writeFile outPath (Aeson.encode env)
          putStrLn ("  extracted: " ++ outPath ++ " (" ++ show n ++ " concepts)")
