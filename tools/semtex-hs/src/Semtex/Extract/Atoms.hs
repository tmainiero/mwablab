{-# LANGUAGE GHC2021 #-}
{-# OPTIONS_GHC -Wall -Wcompat #-}

-- | Atom-level extraction for semtex v2.
--
-- Parses a TeX file into atoms: paragraphs and theorem environments.
-- Each atom gets tracked for symbol introductions (\newmath), symbol
-- usages, and metadata (\depends, \implements, etc.).
--
-- An "atom" is any paragraph or theorem environment. Paragraphs are
-- separated by blank lines. Theorem environments are delimited by
-- \begin{definition}...\end{definition} and similar.
module Semtex.Extract.Atoms
  ( -- * Atom extraction
    extractAtoms
  , extractAtomsFromFile
    -- * Preamble parsing
  , parseTypeMacros
  , parseInstanceMacros
    -- * Section tracking
  , SectionState(..)
  , initialSectionState
  ) where

import Data.Char          (isSpace)
import Data.List          (foldl')
import Data.Map.Strict    (Map)
import Data.Set           (Set)
import Data.Text          (Text)

import qualified Data.Map.Strict  as Map
import qualified Data.Set         as Set
import qualified Data.Text        as T
import qualified Data.Text.IO     as TIO

import Semtex.Extract.Parser
  ( NewCommandDef(..)
  , extractAxiom
  , extractConcept
  , extractDepends
  , extractImplements
  , extractLabel
  , extractNewMath
  , extractNewTerm
  , extractStacksRef
  , extractNlabRef
  , parseNewCommands
  )
import Semtex.Types
import Semtex.Uid (parseUidComment)

-- ---------------------------------------------------------------------------
-- Theorem environment names
-- ---------------------------------------------------------------------------

-- | The set of TeX theorem environment names that create atoms.
theoremEnvNames :: Set Text
theoremEnvNames = Set.fromList
  [ "definition", "theorem", "proposition", "lemma"
  , "corollary", "remark", "example", "proof"
  ]

-- | Map environment name to AtomType.
envToAtomType :: Text -> Maybe AtomType
envToAtomType "definition"  = Just AtomDefinition
envToAtomType "theorem"     = Just AtomTheorem
envToAtomType "proposition" = Just AtomProposition
envToAtomType "lemma"       = Just AtomLemma
envToAtomType "corollary"   = Just AtomCorollary
envToAtomType "remark"      = Just AtomRemark
envToAtomType "example"     = Just AtomExample
envToAtomType "proof"       = Just AtomProof
envToAtomType _             = Nothing

-- ---------------------------------------------------------------------------
-- Section state tracking
-- ---------------------------------------------------------------------------

-- | Tracks the current section nesting for display number computation.
data SectionState = SectionState
  { ssSection    :: !Int
  , ssSubsection :: !Int
  , ssBlock      :: !Int
    -- ^ Shared counter for all block types within the current subsection.
  }
  deriving stock (Eq, Show)

-- | Initial section state.
initialSectionState :: SectionState
initialSectionState = SectionState 0 0 0

-- | Compute the section path as a list of integers.
sectionPath :: SectionState -> [Int]
sectionPath ss
  | ssSection ss == 0 = []
  | ssSubsection ss == 0 = [ssSection ss]
  | otherwise = [ssSection ss, ssSubsection ss]

-- ---------------------------------------------------------------------------
-- Line classification
-- ---------------------------------------------------------------------------

data LineClass
  = LCBlank
  | LCSection
  | LCSubsection
  | LCBeginEnv !Text     -- theorem env name
  | LCEndEnv !Text       -- theorem env name
  | LCConcept !Text !Text -- id, name
  | LCUidComment !Uid
  | LCContent
  deriving stock (Eq, Show)

classifyLine :: Text -> LineClass
classifyLine line
  | isBlankLine line = LCBlank
  | Just uid <- parseUidComment line = LCUidComment uid
  | Just (cid, name) <- extractConcept line = LCConcept cid name
  | isSection line = LCSection
  | isSubsection line = LCSubsection
  | Just env <- beginEnv line = LCBeginEnv env
  | Just env <- endEnv line = LCEndEnv env
  | otherwise = LCContent

isBlankLine :: Text -> Bool
isBlankLine = T.all isSpace

isSection :: Text -> Bool
isSection line = T.isPrefixOf "\\section" (T.stripStart line)

isSubsection :: Text -> Bool
isSubsection line = T.isPrefixOf "\\subsection" (T.stripStart line)

-- | Extract the environment name from \begin{envname}.
beginEnv :: Text -> Maybe Text
beginEnv line =
  let stripped = T.stripStart line
  in  case T.stripPrefix "\\begin{" stripped of
        Just rest ->
          let envName = T.takeWhile (/= '}') rest
          in  if Set.member envName theoremEnvNames
                then Just envName
                else Nothing
        Nothing -> Nothing

-- | Extract the environment name from \end{envname}.
endEnv :: Text -> Maybe Text
endEnv line =
  let stripped = T.stripStart line
  in  case T.stripPrefix "\\end{" stripped of
        Just rest ->
          let envName = T.takeWhile (/= '}') rest
          in  if Set.member envName theoremEnvNames
                then Just envName
                else Nothing
        Nothing -> Nothing

-- ---------------------------------------------------------------------------
-- Atom builder (state machine)
-- ---------------------------------------------------------------------------

-- | Builder accumulating lines for the current atom.
data AtomBuilder = AtomBuilder
  { abType        :: !AtomType
  , abLines       :: ![Text]       -- in reverse order
  , abUid         :: !(Maybe Uid)
  , abConceptId   :: !(Maybe ConceptId)
  , abSymIntros   :: ![SymbolIntro]
  , abTermIntros  :: ![Text]
  , abDepends     :: ![ConceptId]
  , abImplements  :: !(Map Text [Text])
  , abAxioms      :: ![Text]
  , abStacksRefs  :: ![Tag]
  , abNlabRefs    :: ![Tag]
  , abLabels      :: ![Text]
  , abSectionPath :: ![Int]
  }

-- | Top-level extraction state.
data ExtractAtomState = ExtractAtomState
  { easCurrent    :: !(Maybe AtomBuilder)
  , easCompleted  :: ![Atom]            -- in reverse order
  , easSection    :: !SectionState
  , easConceptId  :: !(Maybe ConceptId) -- current concept scope
  , easInEnv      :: !(Maybe Text)      -- currently inside this env
  , easInstanceMacros :: !(Set Text)    -- known instance macro names
  }

-- | Initial extraction state.
initialExtractState :: Set Text -> ExtractAtomState
initialExtractState knownInstances = ExtractAtomState
  { easCurrent = Nothing
  , easCompleted = []
  , easSection = initialSectionState
  , easConceptId = Nothing
  , easInEnv = Nothing
  , easInstanceMacros = knownInstances
  }

-- | Create a fresh atom builder for a paragraph.
freshParagraph :: SectionState -> Maybe ConceptId -> AtomBuilder
freshParagraph ss mcid = AtomBuilder
  { abType = AtomParagraph
  , abLines = []
  , abUid = Nothing
  , abConceptId = mcid
  , abSymIntros = []
  , abTermIntros = []
  , abDepends = []
  , abImplements = Map.empty
  , abAxioms = []
  , abStacksRefs = []
  , abNlabRefs = []
  , abLabels = []
  , abSectionPath = sectionPath ss
  }

-- | Create a fresh atom builder for a theorem environment.
freshEnvAtom :: AtomType -> SectionState -> Maybe ConceptId -> AtomBuilder
freshEnvAtom atype ss mcid = (freshParagraph ss mcid) { abType = atype }

-- | Finalize a builder into an Atom.
finalizeAtom :: FilePath -> SectionState -> AtomBuilder -> Atom
finalizeAtom fp ss ab =
  let content = T.unlines (reverse (abLines ab))
      blockNum = ssBlock ss + 1
  in  Atom
        { atomUid = abUid ab
        , atomDisplayNumber = Nothing  -- computed later
        , atomType = abType ab
        , atomContent = content
        , atomFile = fp
        , atomConceptId = abConceptId ab
        , atomSymbolIntros = reverse (abSymIntros ab)
        , atomSymbolUsages = Set.empty  -- computed in SymbolTrack pass
        , atomTermIntros = reverse (abTermIntros ab)
        , atomDepends = reverse (abDepends ab)
        , atomImplements = abImplements ab
        , atomAxioms = reverse (abAxioms ab)
        , atomStacksRefs = reverse (abStacksRefs ab)
        , atomNlabRefs = reverse (abNlabRefs ab)
        , atomLabels = reverse (abLabels ab)
        , atomBackRefs = []
        , atomSectionPath = abSectionPath ab ++ [blockNum]
        }

-- | Check if a builder has any non-trivial content.
hasContent :: AtomBuilder -> Bool
hasContent ab = any (not . isBlankLine) (abLines ab)

-- | Process metadata extractors on a line, folding results into the builder.
extractMetadata :: Set Text -> AtomBuilder -> Text -> AtomBuilder
extractMetadata knownInstances ab line =
  let -- Symbol introductions: \newmath{...}
      newMaths = extractNewMath line
      intros = map mkIntro newMaths

      -- Terms: \newterm{...}
      terms = extractNewTerm line

      -- Dependencies, implements, etc.
      deps = extractDepends line
      impls = extractImplements line
      axioms = extractAxiom line
      stacks = extractStacksRef line
      nlabs = extractNlabRef line
      labels = extractLabel line
      filteredLabels = filter (\l ->
            not (T.isPrefixOf "concept:" l)
         && not (T.isPrefixOf "axiom:" l)) labels

  in  ab
        { abSymIntros = intros ++ abSymIntros ab
        , abTermIntros = terms ++ abTermIntros ab
        , abDepends = deps ++ abDepends ab
        , abImplements = foldl' addImpl (abImplements ab) impls
        , abAxioms = axioms ++ abAxioms ab
        , abStacksRefs = stacks ++ abStacksRefs ab
        , abNlabRefs = nlabs ++ abNlabRefs ab
        , abLabels = filteredLabels ++ abLabels ab
        }
  where
    mkIntro content =
      let macroName = extractMacroName knownInstances content
      in  SymbolIntro
            { introMacroName = macroName
            , introContent = content
            }

    addImpl m (lang, modName) =
      Map.insertWith (\_ old -> old ++ [modName]) lang [modName] m

-- | Extract the instance macro name from \newmath content.
-- If the content is like \Set or \ForgetAbToSet{...}, extract the macro name.
-- Falls back to the full content if no macro is found.
extractMacroName :: Set Text -> Text -> Text
extractMacroName knownInstances content =
  let stripped = T.strip content
  in  case T.uncons stripped of
        Just ('\\', rest) ->
          let name = T.takeWhile (\c -> c /= '{' && c /= ' '
                                     && c /= '\\' && c /= '}') rest
          in  if Set.member name knownInstances
                then name
                else content
        _ -> content

-- ---------------------------------------------------------------------------
-- Main extraction loop
-- ---------------------------------------------------------------------------

-- | Process all lines of a TeX file into atoms.
processLines :: FilePath -> Set Text -> [Text] -> [Atom]
processLines fp knownInstances lns =
  let initial = initialExtractState knownInstances
      final = foldl' (processLine fp) initial lns
      -- Close any open atom
      completed = case easCurrent final of
        Nothing -> easCompleted final
        Just ab ->
          if hasContent ab
            then finalizeAtom fp (easSection final) ab : easCompleted final
            else easCompleted final
  in  reverse completed

-- | Process a single line in the state machine.
processLine :: FilePath -> ExtractAtomState -> Text -> ExtractAtomState
processLine fp st line =
  case classifyLine line of
    LCBlank ->
      -- Blank line: close current paragraph atom (if any).
      -- Don't close theorem env atoms on blank lines.
      case easInEnv st of
        Just _ ->
          -- Inside a theorem env: blank lines are part of the atom.
          addLineToBuilder st line
        Nothing ->
          closeParagraph fp st

    LCSection ->
      let st' = closeParagraph fp st
          ss = easSection st'
          newSs = ss { ssSection = ssSection ss + 1
                     , ssSubsection = 0
                     , ssBlock = 0
                     }
      in  st' { easSection = newSs }

    LCSubsection ->
      let st' = closeParagraph fp st
          ss = easSection st'
          newSs = ss { ssSubsection = ssSubsection ss + 1
                     , ssBlock = 0
                     }
      in  st' { easSection = newSs }

    LCConcept cid _name ->
      let st' = st { easConceptId = Just cid }
      in  addLineToBuilder st' line

    LCUidComment uid ->
      -- Attach UID to the current or next atom.
      case easCurrent st of
        Just ab -> st { easCurrent = Just (ab { abUid = Just uid }) }
        Nothing ->
          -- Start a new paragraph builder with this UID pre-set.
          let ab = (freshParagraph (easSection st) (easConceptId st))
                     { abUid = Just uid }
          in  st { easCurrent = Just ab }

    LCBeginEnv envName ->
      let st' = closeParagraph fp st
          atype = case envToAtomType envName of
            Just t  -> t
            Nothing -> AtomParagraph
          ab = freshEnvAtom atype (easSection st') (easConceptId st')
      in  st' { easCurrent = Just ab
              , easInEnv = Just envName
              }

    LCEndEnv _envName ->
      let st' = addLineToBuilder st line
      in  closeCurrentAtom fp st' { easInEnv = Nothing }

    LCContent ->
      addLineToBuilder st line

-- | Add a line to the current builder, creating a paragraph if needed.
addLineToBuilder :: ExtractAtomState -> Text -> ExtractAtomState
addLineToBuilder st line =
  let ab = case easCurrent st of
        Just existing -> existing
        Nothing -> freshParagraph (easSection st) (easConceptId st)
      ab' = extractMetadata (easInstanceMacros st) ab line
      ab'' = ab' { abLines = line : abLines ab' }
  in  st { easCurrent = Just ab'' }

-- | Close the current atom if it has content and add it to completed.
closeCurrentAtom :: FilePath -> ExtractAtomState -> ExtractAtomState
closeCurrentAtom fp st =
  case easCurrent st of
    Nothing -> st
    Just ab ->
      if hasContent ab
        then
          let atom = finalizeAtom fp (easSection st) ab
              ss' = (easSection st) { ssBlock = ssBlock (easSection st) + 1 }
          in  st { easCurrent = Nothing
                 , easCompleted = atom : easCompleted st
                 , easSection = ss'
                 }
        else st { easCurrent = Nothing }

-- | Close the current atom only if it's a paragraph (not in a theorem env).
closeParagraph :: FilePath -> ExtractAtomState -> ExtractAtomState
closeParagraph fp st =
  case easInEnv st of
    Just _ -> st  -- don't close theorem envs on paragraph breaks
    Nothing -> closeCurrentAtom fp st

-- ---------------------------------------------------------------------------
-- Preamble parsing
-- ---------------------------------------------------------------------------

-- | Extract the set of type macro names from a preamble file.
-- Type macros are identified by convention: they take exactly one argument
-- and use \mathsf or similar typesetting commands.
-- The known type macros are: Category, Functor, NatTrans, Monoidal, Enrichment.
parseTypeMacros :: Text -> Set Text
parseTypeMacros content =
  let cmds = parseNewCommands content
      -- Type macros: defined with [1] arg and body contains \mathsf
      isTypeMacro cmd =
           ncdNArgs cmd == Just 1
        && T.isInfixOf "mathsf" (ncdBody cmd)
  in  Set.fromList [ncdName cmd | cmd <- cmds, isTypeMacro cmd]

-- | Extract instance macros: \newcommand definitions that are NOT type macros.
-- An instance macro is one whose body references a known type macro.
parseInstanceMacros :: Set Text -> Text -> Map Text InstanceMacro
parseInstanceMacros typeMacros content =
  let cmds = parseNewCommands content
      -- Skip semtex metadata macros and type macros themselves
      skipNames = Set.fromList
        [ "concept", "depends", "implements", "axiom", "uses"
        , "stacksref", "nlabref", "newterm", "newmath"
        , "lto", "lTo", "lmapsto", "op"
        ]
      isInstance cmd =
           not (Set.member (ncdName cmd) skipNames)
        && not (Set.member (ncdName cmd) typeMacros)
        && ncdNArgs cmd == Nothing  -- instance macros are typically 0-arg
        && usesTypeMacro (ncdBody cmd)

      usesTypeMacro body = any (\tm -> T.isInfixOf tm body) (Set.toList typeMacros)

      mkInstance cmd =
        let parentType = findTypeMacro (ncdBody cmd)
        in  ( ncdName cmd
            , InstanceMacro
                { imName = ncdName cmd
                , imNArgs = ncdNArgs cmd
                , imBody = ncdBody cmd
                , imTypeMacro = parentType
                }
            )

      findTypeMacro body =
        case filter (\tm -> T.isInfixOf tm body) (Set.toList typeMacros) of
          (tm : _) -> Just tm
          []       -> Nothing

  in  Map.fromList [mkInstance cmd | cmd <- cmds, isInstance cmd]

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- | Extract atoms from TeX content, given known instance macro names.
extractAtoms :: FilePath -> Set Text -> Text -> [Atom]
extractAtoms fp knownInstances content =
  let lns = T.lines content
      -- Filter out document wrapper lines
      filtered = filter (not . isDocumentWrapper) lns
  in  processLines fp knownInstances filtered

-- | Lines that are part of the document wrapper, not content.
isDocumentWrapper :: Text -> Bool
isDocumentWrapper line =
  let stripped = T.stripStart line
  in  any (`T.isPrefixOf` stripped)
        [ "\\documentclass"
        , "\\begin{document}"
        , "\\end{document}"
        , "\\maketitle"
        , "\\tableofcontents"
        , "\\usepackage"
        ]

-- | Extract atoms from a TeX file on disk.
extractAtomsFromFile :: Set Text -> FilePath -> IO AtomEnvelope
extractAtomsFromFile knownInstances fp = do
  content <- TIO.readFile fp
  let atoms = extractAtoms fp knownInstances content
  pure (AtomEnvelope fp atoms)
