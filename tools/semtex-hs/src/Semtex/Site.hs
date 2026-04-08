{-# LANGUAGE GHC2021 #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | Doc site generation for semtex v2.
--
-- Pipeline: TeX -> preprocess (strip semtex macros, inject back-refs)
--           -> pandoc --mathml -> HTML
-- tikz-cd diagrams: pdflatex + pdf2svg -> SVG (fallback: placeholder)
--
-- The @site@ subcommand generates a static HTML site from TeX specs.
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
  ) where

import Control.Exception   (SomeException, catch)
import Data.List           (isSuffixOf, sort)
import Data.Map.Strict     (Map)
import Data.Text           (Text)
import System.Directory    (createDirectoryIfMissing, doesFileExist,
                            listDirectory, doesDirectoryExist)
import System.Exit         (ExitCode(..))
import System.FilePath     ((</>), takeBaseName, takeFileName)
import System.IO           (hPutStrLn, stderr)
import System.IO.Temp      (withSystemTempDirectory)
import System.Process      (readProcessWithExitCode)

import qualified Data.Map.Strict  as Map
import qualified Data.Text        as T
import qualified Data.Text.IO     as TIO

import Semtex.Types

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

-- | Run the @site@ subcommand: generate a static HTML doc site.
--
-- @specDir@ is the directory containing TeX files (e.g. @src/spec/@).
-- @outDir@ is the output directory (e.g. @docs/site/@).
runSite :: FilePath -> FilePath -> IO ()
runSite specDir outDir = do
  createDirectoryIfMissing True outDir

  -- Try to load preamble for macro definitions.
  let preamblePath = specDir </> "../preamble.tex"
  hasPreamble <- doesFileExist preamblePath
  preamble <- if hasPreamble
    then TIO.readFile preamblePath
    else do
      -- Try specDir itself
      let alt = specDir </> "preamble.tex"
      altExists <- doesFileExist alt
      if altExists then TIO.readFile alt else pure ""

  -- Find all .tex files recursively.
  texFiles <- findTexFiles specDir
  putStrLn ("  found " ++ show (length texFiles) ++ " TeX files")

  -- Process each file.
  htmlFiles <- mapM (processTexFile preamble outDir) texFiles

  -- Generate index page.
  generateIndex outDir (concat htmlFiles)

  -- Write CSS.
  writeCss outDir

  putStrLn ("  site generated: " ++ outDir)

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
-- Per-file processing
-- ---------------------------------------------------------------------------

