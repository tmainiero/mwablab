-- | Core types for the semtex semantic TeX preprocessor.
--
-- v2 adds atom-level tracking with UIDs, display numbers, and symbol tracking
-- alongside the original concept-level types.
module Semtex.Types
  ( -- * Identifiers
    ConceptId
  , Tag
  , Uid(..)
  , DisplayNumber(..)
    -- * Atom types (v2)
  , AtomType(..)
  , Atom(..)
  , AtomEnvelope(..)
    -- * Symbol tracking (v2)
  , InstanceMacro(..)
  , SymbolIntro(..)
    -- * Core records (v1, kept for backward compat)
  , Concept(..)
  , Envelope(..)
  , Registry(..)
  , SymbolEntry(..)
    -- * v2 Registry
  , RegistryV2(..)
    -- * Errors and warnings
  , SemtexError(..)
  , SemtexWarning(..)
  ) where

import Data.Map.Strict (Map)
import Data.Set        (Set)
import Data.Text       (Text)
import Data.Time       (UTCTime)

-- ---------------------------------------------------------------------------
-- Identifiers
-- ---------------------------------------------------------------------------

-- | Stable identifier for a concept block, e.g. @"category"@.
--   Populated from the mandatory first argument of @\concept@.
type ConceptId = Text

-- | Stacks Project tag or nLab slug used as a cross-reference key,
--   e.g. @"001A"@ or @"sheaf"@.
type Tag = Text

-- | Base-35 unique identifier (0-9, A-Z minus O).
-- Sequential, monotonic, never reused. Like Stacks Project tags.
newtype Uid = Uid { unUid :: Text }
  deriving stock (Eq, Ord, Show)

