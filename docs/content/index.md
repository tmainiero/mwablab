---
title: mwablab --- Categorical Foundations
---

A library implementing categorical and higher-categorical mathematics as executable code.
The math leads; code follows.

## What this is

mwablab encodes the core structures of category theory---categories, functors, natural transformations---as working code in three languages, each serving a different purpose:

| Language | Role | What you get |
|----------|------|-------------|
| **Haskell** | Computation | Typeclasses, property-based tests, executable examples |
| **Agda** | Formalization | Dependently-typed proofs that the laws actually hold |
| **Common Lisp** | Exploration | A DSL for building and inspecting small categories |

Every definition traces back to a TeX specification in `src/spec/`, which is the formal source of truth.

## What's implemented

### Phase 1a: Ordinary Categories (current)

- [**Category**](foundations/category.html) --- objects, morphisms, identity, composition
- [**Functor**](foundations/functor.html) --- structure-preserving maps between categories
- [**Natural Transformation**](foundations/natural-transformation.html) --- morphisms between functors
- [**Opposite Category**](foundations/opposite.html) --- reversing all the arrows

### Roadmap

Phase 1b (monoidal categories, enrichment) $\to$ Phase 2 (Yoneda, limits, adjunctions, Kan extensions) $\to$ Phase 3 (sites, sheaves, algebra, simplicial methods) $\to$ Phase 4 (homological algebra, derived categories).

### Concept graph

The dependency graph of all implemented concepts, generated from the TeX specifications:

![Concept dependency graph](concepts.svg)

## Design principles

1. **Spec as initial object.** The TeX specification is the universal source.
   All implementations are morphisms from the spec.
   If two implementations disagree, the spec adjudicates.

2. **Two-track Haskell.** A typeclass track (open, extensible, Set-enriched) and a data track
   (reified records, future substrate for $\Category{V}$-enrichment).

3. **Universe polymorphism.** Agda uses three universe levels per category
   (objects $o$, morphisms $\ell$, equality $e$). Haskell uses kind polymorphism.

4. **Diagrammatic composition.** `f >>> g` means "first $f$, then $g$" (left-to-right).
   Classical composition `compose g f` is the class method.

## References

- [Stacks Project, Part I](https://stacks.math.columbia.edu/browse) --- primary mathematical reference
- Kelly, *Basic Concepts of Enriched Category Theory*
- [agda-categories](https://github.com/agda/agda-categories) (Hu & Carette) --- Agda design model
- [nLab](https://ncatlab.org/) --- encyclopedic reference
