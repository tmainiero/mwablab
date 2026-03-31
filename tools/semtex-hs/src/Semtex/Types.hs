-- | Core types for the semtex semantic TeX preprocessor.
--
-- Every record here corresponds to a data structure in the Python reference
-- implementation.  Fields are strict throughout; lazy thunks are not useful
-- at this granularity.
module Semtex.Types
  ( -- * Identifiers
    ConceptId
  , Tag
    -- * Core records
  , Concept(..)
  , Envelope(..)
  , Registry(..)
  , SymbolEntry(..)
    -- * Errors and warnings
  , SemtexError(..)
  , SemtexWarning(..)
  ) where

import Data.Map.Strict (Map)
import Data.Text       (Text)
import Data.Time       (UTCTime)

-- ---------------------------------------------------------------------------
-- Identifiers
-- ---------------------------------------------------------------------------

-- | Stable identifier for a concept block, e.g. @\"category\"@.
--   Populated from the mandatory first argument of @\\concept@.
type ConceptId = Text

-- | Stacks Project tag or nLab slug used as a cross-reference key,
--   e.g. @\"001A\"@ or @\"sheaf\"@.
type Tag = Text

-- ---------------------------------------------------------------------------
-- Core records
-- ---------------------------------------------------------------------------

-- | Semantic metadata extracted from a single @\\concept{...}@ block.
--
--   Fields that are computed in a later pass (@conceptBackRefs@) are still
--   present here so that the registry can store a fully-resolved value.
data Concept = Concept
  { -- | Stable identifier; the primary key across all registries.
    conceptId          :: !ConceptId
    -- | Human-readable display name from the @name@ key.
  , conceptName        :: !Text
    -- | Source file from which this concept was extracted.
  , conceptFile        :: !FilePath
    -- | Ordered, deduplicated list of concepts this one depends on.
    --   Determines topological sort order.
  , conceptDepends     :: ![ConceptId]
    -- | Concepts whose definitions this concept merely uses (soft
    --   dependency, not included in the DAG for ordering purposes).
  , conceptUses        :: ![ConceptId]
    -- | Names of axioms declared inside this concept block.
  , conceptAxioms      :: ![Text]
    -- | Language-to-module mapping from @implements@ keys,
    --   e.g. @fromList [(\"haskell\", [\"Data.Category\"])]@.
  , conceptImplements  :: !(Map Text [Text])
    -- | Stacks Project tags referenced by this concept.
  , conceptStacksRefs  :: ![Tag]
    -- | nLab page slugs referenced by this concept.
  , conceptNlabRefs    :: ![Tag]
    -- | Mathematical terms introduced or used by this concept.
  , conceptTerms       :: ![Text]
    -- | TeX macro bodies (brace-balanced) declared via @symbol@ keys.
  , conceptSymbols     :: ![Text]
    -- | Internal label strings, stripped of @concept:@ and @axiom:@ prefixes.
  , conceptLabels      :: ![Text]
    -- | Back-references computed during registry merge; not populated by
    --   the extraction pass.
  , conceptBackRefs    :: ![ConceptId]
  }
  deriving stock (Eq, Show)

-- | All concepts extracted from a single source file.
data Envelope = Envelope
  { -- | Absolute or project-relative path to the processed file.
    envelopeFile     :: !FilePath
    -- | Concepts extracted from this file, in source order.
  , envelopeConcepts :: ![Concept]
  }
  deriving stock (Eq, Show)

-- | One entry in the registry's symbol table, recording which concept
--   introduced a symbol and which language modules implement it.
data SymbolEntry = SymbolEntry
  { -- | Concept that declared the symbol.
    symConcept :: !ConceptId
    -- | Language-to-module mapping inherited from that concept's
    --   @implements@ field.
  , symLangs   :: !(Map Text [Text])
  }
  deriving stock (Eq, Show)

-- | Merged, globally consistent registry produced by the second pass.
--
--   The version field is always @1@ for this schema generation.
data Registry = Registry
  { -- | Schema version; always @1@.
    regVersion       :: !Int
    -- | Timestamp of registry generation (UTC).
  , regGenerated     :: !UTCTime
    -- | All known concepts, keyed by @ConceptId@.
  , regConcepts      :: !(Map ConceptId Concept)
    -- | Dependency DAG: maps each concept to the list of concepts it
    --   directly depends on (i.e., its out-neighbours in the DAG).
  , regDependencyDag :: !(Map ConceptId [ConceptId])
    -- | Topological ordering of all concepts; dependency-first.
  , regTopoOrder     :: ![ConceptId]
    -- | Maps each Stacks Project tag to the concept that cites it.
  , regStacksIndex   :: !(Map Tag ConceptId)
    -- | Maps each nLab slug to the concept that cites it.
  , regNlabIndex     :: !(Map Tag ConceptId)
    -- | Maps each TeX symbol body to its @SymbolEntry@.
  , regSymbolTable   :: !(Map Text SymbolEntry)
  }
  deriving stock (Eq, Show)

-- ---------------------------------------------------------------------------
-- Errors and warnings
-- ---------------------------------------------------------------------------

-- | Fatal errors that abort processing.
data SemtexError
  = -- | A concept declares a dependency that does not appear in any
    --   processed file.  First field is the depending concept; second is
    --   the missing dependency.
    MissingDependency !ConceptId !ConceptId
    -- | A cycle was detected in the dependency DAG.  The list gives the
    --   cycle in traversal order.
  | CycleDetected ![ConceptId]
    -- | An @implements@ entry names a source file that does not exist.
    --   Fields: concept, language, missing path.
  | MissingImplFile !ConceptId !Text !FilePath
  deriving stock (Eq, Show)

-- | Non-fatal warnings emitted during extraction or merge.
data SemtexWarning
  = -- | Two source files define a concept with the same @ConceptId@.
    --   The second definition shadows the first.
    --   Fields: duplicate id, path of the file that triggered the clash.
    DuplicateConcept !ConceptId !FilePath
    -- | A Stacks/nLab tag is cited by more than one concept.
    --   Fields: tag, all concepts that cite it.
  | DuplicateTag !Tag ![ConceptId]
    -- | An @implements@ key names a language not in the allowed set.
    --   Fields: concept, unknown language string.
  | UnknownLanguage !ConceptId !Text
  deriving stock (Eq, Show)
