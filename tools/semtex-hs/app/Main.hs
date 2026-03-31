-- | CLI entry point for semtex — wires up subcommands via optparse-applicative.
--
-- Exposes five subcommands:
--
--   * @extract FILE [FILE ...]@ — extract concept graphs from TeX files
--   * @merge DIR@ — merge per-file .semtex.json into registry.json
--   * @validate REGISTRY [PROJECT_ROOT]@ — validate a registry
--   * @mathjax PREAMBLE@ — generate MathJax macro configuration
--   * @graph REGISTRY@ — emit Graphviz DOT from registry
--
-- Each subcommand dispatches to its corresponding module
-- ('Semtex.Extract', 'Semtex.Merge', 'Semtex.Validate', 'Semtex.MathJax',
-- 'Semtex.Graph').
module Main (main) where

import Options.Applicative

import Semtex.Extract (extractFiles)
import Semtex.Graph (runGraph)
import Semtex.Merge (loadAndMerge)
import Semtex.Validate (runValidate)
import Semtex.MathJax (runMathJax)

-- | Sum type for all supported commands.
data Command
  = Extract [FilePath]
  | Merge FilePath
  | Validate FilePath (Maybe FilePath)
  | MathJax FilePath
  | Graph FilePath

-- | Parser for the full CLI.
--
-- Produces a 'Command' that determines which subcommand was invoked.
commandParser :: ParserInfo Command
commandParser = info (helper <*> cmds) $
  fullDesc
  <> progDesc "semtex -- semantic TeX preprocessor"
  <> header "semtex - extract concept graphs from annotated TeX"
  where
    cmds = subparser $
         command "extract"  (info extractCmd  (progDesc "Extract per-file .semtex.json"))
      <> command "merge"    (info mergeCmd    (progDesc "Merge .semtex.json -> registry.json"))
      <> command "validate" (info validateCmd (progDesc "Validate registry"))
      <> command "mathjax"  (info mathjaxCmd  (progDesc "Generate MathJax macro config"))
      <> command "graph"    (info graphCmd    (progDesc "Emit Graphviz DOT from registry"))

    extractCmd  = Extract <$> some (argument str (metavar "FILE..."))
    mergeCmd    = Merge <$> argument str (metavar "DIR")
    validateCmd = Validate
      <$> argument str (metavar "REGISTRY")
      <*> optional (argument str (metavar "PROJECT_ROOT"))
    mathjaxCmd  = MathJax <$> argument str (metavar "PREAMBLE")
    graphCmd    = Graph <$> argument str (metavar "REGISTRY")

-- | Main entry point.
--
-- Parses command-line arguments and dispatches to the appropriate handler.
main :: IO ()
main = do
  cmd <- execParser commandParser
  case cmd of
    Extract files     -> extractFiles files
    Merge dir         -> loadAndMerge dir
    Validate reg root -> runValidate reg root
    MathJax preamble  -> runMathJax preamble
    Graph reg         -> runGraph reg
