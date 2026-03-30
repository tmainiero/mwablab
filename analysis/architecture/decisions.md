# Architectural Decisions — mwablab

**Status**: Synthesized from Math Guide, Software Architect, and Math Reviewer pod (2026-03-30)

---

## 1. Foundational Approach: Enriched Categories

**Decision**: Enriched categories are the true foundation, but ordinary categories come first in the implementation order.

**Rationale**: A V-enriched category parameterized over a monoidal base V gives us five theories for one framework:

| Enrichment base V | V-categories are | Classical name |
|-------------------|-----------------|----------------|
| Set | ordinary categories | categories |
| Ab | preadditive categories | Ab-categories |
| Ch(Ab) | differential graded categories | dg-categories |
| Cat | strict 2-categories | 2-categories |
| sSet | simplicial categories | (∞,1)-categories (one model) |

**Implementation order** (corrected by Math Reviewer — monoidal categories require categories, functors, natural transformations in their definition):

```
Phase 0:  Nix scaffolding
Phase 1a: Category, Functor, NaturalTransformation, Opposite category (ordinary/Set-enriched)
Phase 1b: MonoidalCategory, V-EnrichedCategory, V-Functor, V-NaturalTransformation
Phase 2:  Enriched Yoneda, Weighted limits, Adjunctions, Kan extensions, Ends/Coends
Phase 3:  Sites/Sheaves ∥ Algebra ∥ Simplicial (parallel)
Phase 4:  Homological (after Algebra)
```

All Tier 1+ constructions proceed at the enriched level, with Set-enriched specializations as the primary computational interface.

**Key constructions missing from initial tier plans** (flagged by Reviewer):
- Opposite categories (C^op) — needed for presheaves, Yoneda. Add to Phase 1a.
- Comma categories (slice/coslice) — pervasive. Add to Phase 2.
- Ends and coends — needed for enriched Yoneda and weighted limits. Add to Phase 2.
- Kan extensions — "the concept from which all others follow" (Mac Lane). Late Phase 2.

---

## 2. Languages

**Decision**: Three-language split unified by Nix.

| Language | Role | Tiers |
|----------|------|-------|
| **Haskell** (GHC 9.8+) | Computation — typeclasses, GADTs, property-based testing | All tiers |
| **Agda** (2.7+, cubical mode) | Formalization — dependent types, proofs as types | Core: 0–2, selective elsewhere |
| **Common Lisp** (SBCL) | DSL — diagram specification, notation, exploration | 0–1, grows on demand |

### Agda over Lean (Math Reviewer recommendation)

Cubical Agda provides computational univalence — equivalent categories ARE equal, with computational content. For a project targeting simplicial methods and higher categories (Tier 5), this is an eventual necessity. Lean's univalence is axiomatic (no computational content).

Trade-off accepted: smaller ecosystem than mathlib. Build on `agda-categories` (Hu & Carette).

### Agda equality: Start with setoids

Start with `agda-categories` setoid approach (proven, large library). Cubical equality is deferred — revisit if Tier 5 demands it. Pragmatism over elegance here.

### Lisp scope: Earn its place

Lisp starts at Tiers 0–1. Extends to Tier 2 (site/topology DSL) if the diagram DSL proves valuable. No commitment beyond that. Code generation (Lisp → Agda/Haskell) is speculative — don't plan for it.

**Concrete Lisp value**: diagram DSL should generate (a) test harnesses, (b) TeX diagram renderings. This connects it to the spec-as-source-of-truth architecture.

---

## 3. Nix Architecture

**Decision**: Nix flake is the unifying substrate. Everything builds, tests, and documents through Nix.

```
flake.nix
├── inputs: nixpkgs, flake-utils, agda-categories
├── packages: mwablab-haskell, mwablab-agda, mwablab-lisp, mwablab-docs
├── devShells: default (unified), haskell, agda, lisp
├── checks: agda-typecheck, haskell-tests, lisp-tests, hlint, docs-build, cross-check
└── apps: verify (runs all checks in dependency order)
```

- Per-language dev shells for focused work; unified shell for integration
- `nix flake check` is the CI spec — no separate CI configuration
- Documentation built as a Nix derivation (reproducible, cacheable)
- Cross-language interop via mathematical specifications, not FFI

---

## 4. Module Architecture

**Decision**: Spec-as-initial-object. TeX specifications are the universal source.

```
src/
├── spec/          — TeX mathematical specifications (source of truth)
│   ├── foundations/
│   ├── constructions/
│   ├── topology/
│   ├── algebra/
│   ├── homological/
│   └── simplicial/
├── haskell/       — Computation (Cat.Category, Cat.Functor, etc.)
├── agda/          — Formalization (Cat.Category, Cat.Functor, etc.)
└── lisp/          — DSL and exploration
```

Every implementation is a morphism from the spec:
```
              spec
             / | \
            /  |  \
           v   v   v
     haskell  agda  lisp
```

If two implementations disagree, the spec adjudicates.

---

## 5. Type Design

### Haskell: Two-track encoding

1. **Typeclass track** — implicitly Set-enriched, primary computational interface:
   ```haskell
   class Category (cat :: k → k → Type) where
     id  :: cat a a
     (∘) :: cat b c → cat a b → cat a c
   ```