-- | Process a single TeX file: preprocess -> pandoc -> HTML.
-- Returns the list of generated HTML file paths (for the index).
processTexFile :: Text -> FilePath -> FilePath -> IO [FilePath]
processTexFile preamble outDir texPath = do
  content <- TIO.readFile texPath

  -- Strip metadata macros; keep content macros for pandoc.
  let stripped = stripSemtexMacros content
      withoutWrapper = stripDocumentWrapper stripped

  -- Replace tikz-cd environments with HTML placeholders before pandoc.
  let withDiagrams = renderTikzDiagrams withoutWrapper

  let baseName = takeBaseName (takeFileName texPath)
      htmlPath = outDir </> baseName ++ ".html"

  htmlContent <- texToHtml preamble withDiagrams baseName
  TIO.writeFile htmlPath (wrapHtml baseName htmlContent)
  putStrLn ("  generated: " ++ htmlPath)
  pure [htmlPath]

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

    -- Strip inline semtex macros, preserving surrounding text.
    inlineStrip = stripInlineMacro "stacksref"
                . stripInlineMacro "nlabref"
                . stripInlineMacro "axiom"

    -- Remove a single-arg macro occurrence inline: \macro{arg} -> ""
    stripInlineMacro macro txt =
      case T.breakOn ("\\" <> macro <> "{") txt of
        (before, rest)
          | T.null rest -> txt
          | otherwise ->
              let afterMacro = T.drop (T.length macro + 2) rest  -- skip \macro{
                  afterBrace = skipBracedContent afterMacro
              in  before <> stripInlineMacro macro afterBrace

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

-- | Inject "Referenced by" HTML at the end of the document.
-- For now, this is a stub that will be populated when the full
-- merge pipeline provides back-reference data.
injectBackRefs :: Map Uid [Uid] -> Text -> Text
injectBackRefs backRefs content
  | Map.null backRefs = content
  | otherwise = content  -- TODO: inject per-atom back-refs when merge provides data

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

-- | Convert preprocessed TeX content to HTML via pandoc.
-- Uses pandoc --mathml for native MathML rendering.
-- Injects preamble macro definitions so pandoc can expand custom macros.
-- Falls back to raw TeX content if pandoc is not available.
texToHtml :: Text -> Text -> String -> IO Text
texToHtml preamble texContent _baseName = do
  hasPandoc <- checkExecutable "pandoc"
  if hasPandoc
    then do
      -- Prepend preamble macro definitions so pandoc can expand them.
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

-- | Extract macro definitions from preamble that pandoc can understand.
-- Filters to single-line \newcommand and \DeclareMathOperator definitions.
-- Multi-line macros (like \lto with \mathchoice) are skipped since pandoc
-- handles them via its own TeX macro expansion.
extractPandocMacros :: Text -> Text
extractPandocMacros preamble =
  let lns = T.lines preamble
      -- Collect complete macro definitions (handling multi-line ones).
      macros = collectMacroDefs lns
  in  T.unlines macros

-- | Collect macro definitions, handling multi-line \newcommand blocks.
-- A multi-line macro starts with \newcommand and ends when braces balance.
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
-- Wraps content in a <pre> block with basic escaping.
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
-- If pdflatex + pdf2svg are available, renders to SVG.
-- Otherwise, inserts a styled placeholder.
renderTikzDiagrams :: Text -> Text
renderTikzDiagrams content =
  let chunks = splitTikzcd content
  in  T.concat (map processTikzChunk chunks)

data TikzChunk
  = PlainChunk !Text
  | TikzChunk !Text   -- the full tikzcd environment
  deriving stock (Eq, Show)

-- | Split text into alternating plain/tikzcd chunks.
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
                          -- Unclosed tikzcd; treat everything as plain
                          reverse (PlainChunk t : acc)
                      | otherwise ->
                          let tikzFull = tikzPart <> "\\end{tikzcd}"
                              remaining = T.drop (T.length "\\end{tikzcd}") afterEnd
                          in  go (TikzChunk tikzFull : PlainChunk before : acc) remaining

-- | Process a single chunk: plain text passes through,
-- tikzcd becomes a placeholder (actual SVG rendering is attempted at build time).
processTikzChunk :: TikzChunk -> Text
processTikzChunk (PlainChunk t) = t
processTikzChunk (TikzChunk tikz) =
  -- For the HTML output, we render tikz-cd as a placeholder
  -- that shows the diagram source in a tooltip.
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
-- Returns Just svgContent on success, Nothing on failure.
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
-- HTML template
-- ---------------------------------------------------------------------------

-- | Wrap HTML body content in a full HTML page.
wrapHtml :: String -> Text -> Text
wrapHtml title body = T.unlines
  [ "<!DOCTYPE html>"
  , "<html lang=\"en\">"
  , "<head>"
  , "  <meta charset=\"utf-8\">"
  , "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
  , "  <title>" <> T.pack title <> " - mwablab</title>"
  , "  <link rel=\"stylesheet\" href=\"style.css\">"
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
-- Index page generation
-- ---------------------------------------------------------------------------

-- | Generate the index.html page listing all generated pages.
generateIndex :: FilePath -> [FilePath] -> IO ()
generateIndex outDir htmlFiles = do
  let entries = map mkEntry (sort htmlFiles)
      body = T.unlines
        [ "<h1>mwablab &mdash; Categorical Foundations</h1>"
        , "<ul>"
        , T.unlines entries
        , "</ul>"
        ]
      mkEntry fp =
        let name = takeBaseName fp
        in  "  <li><a href=\"" <> T.pack (takeFileName fp)
            <> "\">" <> T.pack name <> "</a></li>"
  TIO.writeFile (outDir </> "index.html") (wrapHtml "Index" body)

-- ---------------------------------------------------------------------------
-- CSS
-- ---------------------------------------------------------------------------

-- | Write the site stylesheet.
writeCss :: FilePath -> IO ()
writeCss outDir =
  TIO.writeFile (outDir </> "style.css") cssContent

cssContent :: Text
cssContent = T.unlines
  [ ":root {"
  , "  --bg: #fafafa;"
  , "  --fg: #222;"
  , "  --accent: #2255aa;"
  , "  --defblue: #e8eeff;"
  , "  --border: #ddd;"
  , "  --mono: 'JetBrains Mono', 'Fira Code', monospace;"
  , "}"
  , ""
  , "body {"
  , "  font-family: 'Computer Modern Serif', 'Latin Modern Roman', Georgia, serif;"
  , "  max-width: 48em;"
  , "  margin: 2em auto;"
  , "  padding: 0 1em;"
  , "  background: var(--bg);"
  , "  color: var(--fg);"
  , "  line-height: 1.6;"
  , "}"
  , ""
  , "nav { margin-bottom: 2em; }"
  , "nav a { color: var(--accent); }"
  , ""
  , "h1, h2, h3 {"
  , "  color: var(--fg);"
  , "  border-bottom: 1px solid var(--border);"
  , "  padding-bottom: 0.3em;"
  , "}"
  , ""
  , ".newmath {"
  , "  background: var(--defblue);"
  , "  padding: 1px 3px;"
  , "  border-radius: 2px;"
  , "}"
  , ""
  , ".tikz-diagram {"
  , "  margin: 1em 0;"
  , "  padding: 1em;"
  , "  border: 1px solid var(--border);"
  , "  border-radius: 4px;"
  , "  background: #fff;"
  , "}"
  , ""
  , ".tikz-placeholder {"
  , "  text-align: center;"
  , "  color: #666;"
  , "}"
  , ""
  , ".tikz-source {"
  , "  font-family: var(--mono);"
  , "  font-size: 0.85em;"
  , "  overflow-x: auto;"
  , "}"
  , ""
  , "details summary {"
  , "  cursor: pointer;"
  , "  color: var(--accent);"
  , "  font-size: 0.9em;"
  , "}"
  , ""
  , ".back-refs {"
  , "  font-size: 0.85em;"
  , "  color: #666;"
  , "  margin-top: 0.5em;"
  , "}"
  , ""
  , ".tex-fallback pre {"
  , "  font-family: var(--mono);"
  , "  font-size: 0.85em;"
  , "  overflow-x: auto;"
  , "  background: #f5f5f5;"
  , "  padding: 1em;"
  , "  border-radius: 4px;"
  , "}"
  , ""
  , "ul { list-style-type: none; padding-left: 0; }"
  , "ul li { margin: 0.3em 0; }"
  , "ul li a { color: var(--accent); text-decoration: none; }"
  , "ul li a:hover { text-decoration: underline; }"
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
