{-# LANGUAGE GHC2021 #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | MathJax configuration generation for the semtex documentation pipeline.
--
-- Reads a @preamble.tex@ file and emits a JavaScript MathJax configuration
-- block to stdout.  The output makes all TeX macros available for browser-side
-- math rendering on the documentation site.
--
-- Corresponds to the @mathjax PREAMBLE@ sub-command of the semtex CLI.
module Semtex.MathJax
  ( -- * MathJax config generation
    runMathJax
  ) where

import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

import Semtex.Extract.Parser
  ( NewCommandDef(..)
  , MathOpDef(..)
  , parseNewCommands
  , parseDeclareMathOps
  )

-- ---------------------------------------------------------------------------
-- Public entry point
-- ---------------------------------------------------------------------------

-- | Parse @preamblePath@ and print a MathJax JavaScript configuration block
-- to stdout.  The shell script that invokes this command redirects stdout to
-- the desired output file.
--
-- The generated block assigns @window.MathJax@ before MathJax is loaded, so
-- the library picks up the macro table at initialisation time.
runMathJax :: FilePath -> IO ()
runMathJax preamblePath = do
  content <- TIO.readFile preamblePath
  let newCmds = parseNewCommands content
      mathOps  = parseDeclareMathOps content
      macros   = buildMacroMap newCmds mathOps
  TIO.putStr (renderMathJaxConfig macros)

-- ---------------------------------------------------------------------------
-- Semantic-only macros (not meaningful to MathJax)
-- ---------------------------------------------------------------------------

-- | Macros that carry semantic metadata for the concept graph but have no
-- mathematical rendering in MathJax.  These are omitted from the JS output.
skipMacros :: Set Text
skipMacros = Set.fromList
  [ "concept", "depends", "implements", "axiom", "uses"
  , "stacksref", "nlabref", "newterm", "newmath"
  ]

-- ---------------------------------------------------------------------------
-- Macro map
-- ---------------------------------------------------------------------------

-- | A single MathJax macro entry, distinguishing zero-argument macros from
-- those that take @n >= 1@ arguments.
data MacroEntry
  = SimpleMacro !Text       -- ^ Body only; no argument slots.
  | ArgedMacro  !Text !Int  -- ^ Body using @#1@..@#n@ placeholders, plus arity.
  deriving stock (Eq, Show)

-- | Build the macro map from parsed preamble definitions.
--
-- @\\newcommand@ entries in 'skipMacros' are omitted.  Backslashes in macro
-- bodies are doubled so that the resulting JS string literals contain the
-- single backslash that TeX expects.
--
-- @\\DeclareMathOperator{\\Foo}{bar}@ becomes the simple macro
-- @\\operatorname{bar}@.
buildMacroMap :: [NewCommandDef] -> [MathOpDef] -> Map Text MacroEntry
buildMacroMap newCmds mathOps =
  Map.fromList (map fromNewCmd filtered ++ map fromMathOp mathOps)
  where
    filtered = filter (\d -> not (Set.member (ncdName d) skipMacros)) newCmds

    fromNewCmd :: NewCommandDef -> (Text, MacroEntry)
    fromNewCmd d =
      let body = cleanBody (ncdBody d)
      in case ncdNArgs d of
           Just n  -> (ncdName d, ArgedMacro body n)
           Nothing -> (ncdName d, SimpleMacro body)

    fromMathOp :: MathOpDef -> (Text, MacroEntry)
    fromMathOp d =
      -- The JS string needs one backslash, so we write two here.
      (modName d, SimpleMacro ("\\\\operatorname{" <> modText d <> "}"))

-- | Clean a TeX macro body for embedding in a JS string literal.
--
-- Steps:
--
-- 1. Strip TeX line comments (@%@ to end of line).
-- 2. Collapse runs of whitespace to a single space and strip.
-- 3. Escape backslashes: @\\@ -> @\\\\@ (JS string needs literal @\\@).
cleanBody :: Text -> Text
cleanBody =
    escapeBackslashes
  . T.strip
  . collapseWhitespace
  . stripComments
  where
    -- Remove % ... \n
    stripComments :: Text -> Text
    stripComments t =
      T.unlines
        [ T.takeWhile (/= '%') line
        | line <- T.lines t
        ]

    -- Replace any run of whitespace with a single space
    collapseWhitespace :: Text -> Text
    collapseWhitespace = T.unwords . T.words

    -- Double every backslash
    escapeBackslashes :: Text -> Text
    escapeBackslashes = T.replace "\\" "\\\\"

-- ---------------------------------------------------------------------------
-- JS rendering
-- ---------------------------------------------------------------------------

-- | Render the full MathJax configuration block as 'Text'.
--
-- Output format:
--
-- @
--     MathJax = {
--       tex: {
--         inlineMath: [['\\(', '\\)']],
--         displayMath: [['\\[', '\\]']],
--         macros: {
--           Ab: '\\\\mathsf{Ab}',
--           Category: ['\\\\mathsf{#1}', 1],
--           ...
--         }
--       }
--     };
-- @
--
-- Macros are sorted alphabetically.  The last entry carries no trailing comma.
renderMathJaxConfig :: Map Text MacroEntry -> Text
renderMathJaxConfig macros =
  T.unlines
    [ "    MathJax = {"
    , "      tex: {"
    , "        inlineMath: [['\\\\(', '\\\\)']],"
    , "        displayMath: [['\\\\[', '\\\\]']],"
    , "        macros: {"
    , T.intercalate "\n" macroLines
    , "        }"
    , "      }"
    , "    };"
    ]
  where
    entries    = Map.toAscList macros
    total      = length entries
    macroLines = zipWith renderEntry [1 ..] entries

    renderEntry :: Int -> (Text, MacroEntry) -> Text
    renderEntry idx (name, entry) =
      let comma  = if idx == total then "" else ","
          indent = "          "
      in case entry of
           SimpleMacro body ->
             indent <> name <> ": '" <> body <> "'" <> comma
           ArgedMacro body n ->
             indent <> name <> ": ['" <> body <> "', " <> T.pack (show n) <> "]" <> comma
