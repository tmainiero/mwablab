{-# LANGUAGE GHC2021 #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | Doc site generation for semtex v2.
--
-- Pipeline:
--   1. Parse preamble for type/instance macros
--   2. Extract atoms from each TeX file (Atoms.hs)
--   3. Assign UIDs (Uid.hs)
--   4. Scan symbol usages and compute back-refs (SymbolTrack.hs)
--   5. Compute display numbers from section paths
--   6. For each file: inject display numbers and back-refs into atom
--      content, strip semtex macros, render tikz-cd, pass to pandoc
--
-- The @site@ subcommand generates a static HTML site from TeX specs.
-- Uses the pandoc template at @docs/templates/default.html@ and CSS
-- from @docs/css/@ for consistent styling with dark mode and sidebar.
module Semtex.Site
  ( -- * Site generation
    runSite
    -- * TeX preprocessing
  , preprocessTeX
  , stripSemtexMacros
  , convertNewterm
  , convertNewmath
  , injectBackRefs
    -- * Pandoc conversion
  , texToHtml
    -- * TikZ rendering
  , renderTikzDiagrams
    -- * Display numbers
  , displayNumber
  ) where

import Control.Exception   (SomeException, catch)
import Data.List           (intercalate, isSuffixOf, sort)
import Data.Map.Strict     (Map)
import Data.Set            (Set)
import Data.Text           (Text)
import System.Directory    (createDirectoryIfMissing, doesFileExist,
                            listDirectory, doesDirectoryExist,
                            copyFile)
import System.Exit         (ExitCode(..))
import System.FilePath     ((</>), takeBaseName, takeFileName)
import System.IO           (hPutStrLn, stderr)
import System.IO.Temp      (withSystemTempDirectory)
import System.Process      (readProcessWithExitCode)

import qualified Data.Map.Strict  as Map
import qualified Data.Set         as Set
import qualified Data.Text        as T
import qualified Data.Text.IO     as TIO

import Semtex.Extract.Atoms (extractAtoms, parseTypeMacros, parseInstanceMacros)
import Semtex.SymbolTrack   (buildSymbolTable, scanUsages, inferDependencies,
                             validateSymbols)
import Semtex.Types
import Semtex.Uid           (assignUids, initialUid)

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

-- | Run the @site@ subcommand: generate a static HTML doc site.
--
-- @specDir@ is the directory containing TeX files (e.g. @src/spec/foundations/@).
-- @outDir@ is the output directory (e.g. @docs/site/@).
--
-- Output structure:
--
-- > outDir/
-- >   index.html
-- >   foundations/
-- >     category.html
-- >     functor.html
-- >     ...
-- >   css/
-- >     style.css
-- >     theme.css
runSite :: FilePath -> FilePath -> IO ()
runSite specDir outDir = do
  createDirectoryIfMissing True outDir
  createDirectoryIfMissing True (outDir </> "foundations")
  createDirectoryIfMissing True (outDir </> "css")

  -- Try to locate the project root by going up from specDir.
  -- specDir is typically src/spec/foundations/, so project root is ../../..
  let projectRoot = specDir </> ".." </> ".." </> ".."

  -- Try to load preamble for macro definitions.
  let preamblePath = specDir </> ".." </> "preamble.tex"
  hasPreamble <- doesFileExist preamblePath
  preamble <- if hasPreamble
    then TIO.readFile preamblePath
    else do
      let alt = specDir </> "preamble.tex"
      altExists <- doesFileExist alt
      if altExists then TIO.readFile alt else pure ""

  -- Locate the pandoc template and CSS assets.
  let templatePath = projectRoot </> "docs" </> "templates" </> "default.html"
      stylePath    = projectRoot </> "docs" </> "css" </> "style.css"
      themePath    = projectRoot </> "docs" </> "css" </> "themes" </> "catppuccin.css"

  hasTemplate <- doesFileExist templatePath
  if hasTemplate
    then putStrLn ("  using template: " ++ templatePath)
    else hPutStrLn stderr ("  warning: template not found at " ++ templatePath)

  -- Copy CSS assets to output directory.
  copyAsset stylePath (outDir </> "css" </> "style.css")
  copyAsset themePath (outDir </> "css" </> "theme.css")

  -- Find all .tex files recursively.
  texFiles <- findTexFiles specDir
  putStrLn ("  found " ++ show (length texFiles) ++ " TeX files")

  -- --- v2 atom pipeline ---

  -- Parse preamble for type and instance macros.
  let typeMacros = parseTypeMacros preamble
      instanceMacroMap = parseInstanceMacros typeMacros preamble
      instanceNames = Set.fromList (Map.keys instanceMacroMap)

  -- Extract atoms from all files.
  allFileAtoms <- mapM (extractAtomsFromFile' instanceNames) texFiles
  let rawAtoms = concatMap snd allFileAtoms

  putStrLn ("  extracted " ++ show (length rawAtoms) ++ " atoms")

  -- Assign UIDs to atoms without one.
  let (_nextUid, atomsWithUids) = assignUids initialUid rawAtoms

  -- Build symbol table and scan usages.
  let symTable = buildSymbolTable typeMacros instanceNames atomsWithUids
      atomsWithUsages = scanUsages instanceNames atomsWithUids

  -- Validate symbols (non-fatal for site generation).
  let errors = validateSymbols typeMacros atomsWithUsages
  mapM_ (\err -> hPutStrLn stderr ("  warning: " ++ show err)) errors

  -- Infer dependencies and compute back-references.
  let depEdges = inferDependencies symTable atomsWithUsages
      backRefMap = Map.fromListWith (++)
        [ (dep, [uid])
        | (uid, deps) <- Map.toList depEdges
        , dep <- deps
        ]

  putStrLn ("  symbol deps: " ++ show (Map.size depEdges)
            ++ " edges, " ++ show (Map.size backRefMap) ++ " back-refs")

  -- Populate back-refs on atoms and compute display numbers.
  let finalAtoms = map (\a ->
        let withBackRef = case atomUid a of
              Just uid -> a { atomBackRefs = Map.findWithDefault [] uid backRefMap }
              Nothing  -> a
            dn = displayNumber (atomSectionPath withBackRef)
        in  withBackRef { atomDisplayNumber = Just dn }
        ) atomsWithUsages

  -- Build UID -> Atom lookup for resolving back-ref display numbers.
  let atomByUid = Map.fromList
        [ (uid, a)
        | a <- finalAtoms
        , Just uid <- [atomUid a]
        ]

  -- Group final atoms back by source file.
  let atomsByFile = groupAtomsByFile finalAtoms

  -- Process each file: inject numbering/back-refs, strip macros, pandoc.
  htmlFiles <- mapM
    (processFileAtoms preamble templatePath outDir atomByUid atomsByFile)
    texFiles

  -- Generate index page.
  generateIndex templatePath outDir (concat htmlFiles)

  putStrLn ("  site generated: " ++ outDir)

-- | Extract atoms from a TeX file, returning (filePath, atoms).
extractAtomsFromFile' :: Set Text -> FilePath -> IO (FilePath, [Atom])
extractAtomsFromFile' instanceNames fp = do
  content <- TIO.readFile fp
  let atoms = extractAtoms fp instanceNames content
  pure (fp, atoms)

-- | Group atoms by their source file path.
groupAtomsByFile :: [Atom] -> Map FilePath [Atom]
groupAtomsByFile = foldl (\m a ->
  Map.insertWith (\new old -> old ++ new) (atomFile a) [a] m) Map.empty

-- | Copy a file if the source exists; warn otherwise.
copyAsset :: FilePath -> FilePath -> IO ()
copyAsset src dst = do
  exists <- doesFileExist src
  if exists
    then copyFile src dst
    else hPutStrLn stderr ("  warning: asset not found: " ++ src)

-- ---------------------------------------------------------------------------
-- Display numbers
-- ---------------------------------------------------------------------------

-- | Compute a display number from a section path like [2, 1, 3] -> "2.1.3".
displayNumber :: [Int] -> DisplayNumber
displayNumber [] = DisplayNumber "0"
displayNumber path = DisplayNumber (T.pack (intercalate "." (map show path)))

-- | Format atom type as a short label for display.
atomTypeLabel :: AtomType -> Text
atomTypeLabel AtomParagraph   = ""
atomTypeLabel AtomDefinition  = "Definition"
atomTypeLabel AtomTheorem     = "Theorem"
atomTypeLabel AtomProposition = "Proposition"
atomTypeLabel AtomLemma       = "Lemma"
atomTypeLabel AtomCorollary   = "Corollary"
atomTypeLabel AtomRemark      = "Remark"
atomTypeLabel AtomExample     = "Example"
atomTypeLabel AtomProof       = "Proof"

-- ---------------------------------------------------------------------------
-- Atom content injection
-- ---------------------------------------------------------------------------

-- | Inject a display number anchor at the start of an atom's content.
-- For theorem environments, adds "Definition 2.1.3." prefix.
-- For paragraphs, adds a superscript margin number.
-- Uses TeX commands that pandoc converts to proper HTML:
--   \label{atom-UID}   -> <span id="atom-UID">
--   \hyperlink{...}{N} -> <a href="#...">N</a>
injectDisplayNumber :: Atom -> Text
injectDisplayNumber atom =
  case atomDisplayNumber atom of
    Nothing -> atomContent atom
    Just dn ->
      let num = unDisplayNumber dn
          label = atomTypeLabel (atomType atom)
          anchor = case atomUid atom of
            Just uid -> "\\label{atom-" <> unUid uid <> "}"
            Nothing  -> ""
          prefix = case atomType atom of
            AtomParagraph ->
              "\\textsuperscript{\\textbf{" <> num <> "}}" <> anchor <> " "
            _ ->
              "\\textbf{" <> label <> " " <> num <> ".}" <> anchor <> " "
      in  prefix <> stripEnvWrapper (atomType atom) (atomContent atom)

-- | Strip \begin{env}...\end{env} wrapper from theorem environments
-- so we can inject the number before the content.
stripEnvWrapper :: AtomType -> Text -> Text
stripEnvWrapper AtomParagraph content = content
stripEnvWrapper atomType' content =
  let envName = atomTypeToEnvName atomType'
      beginTag = "\\begin{" <> envName <> "}"
      endTag = "\\end{" <> envName <> "}"
      stripped = T.strip content
      -- Remove \begin{env} from start
      afterBegin = case T.stripPrefix beginTag stripped of
        Just rest -> T.strip rest
        Nothing   -> stripped
      -- Remove \end{env} from end
      beforeEnd = case T.stripSuffix endTag (T.stripEnd afterBegin) of
        Just rest -> T.strip rest
        Nothing   -> afterBegin
  in  beforeEnd

-- | Map atom type back to TeX environment name.
atomTypeToEnvName :: AtomType -> Text
atomTypeToEnvName AtomParagraph   = ""
atomTypeToEnvName AtomDefinition  = "definition"
atomTypeToEnvName AtomTheorem     = "theorem"
atomTypeToEnvName AtomProposition = "proposition"
atomTypeToEnvName AtomLemma       = "lemma"
atomTypeToEnvName AtomCorollary   = "corollary"
atomTypeToEnvName AtomRemark      = "remark"
atomTypeToEnvName AtomExample     = "example"
atomTypeToEnvName AtomProof       = "proof"

-- | Inject back-references at the end of an atom's content.
-- Renders as italic "Used in X.Y, Z.W." with clickable links.
-- Uses \hyperlink which pandoc converts to <a href="#...">.
injectAtomBackRefs :: Map Uid Atom -> Atom -> Text
injectAtomBackRefs atomByUid atom =
  let refs = atomBackRefs atom
      refEntries = [ (uid, a)
                   | uid <- refs
                   , Just a <- [Map.lookup uid atomByUid]
                   ]
  in  if null refEntries
        then ""
        else
          let refLinks = map (\(uid, a) ->
                let dn = case atomDisplayNumber a of
                      Just d  -> unDisplayNumber d
                      Nothing -> unUid uid
                in  "\\hyperlink{atom-" <> unUid uid <> "}{" <> dn <> "}"
                ) refEntries
          in  "\n\n\\noindent\\textit{\\small Used in "
              <> T.intercalate ", " refLinks <> ".}\n"

-- ---------------------------------------------------------------------------
-- Per-file processing (v2 pipeline)
-- ---------------------------------------------------------------------------

-- | Process a single file's atoms through the v2 pipeline.
-- Reconstructs the file content from annotated atoms, then converts to HTML.
processFileAtoms
  :: Text                    -- ^ Preamble
  -> FilePath                -- ^ Template path
  -> FilePath                -- ^ Output directory
  -> Map Uid Atom            -- ^ Global UID -> Atom lookup
  -> Map FilePath [Atom]     -- ^ Atoms grouped by file
  -> FilePath                -- ^ Source TeX file path
  -> IO [FilePath]
processFileAtoms preamble templatePath outDir atomByUid atomsByFile texPath = do
  let baseName = takeBaseName (takeFileName texPath)
      htmlPath = outDir </> "foundations" </> baseName ++ ".html"
      fileAtoms = Map.findWithDefault [] texPath atomsByFile

  -- Read the original file for section headers (atoms don't capture them).
  originalContent <- TIO.readFile texPath

  -- Build annotated content: section headers from original + atoms with
  -- display numbers and back-refs injected.
  let annotatedContent = if null fileAtoms
        -- Fallback: no atoms extracted, use plain preprocessing.
        then stripSemtexMacros (stripDocumentWrapper originalContent)
        else buildAnnotatedContent atomByUid originalContent fileAtoms

  -- Strip remaining semtex macros from annotated content.
  let cleaned = stripSemtexMacros annotatedContent

  -- Render tikz-cd placeholders.
  let withDiagrams = renderTikzDiagrams cleaned

  -- Convert to HTML via pandoc with template.
  htmlContent <- texToHtmlWithTemplate preamble templatePath withDiagrams baseName
  TIO.writeFile htmlPath htmlContent
  putStrLn ("  generated: " ++ htmlPath)
  pure [htmlPath]

-- | Build annotated file content by replacing atom regions with
-- numbered/back-ref-annotated versions.
--
-- Strategy: walk the original file line by line. When we encounter content
-- that matches an atom, replace it with the annotated version. Section
-- headers and other non-atom content pass through.
buildAnnotatedContent :: Map Uid Atom -> Text -> [Atom] -> Text
buildAnnotatedContent atomByUid originalContent atoms =
  let -- Strip document wrapper first.
      stripped = stripDocumentWrapper originalContent
      -- Reconstruct: section headers + annotated atoms in order.
      sectionLines = extractSectionLines stripped
      atomBlocks = map (renderAnnotatedAtom atomByUid) atoms
  in  T.unlines (sectionLines ++ concatMap T.lines atomBlocks)

-- | Extract section and subsection lines from content (preserving order).
extractSectionLines :: Text -> [Text]
extractSectionLines content =
  filter isSectionLine (T.lines content)
  where
    isSectionLine line =
      let s = T.stripStart line
      in  T.isPrefixOf "\\section" s || T.isPrefixOf "\\subsection" s
       || T.isPrefixOf "\\label{sec:" s

-- | Render a single atom with display number and back-refs.
renderAnnotatedAtom :: Map Uid Atom -> Atom -> Text
renderAnnotatedAtom atomByUid atom =
  let numbered = injectDisplayNumber atom
      backRefs = injectAtomBackRefs atomByUid atom
  in  numbered <> backRefs <> "\n"

-- ---------------------------------------------------------------------------
-- File discovery
-- ---------------------------------------------------------------------------

-- | Recursively find all .tex files under a directory.
-- Excludes preamble.tex since it's not a content file.
findTexFiles :: FilePath -> IO [FilePath]
findTexFiles dir = fmap sort (go dir)
  where
    go d = do
      entries <- listDirectory d
      fmap concat (mapM (processEntry d) entries)

    processEntry d name = do
      let path = d </> name
      isDir <- doesDirectoryExist path
      if isDir
        then go path
        else if ".tex" `isSuffixOf` name
                && name /= "preamble.tex"
              then pure [path]
              else pure []

-- ---------------------------------------------------------------------------
-- TeX preprocessing
-- ---------------------------------------------------------------------------

-- | Full preprocessing pipeline for a TeX file.
-- Strips metadata macros but keeps content macros for pandoc.
preprocessTeX :: Map Uid [Uid] -> Text -> Text
preprocessTeX _backRefs content =
  let stripped = stripSemtexMacros content
      withoutWrapper = stripDocumentWrapper stripped
  in  withoutWrapper

-- | Strip semtex-specific macros that are metadata, not content.
-- Removes: \concept, \depends, \implements, \axiom, \uses, \stacksref, \nlabref
-- Keeps: \newterm, \newmath (converted separately)
stripSemtexMacros :: Text -> Text
stripSemtexMacros = T.unlines . map stripLine . T.lines
  where
    stripLine line
      | isSemtexOnlyLine line = ""
      | otherwise = inlineStrip line

    -- Lines that consist entirely of a semtex macro.
    isSemtexOnlyLine line =
      let stripped = T.stripStart line
      in  any (\m -> T.isPrefixOf ("\\" <> m <> "{") stripped)
            ["concept", "depends", "uses", "implements"]
       && not (hasContentAfterMacro stripped)

    hasContentAfterMacro t =
      let afterBraces = skipBracedGroups t
      in  not (T.null (T.strip afterBraces))

    -- Convert or strip inline semtex macros, preserving surrounding text.
    inlineStrip = convertInlineMacro "stacksref" convertStacksref
                . convertInlineMacro "nlabref" convertNlabref
                . stripInlineMacro "axiom"
                . convertInlineMacro "newmath" id

    -- \stacksref{0014} -> \href{...}{\textsc{Stacks Project} Tag \texttt{0014}}
    convertStacksref tag =
      "\\href{https://stacks.math.columbia.edu/tag/" <> tag
      <> "}{\\textsc{Stacks Project} Tag \\texttt{" <> tag <> "}}"

    -- \nlabref{category} -> \href{...}{nLab: \textsf{category}}
    convertNlabref page =
      "\\href{https://ncatlab.org/nlab/show/" <> page
      <> "}{nLab: \\textsf{" <> page <> "}}"

    -- Remove a single-arg macro occurrence inline: \macro{arg} -> ""
    stripInlineMacro macro txt =
      case T.breakOn ("\\" <> macro <> "{") txt of
        (before, rest)
          | T.null rest -> txt
          | otherwise ->
              let afterMacro = T.drop (T.length macro + 2) rest  -- skip \macro{
                  afterBrace = skipBracedContent afterMacro
              in  before <> stripInlineMacro macro afterBrace

    -- Replace a single-arg macro inline: \macro{arg} -> f arg
    convertInlineMacro macro f txt =
      case T.breakOn ("\\" <> macro <> "{") txt of
        (before, rest)
          | T.null rest -> txt
          | otherwise ->
              let afterMacro = T.drop (T.length macro + 2) rest  -- skip \macro{
                  (arg, afterBrace) = extractBracedArg afterMacro
              in  before <> f arg <> convertInlineMacro macro f afterBrace

-- | Skip past a brace-balanced group (assumes we're right after the '{').
skipBracedContent :: Text -> Text
skipBracedContent = go (0 :: Int)
  where
    go _ t | T.null t = t
    go depth t =
      case T.uncons t of
        Nothing -> t
        Just ('{', rest) -> go (depth + 1) rest
        Just ('}', rest)
          | depth == 0 -> rest
          | otherwise  -> go (depth - 1) rest
        Just (_, rest) -> go depth rest

-- | Skip all brace groups at the start of text.
skipBracedGroups :: Text -> Text
skipBracedGroups t =
  case T.uncons (T.stripStart t) of
    Just ('{', _) ->
      let after = skipBracedContent (T.drop 1 (T.stripStart t))
      in  skipBracedGroups after
    _ -> t

-- | Convert \newterm{X} to <strong>X</strong> for HTML.
convertNewterm :: Text -> Text
convertNewterm = replaceTexMacro "newterm" (\arg -> "<strong>" <> arg <> "</strong>")

-- | Convert \newmath{X} to a highlighted span for HTML.
convertNewmath :: Text -> Text
convertNewmath = replaceTexMacro "newmath" (\arg ->
  "<span class=\"newmath\">$" <> arg <> "$</span>")

-- | Replace all occurrences of \macro{arg} with the result of a function
-- applied to the argument.
replaceTexMacro :: Text -> (Text -> Text) -> Text -> Text
replaceTexMacro macro f = go
  where
    prefix = "\\" <> macro <> "{"
    go txt =
      case T.breakOn prefix txt of
        (before, rest)
          | T.null rest -> txt
          | otherwise ->
              let afterPrefix = T.drop (T.length prefix) rest
                  (arg, after) = extractBracedArg afterPrefix
              in  before <> f arg <> go after

-- | Extract a brace-balanced argument (assuming we're right after the '{').
-- Returns (content, text after closing brace).
extractBracedArg :: Text -> (Text, Text)
extractBracedArg = go (0 :: Int) T.empty
  where
    go _ acc t | T.null t = (acc, t)
    go depth acc t =
      case T.uncons t of
        Nothing -> (acc, t)
        Just ('{', rest) -> go (depth + 1) (T.snoc acc '{') rest
        Just ('}', rest)
          | depth == 0 -> (acc, rest)
          | otherwise  -> go (depth - 1) (T.snoc acc '}') rest
        Just (c, rest) -> go depth (T.snoc acc c) rest

-- | Inject "Referenced by" back-refs into content keyed by UID.
injectBackRefs :: Map Uid [Uid] -> Text -> Text
injectBackRefs backRefs content
  | Map.null backRefs = content
  | otherwise = content  -- back-refs are now injected per-atom in v2 pipeline

-- | Strip \documentclass, \begin{document}, \end{document} wrappers.
stripDocumentWrapper :: Text -> Text
stripDocumentWrapper = T.unlines . filter (not . isWrapper) . T.lines
  where
    isWrapper line =
      let s = T.stripStart line
      in  any (`T.isPrefixOf` s)
            [ "\\documentclass"
            , "\\begin{document}"
            , "\\end{document}"
            , "\\maketitle"
            , "\\tableofcontents"
            ]

-- ---------------------------------------------------------------------------
-- Pandoc conversion
-- ---------------------------------------------------------------------------

-- | Convert preprocessed TeX content to HTML via pandoc with the site template.
-- Uses --mathml for native MathML rendering and the pandoc template for
-- consistent site styling (sidebar, dark mode toggle, CSS).
texToHtmlWithTemplate :: Text -> FilePath -> Text -> String -> IO Text
texToHtmlWithTemplate preamble templatePath texContent baseName = do
  hasPandoc <- checkExecutable "pandoc"
  hasTemplate <- doesFileExist templatePath
  if hasPandoc && hasTemplate
    then do
      let macros = extractPandocMacros preamble
          fullInput = macros <> "\n" <> texContent
          title = humanTitle baseName
      (exitCode, stdout, pandocStderr) <- readProcessWithExitCode "pandoc"
        [ "--from=latex"
        , "--to=html5"
        , "--mathml"
        , "--standalone"
        , "--template=" ++ templatePath
        , "--variable=title:" ++ title
        , "--variable=root:../"
        ]
        (T.unpack fullInput)
      case exitCode of
        ExitSuccess -> pure (T.pack stdout)
        ExitFailure _ -> do
          hPutStrLn stderr ("  pandoc warning: " ++ pandocStderr)
          texToHtml preamble texContent baseName >>= pure . wrapHtml baseName
    else
      texToHtml preamble texContent baseName >>= pure . wrapHtml baseName

-- | Convert preprocessed TeX content to HTML body via pandoc (no template).
-- Uses pandoc --mathml for native MathML rendering.
-- Falls back to raw TeX content if pandoc is not available.
texToHtml :: Text -> Text -> String -> IO Text
texToHtml preamble texContent _baseName = do
  hasPandoc <- checkExecutable "pandoc"
  if hasPandoc
    then do
      let macros = extractPandocMacros preamble
          fullInput = macros <> "\n" <> texContent
      (exitCode, stdout, pandocStderr) <- readProcessWithExitCode "pandoc"
        [ "--from=latex"
        , "--to=html5"
        , "--mathml"
        ]
        (T.unpack fullInput)
      case exitCode of
        ExitSuccess -> pure (T.pack stdout)
        ExitFailure _ -> do
          hPutStrLn stderr ("  pandoc warning: " ++ pandocStderr)
          pure (fallbackHtml texContent)
    else do
      hPutStrLn stderr "  pandoc not found, using fallback HTML rendering"
      pure (fallbackHtml texContent)

-- | Convert a kebab-case basename to a human-readable title.
humanTitle :: String -> String
humanTitle = map (\c -> if c == '-' then ' ' else c) . capitalizeFirst
  where
    capitalizeFirst [] = []
    capitalizeFirst (c:cs) = toUpper c : cs
    toUpper c
      | c >= 'a' && c <= 'z' = toEnum (fromEnum c - 32)
      | otherwise = c

-- | Extract macro definitions from preamble that pandoc can understand.
-- Filters out macros that use TeX primitives pandoc cannot handle
-- (e.g. \colorbox, \textcolor, \mathchoice, \setlength).
extractPandocMacros :: Text -> Text
extractPandocMacros preamble =
  let lns = T.lines preamble
      macros = filter (not . isUnsupportedMacro) (collectMacroDefs lns)
      -- Simplified replacements for \mathchoice-based arrow macros.
      -- Pandoc only needs the textstyle variant.
      arrowFallbacks =
        [ "\\newcommand{\\lto}{\\rightarrow}"
        , "\\newcommand{\\lTo}{\\Rightarrow}"
        , "\\newcommand{\\lmapsto}{\\mapsto}"
        ]
  in  T.unlines (macros ++ arrowFallbacks)

-- | Detect macro definitions that pandoc cannot expand correctly.
-- These are either converted in preprocessing or use unsupported primitives.
isUnsupportedMacro :: Text -> Bool
isUnsupportedMacro def = any (`T.isInfixOf` def)
  [ "{\\newmath}"    -- converted to bare content in preprocessing
  , "{\\newterm}"    -- converted to \emph in preprocessing
  , "{\\stacksref}"  -- converted to \href in preprocessing
  , "{\\nlabref}"    -- converted to \href in preprocessing
  , "\\colorbox"     -- unsupported by pandoc
  , "\\colorlet"     -- unsupported by pandoc
  , "\\fboxsep"      -- unsupported by pandoc
  , "\\mathchoice"   -- unsupported by pandoc (arrow macros \lto, \lTo, \lmapsto)
  ]

-- | Collect macro definitions, handling multi-line \newcommand blocks.
collectMacroDefs :: [Text] -> [Text]
collectMacroDefs [] = []
collectMacroDefs (l : ls)
  | startsNewcommand l || startsDeclareMathOp l =
      let (macroDef, rest) = collectUntilBalanced l ls
      in  macroDef : collectMacroDefs rest
  | otherwise = collectMacroDefs ls

startsNewcommand :: Text -> Bool
startsNewcommand l =
  let s = T.stripStart l
  in  T.isPrefixOf "\\newcommand" s || T.isPrefixOf "\\renewcommand" s

startsDeclareMathOp :: Text -> Bool
startsDeclareMathOp l = T.isPrefixOf "\\DeclareMathOperator" (T.stripStart l)

-- | Collect lines until braces are balanced.
collectUntilBalanced :: Text -> [Text] -> (Text, [Text])
collectUntilBalanced firstLine rest =
  let depth = countBraces firstLine
  in  if depth <= 0
        then (firstLine, rest)
        else go depth [firstLine] rest
  where
    go _ acc [] = (T.unlines (reverse acc), [])
    go d acc (l : ls) =
      let d' = d + countBraces l
          acc' = l : acc
      in  if d' <= 0
            then (T.unlines (reverse acc'), ls)
            else go d' acc' ls

    countBraces :: Text -> Int
    countBraces = T.foldl' (\n c -> case c of
      '{' -> n + 1
      '}' -> n - 1
      _   -> n) 0

-- | Fallback HTML rendering when pandoc is not available.
fallbackHtml :: Text -> Text
fallbackHtml content =
  "<div class=\"tex-fallback\"><pre>" <> escapeHtml content <> "</pre></div>"

-- | Basic HTML escaping.
escapeHtml :: Text -> Text
escapeHtml = T.replace "&" "&amp;"
           . T.replace "<" "&lt;"
           . T.replace ">" "&gt;"
           . T.replace "\"" "&quot;"

-- ---------------------------------------------------------------------------
-- TikZ diagram rendering
-- ---------------------------------------------------------------------------

-- | Replace tikz-cd environments with SVG images or placeholders.
renderTikzDiagrams :: Text -> Text
renderTikzDiagrams content =
  let chunks = splitTikzcd content
  in  T.concat (map processTikzChunk chunks)

data TikzChunk
  = PlainChunk !Text
  | TikzChunk !Text
  deriving stock (Eq, Show)

splitTikzcd :: Text -> [TikzChunk]
splitTikzcd = go []
  where
    go acc t
      | T.null t = reverse acc
      | otherwise =
          case T.breakOn "\\begin{tikzcd}" t of
            (before, rest)
              | T.null rest ->
                  reverse (PlainChunk before : acc)
              | otherwise ->
                  case T.breakOn "\\end{tikzcd}" rest of
                    (tikzPart, afterEnd)
                      | T.null afterEnd ->
                          reverse (PlainChunk t : acc)
                      | otherwise ->
                          let tikzFull = tikzPart <> "\\end{tikzcd}"
                              remaining = T.drop (T.length "\\end{tikzcd}") afterEnd
                          in  go (TikzChunk tikzFull : PlainChunk before : acc) remaining

processTikzChunk :: TikzChunk -> Text
processTikzChunk (PlainChunk t) = t
processTikzChunk (TikzChunk tikz) =
  let escaped = escapeHtml tikz
  in  T.unlines
        [ "<div class=\"tikz-diagram\" title=\"" <> T.take 100 escaped <> "\">"
        , "  <div class=\"tikz-placeholder\">"
        , "    <em>[commutative diagram]</em>"
        , "  </div>"
        , "  <details>"
        , "    <summary>Show TeX source</summary>"
        , "    <pre class=\"tikz-source\">" <> escaped <> "</pre>"
        , "  </details>"
        , "</div>"
        ]

-- | Try to render a tikzcd environment to SVG using pdflatex + pdf2svg.
_renderTikzToSvg :: Text -> Text -> IO (Maybe Text)
_renderTikzToSvg preambleContent tikzEnv = do
  hasPdflatex <- checkExecutable "pdflatex"
  hasPdf2svg <- checkExecutable "pdf2svg"
  if hasPdflatex && hasPdf2svg
    then withSystemTempDirectory "semtex-tikz" $ \tmpDir -> do
      let texFile = tmpDir </> "diagram.tex"
          pdfFile = tmpDir </> "diagram.pdf"
          svgFile = tmpDir </> "diagram.svg"
          texContent = T.unlines
            [ "\\documentclass[preview,border=2pt]{standalone}"
            , "\\usepackage{amsmath,amssymb,tikz-cd}"
            , preambleContent
            , "\\begin{document}"
            , tikzEnv
            , "\\end{document}"
            ]
      TIO.writeFile texFile texContent
      (exitCode, _, _) <- readProcessWithExitCode "pdflatex"
        ["-interaction=nonstopmode", "-output-directory=" ++ tmpDir, texFile] ""
      case exitCode of
        ExitSuccess -> do
          (svgExit, _, _) <- readProcessWithExitCode "pdf2svg"
            [pdfFile, svgFile] ""
          case svgExit of
            ExitSuccess -> do
              svgContent <- TIO.readFile svgFile
              pure (Just svgContent)
            ExitFailure _ -> pure Nothing
        ExitFailure _ -> pure Nothing
    else pure Nothing

-- ---------------------------------------------------------------------------
-- HTML fallback template (used when pandoc template is not available)
-- ---------------------------------------------------------------------------

-- | Wrap HTML body content in a basic HTML page (fallback).
wrapHtml :: String -> Text -> Text
wrapHtml title body = T.unlines
  [ "<!DOCTYPE html>"
  , "<html lang=\"en\">"
  , "<head>"
  , "  <meta charset=\"utf-8\">"
  , "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "  <title>" <> T.pack title <> " - mwablab</title>"
  , "  <link rel=\"stylesheet\" href=\"../css/theme.css\">"
  , "  <link rel=\"stylesheet\" href=\"../css/style.css\">"
  , "</head>"
  , "<body>"
  , "  <nav><a href=\"../index.html\">Index</a></nav>"
  , "  <main>"
  , body
  , "  </main>"
  , "</body>"
  , "</html>"
  ]

-- ---------------------------------------------------------------------------
-- Index page generation
-- ---------------------------------------------------------------------------

-- | Generate the index.html page listing all generated pages.
generateIndex :: FilePath -> FilePath -> [FilePath] -> IO ()
generateIndex templatePath outDir htmlFiles = do
  hasTemplate <- doesFileExist templatePath
  hasPandoc <- checkExecutable "pandoc"
  let entries = map mkEntry (sort htmlFiles)
      body = T.unlines
        [ "# mwablab --- Categorical Foundations"
        , ""
        , "Mathematical foundations implemented as code."
        , ""
        , "## Foundations"
        , ""
        , T.unlines entries
        ]
      mkEntry fp =
        let name = takeBaseName fp
        in  "- [" <> T.pack (humanTitle name) <> "](foundations/"
            <> T.pack (takeFileName fp) <> ")"
  if hasTemplate && hasPandoc
    then do
      (exitCode, stdout, _) <- readProcessWithExitCode "pandoc"
        [ "--from=markdown"
        , "--to=html5"
        , "--mathml"
        , "--standalone"
        , "--template=" ++ templatePath
        , "--variable=title:Index"
        , "--variable=root:"
        ]
        (T.unpack body)
      case exitCode of
        ExitSuccess -> TIO.writeFile (outDir </> "index.html") (T.pack stdout)
        ExitFailure _ -> writeFallbackIndex outDir entries
    else writeFallbackIndex outDir entries

writeFallbackIndex :: FilePath -> [Text] -> IO ()
writeFallbackIndex outDir entries = do
  let body = T.unlines
        [ "<h1>mwablab &mdash; Categorical Foundations</h1>"
        , "<p>Mathematical foundations implemented as code.</p>"
        , "<h2>Foundations</h2>"
        , "<ul>"
        , T.unlines (map entryToHtml entries)
        , "</ul>"
        ]
      entryToHtml entry = "  <li>" <> entry <> "</li>"
  TIO.writeFile (outDir </> "index.html") (wrapIndexHtml body)

wrapIndexHtml :: Text -> Text
wrapIndexHtml body = T.unlines
  [ "<!DOCTYPE html>"
  , "<html lang=\"en\">"
  , "<head>"
  , "  <meta charset=\"utf-8\">"
  , "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "  <title>Index - mwablab</title>"
  , "  <link rel=\"stylesheet\" href=\"css/theme.css\">"
  , "  <link rel=\"stylesheet\" href=\"css/style.css\">"
  , "</head>"
  , "<body>"
  , "  <nav><a href=\"index.html\">Index</a></nav>"
  , "  <main>"
  , body
  , "  </main>"
  , "</body>"
  , "</html>"
  ]

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------

-- | Check if an executable is on PATH.
checkExecutable :: String -> IO Bool
checkExecutable name = do
  (exitCode, _, _) <- readProcessWithExitCode "which" [name] ""
    `catch` (\(_ :: SomeException) -> pure (ExitFailure 1, "", ""))
  pure (exitCode == ExitSuccess)
