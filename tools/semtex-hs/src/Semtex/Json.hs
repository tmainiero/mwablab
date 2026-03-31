-- | JSON serialisation and deserialisation for the core semtex types.
--
-- This module provides manual 'ToJSON' and 'FromJSON' instances rather than
-- deriving them via 'Generic' because the Haskell records use @camelCase@
-- field names while the JSON schema uses @snake_case@.  Keeping the mapping
-- explicit here means the on-disk format is independent of Haskell naming
-- conventions and stays stable across refactors.
--
-- Import this module wherever you need to read or write @registry.json@ or
-- the per-file @.semtex.json@ envelopes.
{-# OPTIONS_GHC -Wno-orphans #-}

module Semtex.Json
  ( -- $instances
    -- * Re-exports for convenience
    -- | This module provides 'ToJSON' and 'FromJSON' instances for
    -- the core semtex types. Import it to bring these instances into scope.
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.!=)
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Key     (fromText, toText)
import Data.Aeson.KeyMap  (delete, toList)
import qualified Data.Map.Strict  as Map

import Semtex.Types

-- $instances
-- All instances in this module are orphans with respect to 'Semtex.Types',
-- which is intentional: the types module stays aeson-free and the mapping
-- is expressed exactly once here.

-- ---------------------------------------------------------------------------
-- Concept
-- ---------------------------------------------------------------------------

-- | Serialises a 'Concept' to the canonical JSON object.
--
-- Field mapping (Haskell -> JSON):
--
-- > conceptId           -> "concept_id"
-- > conceptName         -> "name"
-- > conceptFile         -> "file"
-- > conceptDepends      -> "depends"
-- > conceptUses         -> "uses"
-- > conceptAxioms       -> "axioms"
-- > conceptImplements   -> "implements"
-- > conceptStacksRefs   -> "stacks_refs"
-- > conceptNlabRefs     -> "nlab_refs"
-- > conceptTerms        -> "terms_introduced"
-- > conceptSymbols      -> "symbols_introduced"
-- > conceptLabels       -> "labels"
-- > conceptBackRefs     -> "back_refs"
instance ToJSON Concept where
  toJSON c = object
    [ "concept_id"         .= conceptId         c
    , "name"               .= conceptName        c
    , "file"               .= conceptFile        c
    , "depends"            .= conceptDepends     c
    , "uses"               .= conceptUses        c
    , "axioms"             .= conceptAxioms      c
    , "implements"         .= conceptImplements  c
    , "stacks_refs"        .= conceptStacksRefs  c
    , "nlab_refs"          .= conceptNlabRefs    c
    , "terms_introduced"   .= conceptTerms       c
    , "symbols_introduced" .= conceptSymbols     c
    , "labels"             .= conceptLabels      c
    , "back_refs"          .= conceptBackRefs    c
    ]

-- | Parses a 'Concept' from the canonical JSON object.
--
-- The @back_refs@ field is optional and defaults to @[]@; this allows
-- reading envelopes produced before the back-reference pass has run.
instance FromJSON Concept where
  parseJSON = withObject "Concept" $ \o ->
    Concept
      <$> o .:  "concept_id"
      <*> o .:  "name"
      <*> o .:  "file"
      <*> o .:  "depends"
      <*> o .:  "uses"
      <*> o .:  "axioms"
      <*> o .:  "implements"
      <*> o .:  "stacks_refs"
      <*> o .:  "nlab_refs"
      <*> o .:  "terms_introduced"
      <*> o .:  "symbols_introduced"
      <*> o .:  "labels"
      <*> o .:? "back_refs" .!= []

-- ---------------------------------------------------------------------------
-- Envelope
-- ---------------------------------------------------------------------------

-- | Serialises an 'Envelope' to a two-field JSON object.
--
-- > envelopeFile     -> "file"
-- > envelopeConcepts -> "concepts"
instance ToJSON Envelope where
  toJSON e = object
    [ "file"     .= envelopeFile     e
    , "concepts" .= envelopeConcepts e
    ]

-- | Parses an 'Envelope' from a JSON object with @file@ and @concepts@ keys.
instance FromJSON Envelope where
  parseJSON = withObject "Envelope" $ \o ->
    Envelope
      <$> o .: "file"
      <*> o .: "concepts"

-- ---------------------------------------------------------------------------
-- SymbolEntry
-- ---------------------------------------------------------------------------

-- | Serialises a 'SymbolEntry' to a JSON object with dynamic language keys.
--
-- The fixed @concept@ key holds the owning 'ConceptId'.  Every entry in
-- 'symLangs' becomes an additional top-level key whose name is the language
-- string (e.g. @\"haskell\"@, @\"agda\"@) and whose value is the module list.
--
-- Example output:
--
-- > {"concept": "functor", "haskell": ["Cat.Functor"], "agda": ["Cat.Functor"]}
instance ToJSON SymbolEntry where
  toJSON se =
    let fixedPair  = [ "concept" .= symConcept se ]
        langPairs  = [ fromText lang .= mods
                     | (lang, mods) <- Map.toList (symLangs se)
                     ]
    in  object (fixedPair ++ langPairs)

-- | Parses a 'SymbolEntry' from a JSON object.
--
-- Consumes the mandatory @concept@ key, then treats every remaining key as a
-- language entry whose value must be a list of module strings.
instance FromJSON SymbolEntry where
  parseJSON = withObject "SymbolEntry" $ \o -> do
    cid  <- o .: "concept"
    -- Remove the "concept" key before iterating so we only see language keys.
    let langPairs = toList (delete "concept" o)
    langs <- traverse parseLangPair langPairs
    pure SymbolEntry
      { symConcept = cid
      , symLangs   = Map.fromList langs
      }
    where
      parseLangPair (k, v) = do
        mods <- parseJSON v
        -- Recover the Text representation of the aeson Key.
        let lang = toText k
        pure (lang, mods)

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

-- | Serialises a 'Registry' to the canonical @registry.json@ object.
--
-- Field mapping (Haskell -> JSON):
--
-- > regVersion       -> "version"
-- > regGenerated     -> "generated"
-- > regConcepts      -> "concepts"
-- > regDependencyDag -> "dependency_dag"
-- > regTopoOrder     -> "topological_order"
-- > regStacksIndex   -> "stacks_index"
-- > regNlabIndex     -> "nlab_index"
-- > regSymbolTable   -> "symbol_table"
instance ToJSON Registry where
  toJSON r = object
    [ "version"          .= regVersion       r
    , "generated"        .= regGenerated     r
    , "concepts"         .= regConcepts      r
    , "dependency_dag"   .= regDependencyDag r
    , "topological_order".= regTopoOrder     r
    , "stacks_index"     .= regStacksIndex   r
    , "nlab_index"       .= regNlabIndex     r
    , "symbol_table"     .= regSymbolTable   r
    ]

-- | Parses a 'Registry' from the canonical @registry.json@ object.
instance FromJSON Registry where
  parseJSON = withObject "Registry" $ \o ->
    Registry
      <$> o .: "version"
      <*> o .: "generated"
      <*> o .: "concepts"
      <*> o .: "dependency_dag"
      <*> o .: "topological_order"
      <*> o .: "stacks_index"
      <*> o .: "nlab_index"
      <*> o .: "symbol_table"