-- | Hierarchical display number: section.subsection.block (e.g. "2.1.3").
-- Computed from document position, changes freely with reorganization.
newtype DisplayNumber = DisplayNumber { unDisplayNumber :: Text }
  deriving stock (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Atom types (v2)
-- ---------------------------------------------------------------------------

-- | Classification of an atom within a TeX document.
data AtomType
  = AtomParagraph
  | AtomDefinition
  | AtomTheorem
  | AtomProposition
  | AtomLemma
  | AtomCorollary
  | AtomRemark
  | AtomExample
  | AtomProof
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | An atom is any paragraph or theorem environment — the fundamental
-- unit of content in v2.  Every atom gets a UID and a display number.
data Atom = Atom
  { atomUid            :: !(Maybe Uid)
    -- ^ Stable UID from registry. Nothing for newly-discovered atoms.
  , atomDisplayNumber  :: !(Maybe DisplayNumber)
    -- ^ Hierarchical display number, computed from position.
  , atomType           :: !AtomType
    -- ^ What kind of atom this is.
  , atomContent        :: !Text
    -- ^ Raw TeX content of the atom.
  , atomFile           :: !FilePath
    -- ^ Source file this atom came from.
  , atomConceptId      :: !(Maybe ConceptId)
    -- ^ If this atom is inside a \concept block, which one.
  , atomSymbolIntros   :: ![SymbolIntro]
    -- ^ Instance macros introduced via \newmath in this atom.
  , atomSymbolUsages   :: !(Set Text)
    -- ^ Instance macro names used (but not introduced) in this atom.
  , atomTermIntros     :: ![Text]
    -- ^ Terms introduced via \newterm.
  , atomDepends        :: ![ConceptId]
    -- ^ Explicit \depends declarations.
  , atomImplements     :: !(Map Text [Text])
    -- ^ Language-to-module mapping from \implements.
  , atomAxioms         :: ![Text]
    -- ^ Axiom names from \axiom.
  , atomStacksRefs     :: ![Tag]
    -- ^ Stacks Project references.
  , atomNlabRefs       :: ![Tag]
    -- ^ nLab references.
  , atomLabels         :: ![Text]
    -- ^ TeX labels.
  , atomBackRefs       :: ![Uid]
    -- ^ Back-references: UIDs of atoms that reference this one.
    -- Populated during merge, not extraction.
  , atomSectionPath    :: ![Int]
    -- ^ Section nesting as list of section counters, e.g. [2,1] for
    -- section 2, subsection 1. Used to compute display numbers.
  }
  deriving stock (Eq, Show)

-- | A symbol introduction via \newmath wrapping an instance macro.
data SymbolIntro = SymbolIntro
  { introMacroName :: !Text
    -- ^ The macro name, e.g. "Set" from \newmath{\Set}.
  , introContent   :: !Text
    -- ^ The full content inside \newmath{...}.
  }
  deriving stock (Eq, Show)

-- | An instance macro definition parsed from \newcommand.
data InstanceMacro = InstanceMacro
  { imName     :: !Text
    -- ^ Macro name without backslash, e.g. "Set".
  , imNArgs    :: !(Maybe Int)
    -- ^ Arity, if any.
  , imBody     :: !Text
    -- ^ Body of the definition.
  , imTypeMacro :: !(Maybe Text)
    -- ^ If this instance derives from a type macro, which one.
    -- e.g. for \newcommand{\Set}{\Category{Set}}, this is "Category".
  }
  deriving stock (Eq, Show)

-- | All atoms extracted from a single source file.
data AtomEnvelope = AtomEnvelope
  { aeFile  :: !FilePath
    -- ^ Path to the processed file.
  , aeAtoms :: ![Atom]
    -- ^ Atoms in source order.
  }
  deriving stock (Eq, Show)

-- ---------------------------------------------------------------------------
-- Core records (v1 — kept for backward compatibility)
-- ---------------------------------------------------------------------------

-- | Semantic metadata extracted from a single @\concept{...}@ block.
data Concept = Concept
  { conceptId          :: !ConceptId
  , conceptName        :: !Text
  , conceptFile        :: !FilePath
  , conceptDepends     :: ![ConceptId]
  , conceptUses        :: ![ConceptId]
  , conceptAxioms      :: ![Text]
  , conceptImplements  :: !(Map Text [Text])
  , conceptStacksRefs  :: ![Tag]
  , conceptNlabRefs    :: ![Tag]
  , conceptTerms       :: ![Text]
  , conceptSymbols     :: ![Text]
  , conceptLabels      :: ![Text]
  , conceptBackRefs    :: ![ConceptId]
  }
  deriving stock (Eq, Show)

-- | All concepts extracted from a single source file.
data Envelope = Envelope
  { envelopeFile     :: !FilePath
  , envelopeConcepts :: ![Concept]
  }
  deriving stock (Eq, Show)

-- | One entry in the registry's symbol table.
data SymbolEntry = SymbolEntry
  { symConcept :: !ConceptId
  , symLangs   :: !(Map Text [Text])
  }
  deriving stock (Eq, Show)

-- | Merged, globally consistent registry (v1).
data Registry = Registry
  { regVersion       :: !Int
  , regGenerated     :: !UTCTime
  , regConcepts      :: !(Map ConceptId Concept)
  , regDependencyDag :: !(Map ConceptId [ConceptId])
  , regTopoOrder     :: ![ConceptId]
  , regStacksIndex   :: !(Map Tag ConceptId)
  , regNlabIndex     :: !(Map Tag ConceptId)
  , regSymbolTable   :: !(Map Text SymbolEntry)
  }
  deriving stock (Eq, Show)

-- | v2 registry with atom-level tracking, UIDs, and symbol dependencies.
data RegistryV2 = RegistryV2
  { reg2Version       :: !Int
    -- ^ Schema version; always 2.
  , reg2Generated     :: !UTCTime
  , reg2NextUid       :: !Uid
    -- ^ Next UID to assign.
  , reg2Atoms         :: !(Map Uid Atom)
    -- ^ All atoms keyed by UID.
  , reg2Concepts      :: !(Map ConceptId Concept)
    -- ^ Legacy concept map (for backward compat with extract/merge).
  , reg2InstanceMacros :: !(Map Text InstanceMacro)
    -- ^ All known instance macros, keyed by name.
  , reg2TypeMacros    :: !(Set Text)
    -- ^ Known type macro names (from preamble).
  , reg2SymbolDeps    :: !(Map Uid [Uid])
    -- ^ Auto-inferred dependency DAG at atom level:
    -- atom X depends on atom Y if X uses a macro introduced in Y.
  , reg2BackRefs      :: !(Map Uid [Uid])
    -- ^ Inverse of reg2SymbolDeps: atom Y is referenced by atoms [...].
  , reg2ConceptDag    :: !(Map ConceptId [ConceptId])
    -- ^ Legacy concept-level dependency DAG.
  , reg2TopoOrder     :: ![Uid]
    -- ^ Topological ordering of atoms.
  , reg2StacksIndex   :: !(Map Tag Uid)
  , reg2NlabIndex     :: !(Map Tag Uid)
  }
  deriving stock (Eq, Show)

-- ---------------------------------------------------------------------------
-- Errors and warnings
-- ---------------------------------------------------------------------------

-- | Fatal errors that abort processing.
data SemtexError
  = MissingDependency !ConceptId !ConceptId
  | CycleDetected ![ConceptId]
  | MissingImplFile !ConceptId !Text !FilePath
    -- v2 errors
  | NewMathOnTypeMacro !Text !Text !FilePath
    -- ^ \newmath wraps a type macro directly.
    -- Fields: type macro name, atom content snippet, file.
  | DuplicateInstanceMacro !Text !FilePath !FilePath
    -- ^ Same instance macro defined in two places.
    -- Fields: macro name, first file, second file.
  | AtomCycleDetected ![Uid]
    -- ^ Cycle in the atom-level dependency DAG.
  deriving stock (Eq, Show)

-- | Non-fatal warnings emitted during extraction or merge.
data SemtexWarning
  = DuplicateConcept !ConceptId !FilePath
  | DuplicateTag !Tag ![ConceptId]
  | UnknownLanguage !ConceptId !Text
  deriving stock (Eq, Show)
