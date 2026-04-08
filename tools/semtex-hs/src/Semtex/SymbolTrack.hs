{-# LANGUAGE GHC2021 #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | Symbol tracking for semtex v2.
--
-- Builds the symbol table: which atom introduces which instance macro,
-- scans all atoms for usage of instance macros, computes auto-inferred
-- dependency edges, and validates constraints (no \newmath on type macros,
-- no duplicate instance macros).
module Semtex.SymbolTrack
  ( -- * Symbol table
    SymbolTable(..)
  , buildSymbolTable
    -- * Usage scanning
  , scanUsages
    -- * Dependency inference
  , inferDependencies
    -- * Validation
  , validateSymbols
  ) where

import Data.Map.Strict (Map)
import Data.Set        (Set)
import Data.Text       (Text)

import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set
import qualified Data.Text       as T

import Semtex.Types

-- ---------------------------------------------------------------------------
-- Symbol table
-- ---------------------------------------------------------------------------

-- | The symbol table maps instance macro names to the UID of the atom
-- that introduces them.
data SymbolTable = SymbolTable
  { stIntroductions :: !(Map Text Uid)
    -- ^ macro name -> UID of the introducing atom
  , stTypeMacros    :: !(Set Text)
    -- ^ Known type macro names (from preamble)
  , stInstanceNames :: !(Set Text)
    -- ^ All known instance macro names
  }
  deriving stock (Eq, Show)

-- | Build the symbol table from a list of atoms with UIDs.
-- Each atom's symbolIntros records which macros it introduces.
buildSymbolTable :: Set Text -> Set Text -> [Atom] -> SymbolTable
buildSymbolTable typeMacros instanceNames atoms =
  let introMap = Map.fromList
        [ (introMacroName intro, uid)
        | a <- atoms
        , Just uid <- [atomUid a]
        , intro <- atomSymbolIntros a
        , Set.member (introMacroName intro) instanceNames
        ]
  in  SymbolTable
        { stIntroductions = introMap
        , stTypeMacros = typeMacros
        , stInstanceNames = instanceNames
        }

-- ---------------------------------------------------------------------------
-- Usage scanning
-- ---------------------------------------------------------------------------

-- | Scan an atom's content for usage of instance macros.
-- Returns the set of instance macro names used (but not introduced) in
-- this atom.
scanAtomUsages :: Set Text -> Atom -> Set Text
scanAtomUsages instanceNames atom =
  let content = atomContent atom
      -- Find all backslash-prefixed names in the content
      usedMacros = findMacroNames content
      -- Intersect with known instance macros
      usedInstances = Set.intersection usedMacros instanceNames
      -- Subtract macros this atom introduces
      introduced = Set.fromList [introMacroName i | i <- atomSymbolIntros atom]
  in  Set.difference usedInstances introduced

-- | Find all macro names (backslash followed by alphabetic chars) in text.
findMacroNames :: Text -> Set Text
findMacroNames = go Set.empty
  where
    go acc t =
      case T.breakOn "\\" t of
        (_, rest)
          | T.null rest -> acc
          | otherwise ->
              let afterSlash = T.drop 1 rest
                  name = T.takeWhile isAlpha' afterSlash
                  remaining = T.drop (T.length name) afterSlash
              in  if T.null name
                    then go acc remaining
                    else go (Set.insert name acc) remaining
    isAlpha' c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

-- | Scan all atoms for instance macro usages.
-- Returns atoms with their atomSymbolUsages field populated.
scanUsages :: Set Text -> [Atom] -> [Atom]
scanUsages instanceNames = map updateAtom
  where
    updateAtom a = a { atomSymbolUsages = scanAtomUsages instanceNames a }

-- ---------------------------------------------------------------------------
-- Dependency inference
-- ---------------------------------------------------------------------------

-- | Infer dependency edges from symbol usage.
-- If atom X uses a macro introduced by atom Y, then X depends on Y.
-- Returns a map from each atom's UID to the UIDs it depends on.
inferDependencies :: SymbolTable -> [Atom] -> Map Uid [Uid]
inferDependencies st atoms =
  Map.fromList
    [ (uid, deps)
    | a <- atoms
    , Just uid <- [atomUid a]
    , let usages = atomSymbolUsages a
          deps = [ introUid
                 | macroName <- Set.toList usages
                 , Just introUid <- [Map.lookup macroName (stIntroductions st)]
                 , Just uid /= Just introUid  -- no self-deps
                 ]
    , not (null deps)
    ]

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

-- | Validate symbol constraints. Returns a list of blocking errors.
--
-- Rules:
-- 1. \newmath must not wrap a type macro directly.
-- 2. No two atoms may introduce the same instance macro.
validateSymbols :: Set Text -> [Atom] -> [SemtexError]
validateSymbols typeMacros atoms =
  concatMap (checkNewMathOnTypeMacro typeMacros) atoms
  ++ checkDuplicateInstances atoms

-- | Check that \newmath does not wrap a type macro directly.
-- \newmath{\Category{C}} is fine (wraps an instance usage).
-- \newmath{\Category} alone (without argument) would be wrapping
-- the type macro itself, which is an error.
checkNewMathOnTypeMacro :: Set Text -> Atom -> [SemtexError]
checkNewMathOnTypeMacro typeMacros atom =
  [ NewMathOnTypeMacro macroName (introContent intro) (atomFile atom)
  | intro <- atomSymbolIntros atom
  , let content = T.strip (introContent intro)
        macroName = extractBareTypeMacro content
  , not (T.null macroName)
  , Set.member macroName typeMacros
  ]

-- | Extract a bare type macro reference from \newmath content.
-- Returns the macro name if the content is just \MacroName with no argument.
-- Returns empty text if the content has arguments (which is fine).
extractBareTypeMacro :: Text -> Text
extractBareTypeMacro content =
  case T.uncons content of
    Just ('\\', rest) ->
      let name = T.takeWhile (\c -> (c >= 'a' && c <= 'z')
                                 || (c >= 'A' && c <= 'Z')) rest
          after = T.drop (T.length name) rest
      in  if T.null (T.strip after) || T.isPrefixOf "}" (T.strip after)
            then name  -- bare macro, no argument
            else ""    -- has arguments, this is fine
    _ -> ""

-- | Check for duplicate instance macro introductions across atoms.
checkDuplicateInstances :: [Atom] -> [SemtexError]
checkDuplicateInstances atoms =
  let -- Collect all (macroName, file) pairs for introductions
      allIntros :: [(Text, FilePath)]
      allIntros =
        [ (introMacroName intro, atomFile a)
        | a <- atoms
        , intro <- atomSymbolIntros a
        ]

      -- Group by macro name
      grouped :: Map Text [FilePath]
      grouped = Map.fromListWith (++) [(name, [fp]) | (name, fp) <- allIntros]

      -- Find duplicates
      dups = [ DuplicateInstanceMacro name fp1 fp2
             | (name, fps) <- Map.toList grouped
             , (fp1, fp2) <- case fps of
                 (x : y : _) -> [(y, x)]
                 _            -> []
             ]
  in  dups