2. **Data track** — supports enrichment explicitly, GADT-based (no Maybe composition):
   ```haskell
   -- Morphisms indexed by source/target — non-composable composition is a type error
   hom      :: ob → ob → Type
   identity :: forall a. hom a a
   compose  :: forall a b c. hom b c → hom a b → hom a c
   ```

**Critical fix** (Math Reviewer): No `Maybe`-based composition in SmallCat. Use GADTs or type-indexed morphisms from the start. Type safety mirrors mathematical correctness — composition is total on composable pairs.

The data track extends to V-enrichment for Ab-enriched, dg-enriched, etc. The typeclass track remains the primary interface for Set-enriched work.

### Agda: `agda-categories` records

Adopt `agda-categories` wholesale:
```agda
record Category (o ℓ e : Level) : Set (suc (o ⊔ ℓ ⊔ e)) where
  field
    Obj : Set o
    _⇒_ : Obj → Obj → Set ℓ
    _≈_ : ∀ {A B} → (A ⇒ B) → (A ⇒ B) → Set e
    id  : ∀ {A} → A ⇒ A
    _∘_ : ∀ {A B C} → B ⇒ C → A ⇒ B → A ⇒ C
    -- ... laws as fields
```

Three universe levels (objects, morphisms, equality) are mathematically necessary.

### Common Lisp: Structural DSL

CLOS classes with reader macros for mathematical notation. No type enforcement — value is expressiveness and metaprogramming.

### Universal properties

- **Agda**: Full encoding with existence + uniqueness as types
- **Haskell**: Smart constructors; uniqueness tested via QuickCheck
- **Lisp**: Diagram-level DSL generating test harnesses and TeX

---

## 6. Size Issues

**Decision**: Universe polymorphism from day one.

- Every category carries a universe level parameter
- Agda: native universe polymorphism (three levels per category)
- Haskell: phantom type tag (deferred to Phase 2 when functor categories demand it)
- Lisp: runtime tag (assertions in debug mode)

Reference: Grothendieck universes ([nLab](https://ncatlab.org/nlab/show/Grothendieck+universe)).

---

## 7. Notation Conventions

**Decision**: Diagrammatic order for categorical composition (following mathlib, Stacks Project).

| Math | Lean/Agda | Haskell | Lisp |
|------|-----------|---------|------|
| f ∘ g (classical) / f ≫ g (diagrammatic) | `f ≫ g` (diagrammatic) | `f . g` (classical) / `(>>>) f g` | `(∘ f g)` |
| F: C → D | `F : Functor C D` | `F :: CFunctor f C D` | `(functor F C D)` |
| η: F ⟹ G | `η : NaturalTransformation F G` | `η :: NatTrans F G` | `(nat-trans η F G)` |

Greek letters encouraged everywhere: η (unit), ε (counit), μ (multiplication), δ (comultiplication).
Unicode operators enabled project-wide in Haskell via `UnicodeSyntax`.

---

## 8. Documentation Pipeline

**Decision**: Hakyll site assembling multi-language docs, built as a Nix derivation.

Sources:
- TeX specifications → rendered via texlive
- Haskell → Haddock HTML with MathJax
- Agda → clickable hyperlinked HTML (agda --html)
- Lisp → extracted docstrings

Cross-references via canonical identifiers matching `src/spec/` filenames.

---

## 9. Testing Strategy

**Decision**: Tests verify categorical properties, not implementation details.

| Language | Framework | What it tests |
|----------|-----------|---------------|
| Haskell | QuickCheck + Hedgehog | Associativity, functoriality, naturality (property-based) |
| Agda | Type checker (`agda --safe`) | Laws as types — if it type-checks, it's proven |
| Lisp | FiveAM | DSL consistency, diagram commutativity |
| Cross-language | Nix check | Same examples produce same results across languages |

For finite categories: exhaustive testing (genuine proof for finite cases).

---

## 10. Forward-Looking Design

### Strictness vs. weakness
Enriched categories are strict. Bicategories, (∞,1)-categories require weakness. Design for it now (don't prevent weakening), implement later. When defining associativity as a commutative diagram, also plan for the version where it commutes up to a specified higher isomorphism.

### Lean/Haskell divergence risk
Establish a formal correspondence: for every Agda definition, a corresponding Haskell type. For every Agda theorem, a corresponding Haskell property test. Nix checks run both and compare. Discrepancies are CI failures.

### Over-abstraction guard
Every abstraction must come with at least one concrete instantiation that computes something. No pure abstraction without a working example.

---

## Deferred Decisions

1. **Cubical vs. setoid in Agda** — start setoid, revisit at Tier 5
2. **Proof transfer (Agda → Haskell test extraction)** — investigate after Phase 2
3. **Lisp code generation** — speculative, let DSL prove itself first
4. **Weak enrichment (bicategories)** — design for it, don't implement yet
5. **Universe polymorphism in Haskell** — phantom type for now, solve at Phase 2

---

## References

- Kelly, *Basic Concepts of Enriched Category Theory* (TAC Reprint)
- Stacks Project, Part I (categories: 0013, sites: 00VG, sheaves: 00VL)
- `agda-categories` (Hu & Carette)
- nLab: enriched category, monoidal category, Yoneda lemma, weighted limit
- Lurie, *Higher Topos Theory*, Ch. 1–2
- Riehl, *Categorical Homotopy Theory*, Ch. 3
