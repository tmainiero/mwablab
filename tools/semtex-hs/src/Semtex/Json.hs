-- | JSON serialisation and deserialisation for the core semtex types.
--
-- This module provides manual 'ToJSON' and 'FromJSON' instances rather than
-- deriving them via 'Generic' because the Haskell records use @camelCase@
-- field names while the JSON schema uses @snake_case@.
--
-- v2 adds instances for Atom, AtomType, Uid, DisplayNumber, SymbolIntro,
-- InstanceMacro, AtomEnvelope, and RegistryV2.
{-# OPTIONS_GHC -Wno-orphans #-}

module Semtex.Json
  ( -- $instances
  ) where

import Data.Aeson
  ( FromJSON(..)
  , FromJSONKey(..)
  , FromJSONKeyFunction(..)
  , ToJSON(..)
  , ToJSONKey(..)
  , ToJSONKeyFunction(..)
  , object
  , withObject
  , withText
  , (.!=)
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Key     (fromText, toText)
import Data.Aeson.KeyMap  (delete, toList)
import qualified Data.Aeson.Encoding as E
import qualified Data.Map.Strict  as Map
import qualified Data.Set         as Set
import qualified Data.Text        as T

import Semtex.Types

-- $instances
-- All instances in this module are orphans with respect to 'Semtex.Types'.

-- ---------------------------------------------------------------------------
-- Uid
-- ---------------------------------------------------------------------------

instance ToJSON Uid where
  toJSON (Uid t) = toJSON t

instance FromJSON Uid where
  parseJSON = withText "Uid" (pure . Uid)

instance ToJSONKey Uid where
  toJSONKey = ToJSONKeyText (fromText . unUid) (E.text . unUid)

instance FromJSONKey Uid where
  fromJSONKey = FromJSONKeyText Uid

-- ---------------------------------------------------------------------------
-- DisplayNumber
-- ---------------------------------------------------------------------------

instance ToJSON DisplayNumber where
  toJSON (DisplayNumber t) = toJSON t

instance FromJSON DisplayNumber where
  parseJSON = withText "DisplayNumber" (pure . DisplayNumber)

-- ---------------------------------------------------------------------------
-- AtomType
-- ---------------------------------------------------------------------------

instance ToJSON AtomType where
  toJSON AtomParagraph   = toJSON ("paragraph" :: T.Text)
  toJSON AtomDefinition  = toJSON ("definition" :: T.Text)
  toJSON AtomTheorem     = toJSON ("theorem" :: T.Text)
  toJSON AtomProposition = toJSON ("proposition" :: T.Text)
  toJSON AtomLemma       = toJSON ("lemma" :: T.Text)
  toJSON AtomCorollary   = toJSON ("corollary" :: T.Text)
  toJSON AtomRemark      = toJSON ("remark" :: T.Text)
  toJSON AtomExample     = toJSON ("example" :: T.Text)
  toJSON AtomProof       = toJSON ("proof" :: T.Text)

instance FromJSON AtomType where
  parseJSON = withText "AtomType" $ \t -> case t of
    "paragraph"   -> pure AtomParagraph
    "definition"  -> pure AtomDefinition
    "theorem"     -> pure AtomTheorem
    "proposition" -> pure AtomProposition
    "lemma"       -> pure AtomLemma
    "corollary"   -> pure AtomCorollary
    "remark"      -> pure AtomRemark
    "example"     -> pure AtomExample
    "proof"       -> pure AtomProof
    _             -> fail ("unknown AtomType: " ++ T.unpack t)

-- ---------------------------------------------------------------------------
-- SymbolIntro
-- ---------------------------------------------------------------------------

instance ToJSON SymbolIntro where
  toJSON si = object
    [ "macro_name" .= introMacroName si
    , "content"    .= introContent si
    ]

instance FromJSON SymbolIntro where
  parseJSON = withObject "SymbolIntro" $ \o ->
    SymbolIntro
      <$> o .: "macro_name"
      <*> o .: "content"

-- ---------------------------------------------------------------------------
-- InstanceMacro
-- ---------------------------------------------------------------------------

instance ToJSON InstanceMacro where
  toJSON im = object
    [ "name"        .= imName im
    , "nargs"       .= imNArgs im
    , "body"        .= imBody im
    , "type_macro"  .= imTypeMacro im
    ]

instance FromJSON InstanceMacro where
  parseJSON = withObject "InstanceMacro" $ \o ->
    InstanceMacro
      <$> o .:  "name"
      <*> o .:? "nargs"
      <*> o .:  "body"
      <*> o .:? "type_macro"

-- ---------------------------------------------------------------------------
-- Atom
-- ---------------------------------------------------------------------------

instance ToJSON Atom where
  toJSON a = object
    [ "uid"              .= atomUid a
    , "display_number"   .= atomDisplayNumber a
    , "type"             .= atomType a
    , "content"          .= atomContent a
    , "file"             .= atomFile a
    , "concept_id"       .= atomConceptId a
    , "symbol_intros"    .= atomSymbolIntros a
    , "symbol_usages"    .= Set.toList (atomSymbolUsages a)
    , "term_intros"      .= atomTermIntros a
    , "depends"          .= atomDepends a
    , "implements"       .= atomImplements a
    , "axioms"           .= atomAxioms a
    , "stacks_refs"      .= atomStacksRefs a
    , "nlab_refs"        .= atomNlabRefs a
    , "labels"           .= atomLabels a
    , "back_refs"        .= atomBackRefs a
    , "section_path"     .= atomSectionPath a
    ]

instance FromJSON Atom where
  parseJSON = withObject "Atom" $ \o ->
    Atom
      <$> o .:? "uid"
      <*> o .:? "display_number"
      <*> o .:  "type"
      <*> o .:  "content"
      <*> o .:  "file"
      <*> o .:? "concept_id"
      <*> o .:? "symbol_intros"    .!= []
      <*> (Set.fromList <$> (o .:? "symbol_usages" .!= []))
      <*> o .:? "term_intros"      .!= []
      <*> o .:? "depends"          .!= []
      <*> o .:? "implements"       .!= Map.empty
      <*> o .:? "axioms"           .!= []
      <*> o .:? "stacks_refs"      .!= []
      <*> o .:? "nlab_refs"        .!= []
      <*> o .:? "labels"           .!= []
      <*> o .:? "back_refs"        .!= []
      <*> o .:? "section_path"     .!= []

-- ---------------------------------------------------------------------------
-- AtomEnvelope
-- ---------------------------------------------------------------------------

instance ToJSON AtomEnvelope where
  toJSON e = object
    [ "file"  .= aeFile e
    , "atoms" .= aeAtoms e
    ]

instance FromJSON AtomEnvelope where
  parseJSON = withObject "AtomEnvelope" $ \o ->
    AtomEnvelope
      <$> o .: "file"
      <*> o .: "atoms"

-- ---------------------------------------------------------------------------
-- Concept (v1)
-- ---------------------------------------------------------------------------

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
-- Envelope (v1)
-- ---------------------------------------------------------------------------

instance ToJSON Envelope where
  toJSON e = object
    [ "file"     .= envelopeFile     e
    , "concepts" .= envelopeConcepts e
    ]

instance FromJSON Envelope where
  parseJSON = withObject "Envelope" $ \o ->
    Envelope
      <$> o .: "file"
      <*> o .: "concepts"

-- ---------------------------------------------------------------------------
-- SymbolEntry (v1)
-- ---------------------------------------------------------------------------

instance ToJSON SymbolEntry where
  toJSON se =
    let fixedPair  = [ "concept" .= symConcept se ]
        langPairs  = [ fromText lang .= mods
                     | (lang, mods) <- Map.toList (symLangs se)
                     ]
    in  object (fixedPair ++ langPairs)

instance FromJSON SymbolEntry where
  parseJSON = withObject "SymbolEntry" $ \o -> do
    cid  <- o .: "concept"
    let langPairs = toList (delete "concept" o)
    langs <- traverse parseLangPair langPairs
    pure SymbolEntry
      { symConcept = cid
      , symLangs   = Map.fromList langs
      }
    where
      parseLangPair (k, v) = do
        mods <- parseJSON v
        let lang = toText k
        pure (lang, mods)

-- ---------------------------------------------------------------------------
-- Registry (v1)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- RegistryV2
-- ---------------------------------------------------------------------------

instance ToJSON RegistryV2 where
  toJSON r = object
    [ "version"          .= reg2Version        r
    , "generated"        .= reg2Generated      r
    , "next_uid"         .= reg2NextUid        r
    , "atoms"            .= reg2Atoms          r
    , "concepts"         .= reg2Concepts       r
    , "instance_macros"  .= reg2InstanceMacros r
    , "type_macros"      .= Set.toList (reg2TypeMacros r)
    , "symbol_deps"      .= reg2SymbolDeps     r
    , "back_refs"        .= reg2BackRefs       r
    , "concept_dag"      .= reg2ConceptDag     r
    , "topological_order".= reg2TopoOrder      r
    , "stacks_index"     .= reg2StacksIndex    r
    , "nlab_index"       .= reg2NlabIndex      r
    ]

instance FromJSON RegistryV2 where
  parseJSON = withObject "RegistryV2" $ \o ->
    RegistryV2
      <$> o .:  "version"
      <*> o .:  "generated"
      <*> o .:  "next_uid"
      <*> o .:  "atoms"
      <*> o .:? "concepts"         .!= Map.empty
      <*> o .:? "instance_macros"  .!= Map.empty
      <*> (Set.fromList <$> (o .:? "type_macros" .!= []))
      <*> o .:? "symbol_deps"      .!= Map.empty
      <*> o .:? "back_refs"        .!= Map.empty
      <*> o .:? "concept_dag"      .!= Map.empty
      <*> o .:? "topological_order".!= []
      <*> o .:? "stacks_index"     .!= Map.empty
      <*> o .:? "nlab_index"       .!= Map.empty
