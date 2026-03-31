-- | Registry validation — the @validate@ command.
--
-- Loads a @registry.json@ and performs two checks:
--
--   1. Every @implements@ path resolves to an existing file on disk.
--   2. No Stacks Project tag is cited by more than one concept.
module Semtex.Validate
  ( -- * Validation
    runValidate
  ) where

import Control.Monad        (forM, forM_)
import Data.List            (intercalate, nub)
import Data.Map.Strict      (Map)
import Data.Maybe           (fromMaybe)
import Data.Text            (Text)
import System.Directory     (doesFileExist)
import System.Exit          (exitFailure)
import System.FilePath      ((</>))
import System.IO            (hPutStrLn, stderr)

import qualified Data.Aeson       as Aeson
import qualified Data.Map.Strict  as Map
import qualified Data.Text        as T

import Semtex.Json   ()
import Semtex.Types

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

-- | Run the @validate@ command.
--
-- Loads the registry at @registryPath@, resolves all @implements@ entries
-- relative to @mProjectRoot@ (defaulting to @\".\"@), and reports any missing
-- files or duplicate Stacks tags.  Exits with a non-zero code if errors are
-- found.
runValidate :: FilePath -> Maybe FilePath -> IO ()
runValidate registryPath mProjectRoot = do
  let projectRoot = fromMaybe "." mProjectRoot

  -- Load registry from disk.
  registry <- loadRegistry registryPath

  let concepts = regConcepts registry

  -- Check that every implementation file exists.
  (errors, implWarnings) <- checkImplFiles projectRoot concepts

  -- Check for duplicate Stacks tags across concepts.
  let tagWarnings = checkTagUniqueness concepts

  let warnings = implWarnings ++ tagWarnings

  -- Emit warnings.
  forM_ warnings $ \w ->
    hPutStrLn stderr ("warning: " ++ T.unpack w)

  -- Emit errors.
  forM_ errors $ \e ->
    hPutStrLn stderr ("error: " ++ T.unpack e)

  -- Summary line.
  let nConcepts = Map.size concepts
  if null errors
    then putStrLn
           ("  validation OK ("
            ++ show nConcepts ++ " concepts, "
            ++ show (length warnings) ++ " warnings)")
    else do
      putStrLn
        ("\nvalidation FAILED ("
         ++ show (length errors) ++ " errors, "
         ++ show (length warnings) ++ " warnings)")
      exitFailure

-- ---------------------------------------------------------------------------
-- Registry loading
-- ---------------------------------------------------------------------------

-- | Decode a @registry.json@ file.  Exits with an error message on failure.
loadRegistry :: FilePath -> IO Registry
loadRegistry path = do
  result <- Aeson.eitherDecodeFileStrict path
  case result of
    Left  err -> do
      hPutStrLn stderr ("error: could not parse registry: " ++ err)
      exitFailure
    Right reg -> pure reg

-- ---------------------------------------------------------------------------
-- Implementation file checks
-- ---------------------------------------------------------------------------

-- | Known language roots within the project tree.
--
-- Each value is the path prefix (relative to the project root) under which
-- source files for that language live.
langRoots :: Map Text FilePath
langRoots = Map.fromList
  [ ("haskell", "src/haskell/src")
  , ("agda",    "src/agda")
  , ("lisp",    "src/lisp/src")
  ]

-- | Convert a module name to a relative file path for the given language.
--
-- Returns an empty string for unrecognised languages (the caller already
-- guards against unknown languages before calling this).
moduleToPath :: Text -> Text -> FilePath
moduleToPath "haskell" modName = T.unpack (T.replace "." "/" modName) ++ ".hs"
moduleToPath "agda"    modName = T.unpack (T.replace "." "/" modName) ++ ".agda"
moduleToPath "lisp"    modName = T.unpack modName ++ ".lisp"
moduleToPath _         _       = ""

-- | Verify that every @implements@ entry in every concept points to an
-- existing file.
--
-- Returns @(errors, warnings)@ where:
--
--   * /errors/ — one entry per missing file.
--   * /warnings/ — one entry per unrecognised language.
checkImplFiles
  :: FilePath
  -> Map ConceptId Concept
  -> IO ([Text], [Text])
checkImplFiles projectRoot concepts = do
  pairs <- forM (Map.elems concepts) (checkConcept projectRoot)
  let (errLists, warnLists) = unzip pairs
  pure (concat errLists, concat warnLists)

-- | Check all @implements@ entries for a single concept.
checkConcept :: FilePath -> Concept -> IO ([Text], [Text])
checkConcept projectRoot concept = do
  pairs <- forM (Map.toList (conceptImplements concept)) (checkLang projectRoot cid)
  let (errLists, warnLists) = unzip pairs
  pure (concat errLists, concat warnLists)
  where
    cid = conceptId concept

-- | Check all modules for a single (concept, language) pair.
checkLang
  :: FilePath
  -> ConceptId
  -> (Text, [Text])
  -> IO ([Text], [Text])
checkLang projectRoot cid (lang, mods) =
  case Map.lookup lang langRoots of
    Nothing ->
      -- Unknown language — emit a warning, no file checks.
      pure
        ( []
        , [ "concept '" <> cid <> "': unknown language '" <> lang <> "'" ]
        )
    Just langRoot -> do
      errs <- forM mods $ \modName -> do
        let relPath = moduleToPath lang modName
            fullPath = projectRoot </> langRoot </> relPath
        exists <- doesFileExist fullPath
        if exists
          then pure []
          else pure
                 [ "concept '" <> cid
                   <> "': " <> lang
                   <> " module '" <> modName
                   <> "' -> file not found: "
                   <> T.pack fullPath
                 ]
      pure (concat errs, [])

-- ---------------------------------------------------------------------------
-- Stacks tag uniqueness
-- ---------------------------------------------------------------------------

-- | Warn about any Stacks tag that is cited by more than one concept.
--
-- Builds an inverted index from tag to all citing concepts, then reports
-- duplicates.
checkTagUniqueness :: Map ConceptId Concept -> [Text]
checkTagUniqueness concepts =
  concatMap warnIfDuplicate (Map.toList tagIndex)
  where
    -- Build Map Tag [ConceptId] from all concepts.
    tagIndex :: Map Tag [ConceptId]
    tagIndex =
      Map.foldr insertConcept Map.empty concepts

    insertConcept :: Concept -> Map Tag [ConceptId] -> Map Tag [ConceptId]
    insertConcept c acc =
      foldr (\tag m -> Map.insertWith (++) tag [conceptId c] m)
            acc
            (nub (conceptStacksRefs c))

    warnIfDuplicate :: (Tag, [ConceptId]) -> [Text]
    warnIfDuplicate (tag, cids)
      | length cids > 1 =
          [ "Stacks tag '"
            <> tag
            <> "' used by multiple concepts: ["
            <> T.pack (intercalate ", " (map T.unpack cids))
            <> "]"
          ]
      | otherwise = []
