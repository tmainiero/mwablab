---
title: Getting Started
---

## Prerequisites

You need [Nix](https://nixos.org/download.html) with flakes enabled, or Docker.

## With Nix (recommended)

```bash
git clone <repo-url> mwablab && cd mwablab

# Full dev shell (Haskell + Agda + Lisp + TeX)
nix develop

# Or language-specific shells
nix develop .#haskell
nix develop .#agda
nix develop .#lisp
```

## With Docker

```bash
docker build -t mwablab .
docker run -it -v $(pwd):/workspace mwablab
```

Or open in VS Code with the Dev Containers extension---it picks up `.devcontainer/devcontainer.json` automatically.

## Build and test

```bash
# Run all checks (hlint, Agda typecheck, Haskell tests, Lisp load)
nix flake check

# Or within a dev shell:
cd src/haskell && cabal test all    # 24 property tests
cd src/agda && agda --safe Everything.agda
```

## Project layout

```
src/
  spec/            TeX specifications (source of truth)
    foundations/    category.tex, functor.tex, ...
  haskell/         Haskell library + tests
    src/Cat/       Category.hs, Functor.hs, ...
    test/Cat/      CategorySpec.hs, FunctorSpec.hs, ...
  agda/            Agda formalization
    Cat/           Category.agda, Functor.agda, ...
  lisp/            Common Lisp DSL
    src/           category.lisp, functor.lisp, ...
docs/              This documentation site
analysis/          Architecture decisions
```

## Quick tour

### Haskell

```haskell
import Cat.Category
import Cat.Functor
import Cat.Examples ()  -- brings Category (->) into scope

-- Compose two functions using the Category class
f :: Int -> Int
f = compose (+1) (*2)    -- f(x) = 2x + 1

-- Diagrammatic order: left to right
g :: Int -> Int
g = (*2) >>> (+1)         -- same thing: first *2, then +1

-- Functors map morphisms
h :: Maybe Int -> Maybe Int
h = cmap (+1)             -- Just 3 -> Just 4, Nothing -> Nothing
```

### Agda

```agda
open import Cat.Category

-- A Category is a record with three universe levels:
--   Obj : Set o           -- objects
--   _=>_ : Obj -> Obj -> Set l   -- morphisms
--   _~_ : morphism equality (setoid)
--   id, _o_, and seven axiom fields
```

### Common Lisp

```lisp
(require :asdf)
(asdf:load-system :mwablab)
(in-package :mwablab)

;; Build a small category
(defvar *two* (make-finite-category "2"
  '(a b)
  '((:f a b))))

;; Take its opposite
(defvar *two-op* (opposite-category *two*))
```

## Building the docs

```bash
nix develop   # need pandoc
./docs/build.sh
open docs/site/index.html
```

## Semtex --- the concept preprocessor

The TeX specifications use semantic macros (`\concept`, `\depends`, `\implements`, etc.) that semtex extracts into a machine-readable concept graph.

```bash
# Extract per-file metadata
semtex extract src/spec/foundations/*.tex

# Merge into a single registry
semtex merge src/spec/

# Validate all cross-references
semtex validate src/spec/registry.json .

# Generate Graphviz DOT graph
semtex graph src/spec/registry.json | dot -Tsvg > concepts.svg

# Generate MathJax macro config
semtex mathjax src/spec/preamble.tex > mathjax_config.js
```

The `docs/build.sh` script runs these automatically.
