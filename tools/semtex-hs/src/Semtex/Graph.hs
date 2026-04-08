-- | Graphviz DOT graph generation from a semtex registry.
--
-- Reads a @registry.json@ file and emits a DOT digraph to stdout,
-- suitable for rendering with @dot -Tpng@ or similar.
-- v2 adds atom-level dependency graph output.
module Semtex.Graph
  ( -- * Graph generation
    runGraph
    -- * v2 atom graph
  , renderAtomDot
  ) where

import Data.Aeson (eitherDecodeFileStrict)
import Data.List (sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Semtex.Types
import Semtex.Json ()

-- | Load @registry.json@ from the given path and emit a Graphviz DOT
-- graph to stdout.
--
-- Node labels include the concept name and, if available, the first
-- Stacks Project tag.  Edges represent direct dependencies in the DAG.
-- Both nodes and edges are emitted in alphabetical order for
-- reproducible output.
runGraph :: FilePath -> IO ()
runGraph path = do
  result <- eitherDecodeFileStrict path :: IO (Either String Registry)
  case result of
    Left err -> do
      hPutStrLn stderr $ "semtex graph: failed to parse registry: " ++ err
      exitFailure
    Right registry -> do
      TIO.putStrLn $ renderDot registry

-- | Render a 'Registry' as a Graphviz DOT digraph.
renderDot :: Registry -> Text
renderDot registry =
  T.unlines $
    [ "digraph concepts {"
    , "  rankdir=BT;"
    , "  node [shape=box, style=rounded, fontname=\"Helvetica\"];"
    , ""
    ]
    ++ map renderNode (sortOn conceptId (Map.elems (regConcepts registry)))
    ++ [""]
    ++ renderAllEdges (regDependencyDag registry)
    ++ ["}"]

-- | Render a single DOT node declaration for a concept.
--
-- The label is the concept name; if any Stacks Project tags are present,
-- the first tag is appended to the label as @\\n[TAG]@.
renderNode :: Concept -> Text
renderNode c =
  "  " <> quoted (conceptId c) <> " [label=" <> quoted lbl <> "];"
  where
    lbl = case conceptStacksRefs c of
      (tag : _) -> conceptName c <> "\\n[" <> tag <> "]"
      []        -> conceptName c

-- | Render all edges from the dependency DAG, sorted by (source, target).
renderAllEdges :: Map ConceptId [ConceptId] -> [Text]
renderAllEdges dag =
  map renderEdge $ sort pairs
  where
    pairs = [ (src, tgt)
            | (src, tgts) <- Map.toAscList dag
            , tgt <- tgts
            ]

-- | Render a single DOT edge.
renderEdge :: (ConceptId, ConceptId) -> Text
renderEdge (src, tgt) =
  "  " <> quoted src <> " -> " <> quoted tgt <> ";"

-- | Wrap a 'Text' value in double-quote characters for DOT output.
quoted :: Text -> Text
quoted t = "\"" <> t <> "\""

-- ---------------------------------------------------------------------------
-- v2 atom-level graph
-- ---------------------------------------------------------------------------

-- | Render an atom-level dependency graph as DOT.
-- Each atom is a node, edges represent auto-inferred symbol dependencies.
renderAtomDot :: Map Uid Atom -> Map Uid [Uid] -> Text
renderAtomDot atoms deps =
  T.unlines $
    [ "digraph atoms {"
    , "  rankdir=BT;"
    , "  node [shape=box, style=rounded, fontname=\"Helvetica\"];"
    , ""
    ]
    ++ map renderAtomNode (sortOn fst (Map.toList atoms))
    ++ [""]
    ++ renderAtomEdges deps
    ++ ["}"]

-- | Render a single DOT node for an atom.
renderAtomNode :: (Uid, Atom) -> Text
renderAtomNode (uid, atom) =
  let uidText = unUid uid
      label = case atomConceptId atom of
        Just cid -> cid <> "\\n" <> atomTypeLabel (atomType atom)
        Nothing  -> atomTypeLabel (atomType atom)
      fullLabel = uidText <> "\\n" <> label
  in  "  " <> quoted uidText <> " [label=" <> quoted fullLabel <> "];"

-- | Human-readable label for an atom type.
atomTypeLabel :: AtomType -> Text
atomTypeLabel AtomParagraph   = "para"
atomTypeLabel AtomDefinition  = "def"
atomTypeLabel AtomTheorem     = "thm"
atomTypeLabel AtomProposition = "prop"
atomTypeLabel AtomLemma       = "lem"
atomTypeLabel AtomCorollary   = "cor"
atomTypeLabel AtomRemark      = "rem"
atomTypeLabel AtomExample     = "ex"
atomTypeLabel AtomProof       = "proof"

-- | Render all edges in the atom dependency graph.
renderAtomEdges :: Map Uid [Uid] -> [Text]
renderAtomEdges deps =
  map renderEdge $ sort pairs
  where
    pairs =
      [ (unUid src, unUid tgt)
      | (src, tgts) <- Map.toAscList deps
      , tgt <- tgts
      ]
