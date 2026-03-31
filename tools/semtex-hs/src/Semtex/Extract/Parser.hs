{-# LANGUAGE GHC2021 #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | Megaparsec-based parser module for the semtex semantic TeX preprocessor.
--
-- These parsers extract metadata from TeX lines annotated with semtex macros.
-- They are __not__ full TeX parsers: they scan for specific macro invocations
-- and use brace-balanced extraction where needed. This is the Haskell port of
-- the extraction logic in @tools/semtex.py@, with the key improvement that
-- 'bracedGroup' handles arbitrary nesting rather than ad-hoc regex.
--
-- The semtex macro vocabulary (defined in @src/spec/preamble.tex@):
--
-- * @\\concept{id}{Display Name}@ -- declares a concept
-- * @\\depends{concept-id}@       -- hard dependency
-- * @\\uses{concept-id}@          -- weak reference
-- * @\\implements{lang}{module}@  -- cross-language link
-- * @\\axiom{concept-id}{name}@   -- names a law
-- * @\\stacksref{tag}@            -- Stacks Project reference
-- * @\\nlabref{page}@             -- nLab reference
-- * @\\newterm{term}@             -- terminology introduction
-- * @\\newmath{symbol}@           -- symbol introduction
-- * @\\label{...}@                -- TeX label
module Semtex.Extract.Parser
  ( -- * Line-level extractors
    extractConcept
  , extractDepends
  , extractUses
  , extractImplements
  , extractAxiom
  , extractStacksRef
  , extractNlabRef
  , extractNewTerm
  , extractNewMath
  , extractLabel
    -- * Brace-balanced utilities
  , bracedGroup
    -- * Multi-line parsers (for MathJax)
  , parseNewCommands
  , parseDeclareMathOps
  , NewCommandDef(..)
  , MathOpDef(..)
  ) where

import Data.Text (Text)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char

import qualified Data.Text as T

-- ---------------------------------------------------------------------------
-- Parser type
-- ---------------------------------------------------------------------------

-- | The base parser type: parses 'Text' with no custom error component.
type Parser = Parsec Void Text

-- ---------------------------------------------------------------------------
-- Brace-balanced core
-- ---------------------------------------------------------------------------

-- | Parse a brace-balanced group @{...}@, returning the content between the
-- outermost braces. Handles arbitrary nesting: @{a{b{c}d}e}@ yields
-- @"a{b{c}d}e"@. Fails if the opening @{@ is not present or if the group
-- is unclosed.
--
-- This is the critical improvement over the Python regex approach: regexes
-- cannot handle arbitrary nesting, so @\\newmath{\\Functor{F}}@ would fail
-- a naive @[^}]+@ match. 'bracedGroup' handles such cases correctly.
bracedGroup :: Parser Text
bracedGroup = do
  _ <- char '{'
  go (0 :: Int) []
  where
    go depth acc = do
      c <- anySingle
      case c of
        '{' -> go (depth + 1) (c : acc)
        '}' ->
          if depth == 0
            then return (T.pack (reverse acc))
            else go (depth - 1) (c : acc)
        _   -> go depth (c : acc)

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- | Scan through 'Text' collecting all non-overlapping results of a parser.
-- Uses @skipManyTill anySingle (try p)@ to advance past non-matching content.
-- Handles EOF by returning the accumulated list.
findAll :: Parser a -> Text -> [a]
findAll p input = case parse (loop []) "<findAll>" input of
  Left  _   -> []
  Right xs  -> xs
  where
    loop acc = do
      done <- atEnd
      if done
        then return (reverse acc)
        else do
          mx <- optional (try p)
          case mx of
            Just x  -> loop (x : acc)
            Nothing -> anySingle >> loop acc

-- | Parse the literal macro name @\\name@ (backslash then exact ASCII name).
-- Does not consume what follows.
macroName :: String -> Parser ()
macroName name = try $ do
  _ <- char '\\'
  _ <- chunk (T.pack name)
  return ()

-- | Advance past any character until the macro @\\name@ is found, then
-- consume it. Fails only at EOF without a match.
skipToMacro :: String -> Parser ()
skipToMacro name = skipManyTill anySingle (macroName name)

-- | One single-arg macro occurrence: finds @\\name{arg}@ anywhere in
-- remaining input and returns the trimmed content of the brace group.
singleArgOccurrence :: String -> Parser Text
singleArgOccurrence name = do
  skipToMacro name
  T.strip <$> bracedGroup

-- | Two single-arg macro occurrences in sequence: @\\name{a}{b}@.
-- Returns @(T.strip a, T.strip b)@.
twoArgOccurrence :: String -> Parser (Text, Text)
twoArgOccurrence name = do
  skipToMacro name
  a <- T.strip <$> bracedGroup
  b <- T.strip <$> bracedGroup
  return (a, b)

-- ---------------------------------------------------------------------------
-- Line-level extractors
-- ---------------------------------------------------------------------------

-- | Extract the first @\\concept{id}{Display Name}@ occurrence on a line.
-- Only the first match is meaningful (the Python tool stops at the first
-- occurrence and resets context). Returns @'Nothing'@ if no @\\concept@
-- is present.
--
-- Example: @\\concept{category}{Category}@ yields @Just ("category", "Category")@.
extractConcept :: Text -> Maybe (Text, Text)
extractConcept = parseMaybe (twoArgOccurrence "concept")

-- | Extract all @\\depends{concept-id}@ occurrences on a line, in order.
--
-- Example: @\\depends{category} \\depends{functor}@ yields
-- @["category", "functor"]@.
extractDepends :: Text -> [Text]
extractDepends = findAll (singleArgOccurrence "depends")

-- | Extract all @\\uses{concept-id}@ occurrences on a line, in order.
--
-- Weak references: the current concept mentions but does not depend on
-- the referenced concept.
extractUses :: Text -> [Text]
extractUses = findAll (singleArgOccurrence "uses")

-- | Extract all @\\implements{lang}{module}@ occurrences on a line.
-- Returns @(language, module-or-path)@ pairs.
--
-- Example: @\\implements{haskell}{Cat.Functor}@ yields
-- @[("haskell", "Cat.Functor")]@.
extractImplements :: Text -> [(Text, Text)]
extractImplements = findAll (twoArgOccurrence "implements")

-- | Extract all @\\axiom{concept-id}{axiom-name}@ occurrences on a line.
-- Returns only the axiom name (second argument), discarding the concept-id,
-- matching the behaviour of @semtex.py@.
--
-- Example: @\\axiom{category}{left-unit}@ yields @["left-unit"]@.
extractAxiom :: Text -> [Text]
extractAxiom = findAll (snd <$> twoArgOccurrence "axiom")

-- | Extract all @\\stacksref{tag}@ occurrences on a line.
--
-- Example: @\\stacksref{0014}@ yields @["0014"]@.
extractStacksRef :: Text -> [Text]
extractStacksRef = findAll (singleArgOccurrence "stacksref")

-- | Extract all @\\nlabref{page}@ occurrences on a line.
--
-- Example: @\\nlabref{category}@ yields @["category"]@.
extractNlabRef :: Text -> [Text]
extractNlabRef = findAll (singleArgOccurrence "nlabref")

-- | Extract all @\\newterm{term}@ occurrences on a line.
--
-- Example: @\\newterm{composition}@ yields @["composition"]@.
extractNewTerm :: Text -> [Text]
extractNewTerm = findAll (singleArgOccurrence "newterm")

-- | Extract all @\\newmath{symbol}@ occurrences on a line.
-- Uses 'bracedGroup' for brace-balanced extraction, so nested macros such as
-- @\\newmath{\\Functor{F}}@ are handled correctly (unlike the Python regex
-- which supports only one level of nesting).
--
-- Example: @\\newmath{\\Functor{F} \\lto \\Functor{G}}@ yields the full inner
-- text as a single entry.
extractNewMath :: Text -> [Text]
extractNewMath = findAll $ do
  skipToMacro "newmath"
  T.strip <$> bracedGroup

-- | Extract all @\\label{...}@ occurrences on a line, returning raw label
-- text. The caller is responsible for filtering out @concept:@ and @axiom:@
-- prefixes (those are generated by @\\concept@ and @\\axiom@ macros and
-- carry no additional information for the concept graph).
--
-- Example: @\\label{fig:adjunction}@ yields @["fig:adjunction"]@.
extractLabel :: Text -> [Text]
extractLabel = findAll (singleArgOccurrence "label")

-- ---------------------------------------------------------------------------
-- Multi-line parsers (for MathJax)
-- ---------------------------------------------------------------------------

-- | A parsed @\\newcommand@ (or @\\newcommand*@) definition.
data NewCommandDef = NewCommandDef
  { ncdName  :: !Text
    -- ^ The macro name, without the leading backslash.
    -- E.g. @\\newcommand{\\Category}[1]{...}@ gives @ncdName = "Category"@.
  , ncdNArgs :: !(Maybe Int)
    -- ^ Optional arity annotation from @[n]@. @'Nothing'@ means zero-arg.
  , ncdBody  :: !Text
    -- ^ The body of the definition, as raw TeX text.
  } deriving stock (Eq, Show)

-- | A parsed @\\DeclareMathOperator@ definition.
data MathOpDef = MathOpDef
  { modName :: !Text
    -- ^ Operator name, without the leading backslash.
    -- E.g. @\\DeclareMathOperator{\\Hom}{Hom}@ gives @modName = "Hom"@.
  , modText :: !Text
    -- ^ The operator text argument.
  } deriving stock (Eq, Show)

-- ---------------------------------------------------------------------------
-- Internal multi-line parser helpers
-- ---------------------------------------------------------------------------

-- | Parser for a single @\\newcommand@ or @\\newcommand*@ definition.
-- Handles optional @[nargs]@ and uses 'bracedGroup' for both name and body.
newCommandP :: Parser NewCommandDef
newCommandP = do
  skipToMacro "newcommand"
  -- Consume optional star
  _ <- optional (char '*')
  -- Skip optional whitespace between \newcommand and {
  space
  -- Name: {\macroname}
  nameGroup <- bracedGroup
  let rawName = T.strip nameGroup
  name <-
    if T.isPrefixOf (T.singleton '\\') rawName
      then return (T.drop 1 rawName)   -- strip leading backslash
      else fail "newcommand name does not begin with \\"
  -- Skip whitespace
  space
  -- Optional [nargs]
  mnargs <- optional $ do
    _ <- char '['
    digits <- takeWhile1P (Just "digit") (\c -> c >= '0' && c <= '9')
    _ <- char ']'
    case reads (T.unpack digits) of
      [(n, "")] -> return (n :: Int)
      _         -> fail "expected integer in [nargs]"
  -- Skip whitespace
  space
  -- Body
  body <- bracedGroup
  return NewCommandDef
    { ncdName  = name
    , ncdNArgs = mnargs
    , ncdBody  = T.strip body
    }

-- | Parser for a single @\\DeclareMathOperator{\\name}{text}@ definition.
declareMathOpP :: Parser MathOpDef
declareMathOpP = do
  skipToMacro "DeclareMathOperator"
  space
  -- {\name}
  nameGroup <- bracedGroup
  let rawName = T.strip nameGroup
  name <-
    if T.isPrefixOf (T.singleton '\\') rawName
      then return (T.drop 1 rawName)
      else fail "DeclareMathOperator name does not begin with \\"
  space
  -- {text}
  txt <- T.strip <$> bracedGroup
  return MathOpDef { modName = name, modText = txt }

-- ---------------------------------------------------------------------------
-- Public multi-line parsers
-- ---------------------------------------------------------------------------

-- | Parse all @\\newcommand@ and @\\newcommand*@ definitions from full file
-- content (multi-line). The 'ncdBody' field retains TeX comments and
-- whitespace; callers should strip as needed for their target format.
--
-- Operates on the entire file as a single 'Text', not line-by-line, so
-- multi-line macro bodies are handled correctly.
parseNewCommands :: Text -> [NewCommandDef]
parseNewCommands = findAll newCommandP

-- | Parse all @\\DeclareMathOperator{\\name}{text}@ definitions from full
-- file content (multi-line).
--
-- Used by the MathJax config generator to emit @operatorname@ wrappers.
parseDeclareMathOps :: Text -> [MathOpDef]
parseDeclareMathOps = findAll declareMathOpP
