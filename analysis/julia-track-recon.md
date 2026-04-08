# Julia Track Recon: Category Theory in Julia for mwablab

**Date**: 2026-04-07
**Status**: Research complete, awaiting decision

---

## 1. Catlab/GATlab Analysis

### What they are

**Catlab.jl** is AlgebraicJulia's framework for applied category theory. It provides
data structures, algorithms, serialization, and visualization (wiring diagrams via
Graphviz/TikZ) for categorical structures. Actively maintained (docs rebuilt March 2026).

**GATlab.jl** is the new foundational layer (since Catlab 0.16) that provides a
computer algebra system based on Generalized Algebraic Theories (GATs). It was spun
off from Catlab and is now Catlab's backend. The relationship: GATlab defines theories
and their models; Catlab builds applied category theory on top.

### How they encode categories

GATs are specified via the `@theory` macro, which closely mirrors textbook definitions:

```julia
@theory ThCategory begin
  Ob::TYPE
  Hom(dom::Ob, codom::Ob)::TYPE
  id(a::Ob)::(a -> a)
  compose(f::(a -> b), g::(b -> c))::(a -> c)
  # axioms: associativity, left/right identity
end

@theory ThMonoidalCategory{Ob,Hom} <: ThCategory{Ob,Hom} begin
  otimes(A::Ob, B::Ob)::Ob
  otimes(f::(A -> B), g::(C -> D))::((A otimes C) -> (B otimes D))
  munit()::Ob
end

@theory ThSymmetricMonoidalCategory{Ob,Hom} <: ThMonoidalCategory{Ob,Hom} begin
  braid(A::Ob, B::Ob)::((A otimes B) -> (B otimes A))
  -- involutivity: braid(A,B) . braid(B,A) == id(A otimes B)
end
```

Models (instances) come in two flavors:
- **Trait-style** (like Haskell typeclasses): `@instance ThCategory{MyOb, MyHom} begin ... end`
- **Module-style** (like ML modules): explicit model object as first parameter,
  using `WithModel` wrapper for dispatch

GATlab also supports **symbolic/free models** via `@symbolic_model` for expression trees,
and **theory morphisms** via `@map` for declarative model migration between theories.

### Critical finding: strict monoidal only

**Catlab assumes strict monoidal categories.** It does not implement associators,
unitors, or coherence axioms (pentagon, triangle, hexagons). The rationale is
Mac Lane's coherence theorem: every monoidal category is equivalent to a strict one.

This is a fundamental mismatch with mwablab's design. Our Haskell and Agda tracks
explicitly carry full coherence data -- associator, left/right unitors as natural
isomorphisms, pentagon and triangle axioms as testable/provable properties. This is
by design: we want the coherence structure as first-class data, not collapsed away.

### Strengths

- Beautiful DSL syntax via macros -- reads very close to textbook math
- Theory inheritance (`<: ThCategory`) mirrors mathematical refinement
- Symbolic models give free categories with normalization
- Wiring diagram visualization is excellent for applied work
- Theory morphisms enable declarative model migration
- Active development, solid community (Topos Institute backing)

### Limitations

- **No coherence data**: strict monoidal only, no pentagon/triangle
- **No proofs**: explicitly not a theorem prover or proof assistant
- **Applied focus**: designed for computational category theory (databases, networks,
  scientific computing), not foundational mathematics
- **Heavy macro dependency**: the `@theory` macro does a lot of metaprogramming;
  debugging can be opaque
- **Documentation gaps**: acknowledged by maintainers
- **Ongoing refactor**: the Catlab-to-GATlab migration is in progress (as of early 2025),
  so the API surface is shifting

---

## 2. Julia Type System Assessment

### Multiple dispatch vs Haskell typeclasses

Julia's multiple dispatch is analogous to open typeclasses -- you define methods that
specialize on argument types, and the runtime selects the most specific method. This
maps reasonably well to our typeclass track:

| Haskell | Julia |
|---------|-------|
| `class Category cat where` | Abstract type + methods dispatching on it |
| `instance Category (->) where` | Method definitions for concrete types |
| Typeclass constraints | Informal (no enforcement) or GATlab theories |

The key difference: Julia's dispatch is on concrete values/types at runtime, while
Haskell's is resolved at compile time with static guarantees. Julia has no mechanism
to enforce that a set of methods forms a coherent implementation of an interface
(unless you use GATlab).

### The higher-kinded type problem

This is the critical gap. Haskell's `MonoidalData` is parameterized by:
```haskell
data MonoidalData (hom :: Type -> Type -> Type) (tensor :: Type -> Type -> Type) (unit :: Type)
```

The `hom` and `tensor` parameters are **type constructors** (kind `Type -> Type -> Type`).
Julia has no higher-kinded types. You cannot write:

```julia
# IMPOSSIBLE in Julia:
struct MonoidalData{Hom<:Function2, Tensor<:Function2, Unit}
```

where `Function2` means "a type constructor taking two type arguments."

### Workarounds

**Option A: Concretize at the value level (our data track approach)**

Instead of parameterizing over type constructors, store morphism operations as
function values:

```julia
struct CategoryData
    identity::Function    # a -> hom(a, a)
    compose::Function     # hom(b,c) x hom(a,b) -> hom(a,c)
end
```

This loses type safety but gains flexibility. It's essentially what our Haskell data
track does, but without Haskell's rank-2 polymorphism to keep it typed.

**Option B: Use Julia's parametric types with concrete morphism types**

```julia
struct CategoryData{H}
    identity  # returns H instances
    compose   # takes and returns H instances
end
```

Here `H` is a concrete morphism type (like `Matrix{Float64}`), not a type constructor.
This works for specific categories but loses generality.

**Option C: GATlab's approach -- symbolic + dispatch**

GATlab sidesteps the problem by making theories symbolic. The `Hom(a,b)` dependent
type is represented as a term in the GAT, not as a Julia type. Dispatch on models
replaces dispatch on type constructors.

**Option D: Holy trait pattern**

Use empty structs as "tags" and dispatch on them:

```julia
struct SetCategory end
struct VectCategory end

compose(::SetCategory, f, g) = f . g
compose(::VectCategory, f::Matrix, g::Matrix) = f * g
```

This is essentially what GATlab's model-style instances do, formalized.

### Assessment

Julia **cannot** directly express our Haskell data track's parametric design. The
rank-2 polymorphism in `MonoidalData` (e.g., `monAssocFwd :: forall a b c. hom ...`)
is not expressible in Julia's type system. We have two realistic paths:

1. **Untyped data track**: Store coherence morphisms as plain functions, lose static
   type safety, gain Julia's runtime flexibility
2. **GATlab-mediated**: Use GATlab theories for the interface, concrete models for
   instances, accept that coherence is checked by tests not types

---

## 3. Design Proposal

### Recommendation: Hybrid -- own library informed by GATlab, not built on it

**Do not build on top of Catlab/GATlab.** Reasons:

1. Catlab's strict-monoidal assumption is antithetical to our full-coherence design
2. The GATlab refactor is ongoing; building on a shifting API is risky
3. Our needs (foundational math, coherence data, cross-language consistency) differ
   from Catlab's (applied CT, databases, scientific computing)
4. GATlab's macro-heavy approach would make our Julia code opaque to non-Julia readers

**Do learn from GATlab's design.** Specifically:

- The model-as-first-argument dispatch pattern (Holy trait pattern, formalized)
- The theory-morphism concept for relating structures
- The separation of symbolic and computational models

### Proposed architecture

#### Module structure

```
src/julia/
  CatFoundations/
    src/
      CatFoundations.jl          # top-level module
      Category.jl                # CategoryData, compose, id
      Functor.jl                 # FunctorData, fmap
      NaturalTransformation.jl   # NatTransData
      NaturalIsomorphism.jl      # NatIsoData
      Opposite.jl                # OppositeData
      Product.jl                 # ProductData
      Bifunctor.jl               # BifunctorData
      Monoidal.jl                # MonoidalData (full coherence)
      BraidedMonoidal.jl         # BraidedData
      SymmetricMonoidal.jl       # SymmetricData
      Examples/
        Monoidal.jl              # SetProduct, SetCoproduct
    test/
      runtests.jl
      CategoryTest.jl
      MonoidalTest.jl
      ...
    Project.toml
```

#### Core types -- data track only

Julia's type system cannot support our typeclass track, so we implement the data track
only. This is consistent: the data track is the portable one across all languages.

```julia
# Category.jl

"""
    CategoryData{H}

A category reified as data. `H` is the morphism type.

Stacks Project 0014.
"""
struct CategoryData{H}
    identity::Any    # () -> H  (identity morphism)
    compose::Any     # (H, H) -> H  (composition)
end

# Convenience: diagrammatic composition
(>>)(f, g, cat::CategoryData) = cat.compose(g, f)
```

For the monoidal structure with full coherence:

```julia
# Monoidal.jl

"""
    MonoidalData{H, T, U}

A monoidal category (C, tensor, I, alpha, lambda, rho).

`H` = morphism type, `T` = tensor product result type, `U` = unit type.
Full coherence: associator and unitors stored as forward/backward families.

nLab: monoidal+category.
"""
struct MonoidalData{H}
    cat::CategoryData{H}
    tensor_bimap::Any          # (H, H) -> H  (bifunctor action on morphisms)

    # Associator: (A tensor B) tensor C  <->  A tensor (B tensor C)
    assoc_fwd::Any             # () -> H
    assoc_bwd::Any             # () -> H

    # Left unitor: I tensor A  <->  A
    left_unitor_fwd::Any       # () -> H
    left_unitor_bwd::Any       # () -> H

    # Right unitor: A tensor I  <->  A
    right_unitor_fwd::Any      # () -> H
    right_unitor_bwd::Any      # () -> H
end
```

Wait -- this is too untyped. The `Any` types lose all structure. Better approach:
use Julia's callable structs and parametric types to retain *some* type information.

#### Revised design: callable morphism wrappers

```julia
# Category.jl

"""
A category reified as data. The morphism type is left abstract --
morphisms are whatever the compose and identity functions accept/return.

Stacks Project 0014.
"""
struct CategoryData
    id      :: Function    # id(a) -> morphism
    compose :: Function    # compose(g, f) -> morphism  (g after f)
end

# Diagrammatic composition
diag_compose(cat::CategoryData, f, g) = cat.compose(g, f)


# Bifunctor.jl

"""
A bifunctor F : C x D -> E reified as data.

nLab: bifunctor.
"""
struct BifunctorData
    bimap :: Function    # bimap(f, g) -> morphism in E
end

first_map(bf::BifunctorData, cat_d::CategoryData, f) =
    bf.bimap(f, cat_d.id)

second_map(bf::BifunctorData, cat_c::CategoryData, g) =
    bf.bimap(cat_c.id, g)


# Monoidal.jl

"""
A monoidal category (C, tensor, I, alpha, lambda, rho) with full coherence.

The coherence isomorphisms are stored as callable families:
- assoc_fwd, assoc_bwd: components of the associator
- left_unitor_fwd, left_unitor_bwd: components of the left unitor
- right_unitor_fwd, right_unitor_bwd: components of the right unitor

These are functions that, given appropriate objects (as type tags or values),
return the corresponding morphism.

nLab: monoidal+category.
"""
struct MonoidalData
    cat               :: CategoryData
    tensor            :: BifunctorData

    assoc_fwd         :: Function    # (a, b, c) -> morphism
    assoc_bwd         :: Function    # (a, b, c) -> morphism

    left_unitor_fwd   :: Function    # (a) -> morphism
    left_unitor_bwd   :: Function    # (a) -> morphism

    right_unitor_fwd  :: Function    # (a) -> morphism
    right_unitor_bwd  :: Function    # (a) -> morphism
end


# BraidedMonoidal.jl

struct BraidedData
    monoidal      :: MonoidalData
    braiding_fwd  :: Function    # (a, b) -> morphism
    braiding_bwd  :: Function    # (a, b) -> morphism
end


# SymmetricMonoidal.jl

struct SymmetricData
    braided :: BraidedData
end

# Forgetful projections
monoidal(s::SymmetricData)  = s.braided.monoidal
category(s::SymmetricData)  = s.braided.monoidal.cat
tensor(s::SymmetricData)    = s.braided.monoidal.tensor
```

#### Concrete instance: cartesian monoidal (Set, (,), ())

```julia
# Examples/Monoidal.jl

using ..CatFoundations

"""Cartesian monoidal structure on Julia types with functions."""
function set_product()
    cat = CategoryData(
        _ -> identity,              # id
        (g, f) -> g . f             # compose (Haskell-order)
    )

    tensor = BifunctorData(
        (f, g) -> x -> (f(x[1]), g(x[2]))    # bimap
    )

    SymmetricData(BraidedData(
        MonoidalData(
            cat,
            tensor,
            (a, b, c) -> x -> (x[1][1], (x[1][2], x[2])),    # assoc_fwd
            (a, b, c) -> x -> ((x[1], x[2][1]), x[2][2]),      # assoc_bwd
            a -> x -> x[2],                                     # left_unitor_fwd  ((), a) -> a
            a -> x -> ((), x),                                  # left_unitor_bwd
            a -> x -> x[1],                                     # right_unitor_fwd (a, ()) -> a
            a -> x -> (x, ()),                                  # right_unitor_bwd
        ),
        (a, b) -> x -> (x[2], x[1]),    # braiding_fwd
        (a, b) -> x -> (x[2], x[1]),    # braiding_bwd
    ))
end
```

### Key design differences from Haskell track

| Aspect | Haskell | Julia |
|--------|---------|-------|
| Type safety | Rank-2 polymorphism, type constructors as params | Untyped Function fields |
| Two tracks | Typeclass + Data | Data only |
| Coherence enforcement | Types prevent some misuse | Tests only |
| Parametricity | `forall a b c.` enforced by compiler | Convention only |
| Object representation | Haskell types (kind `Type`) | Values or type tags |

The Julia track is necessarily less typed than Haskell. This is fine -- each language
plays to its strengths. Julia's role in mwablab would be:
- Computational experimentation (fast numeric categories, linear algebra)
- DSL prototyping (macros for categorical notation)
- Bridge to the higher-info project (which will use Julia for computation)

---

## 4. Recommendation Summary

**Build from scratch, informed by Catlab/GATlab design, but not dependent on them.**

| Option | Verdict | Reason |
|--------|---------|--------|
| Build on Catlab | No | Strict monoidal only, applied focus, shifting API |
| Build on GATlab | No | Macro-heavy, ongoing refactor, overkill for data track |
| From scratch | **Yes** | Full coherence, cross-language consistency, simplicity |
| Hybrid (use GATlab for theory defs only) | Maybe later | Once GATlab stabilizes, could layer theories on top of our data track |

The from-scratch approach gives us:
- Full coherence data matching Haskell and Agda tracks
- Simple, readable code (no macro magic)
- Cross-language consistency (same record-of-functions pattern)
- Freedom to evolve with the higher-info project's needs

Consider adding GATlab integration later as an optional layer -- define mwablab
theories in GATlab syntax, verify our data track instances satisfy them. This would
add a form of specification checking without coupling our core to GATlab.

---

## 5. Integration Plan

### Nix

Add Julia to the flake. Two options:

**Option A: Simple (recommended to start)**
```nix
# In flake.nix, alongside hsShellPkgs, agdaWithPkgs, etc.
juliaPkgs = [
  pkgs.julia-bin    # or pkgs.julia
];
```

Julia packages managed via `Project.toml` / `Manifest.toml` inside `src/julia/CatFoundations/`.
Run `julia --project=src/julia/CatFoundations -e 'using Pkg; Pkg.instantiate()'` in the dev shell.

**Option B: Full Nix lockdown (later)**
Use `julia2nix` (codedownio/julia2nix) to pin Julia packages in Nix. More reproducible
but adds complexity. Defer until we have real dependencies beyond stdlib.

For now Option A is correct -- our Julia track will have zero external dependencies
initially (just stdlib). No Catlab, no GATlab, no packages to pin.

### Testing

**Supposition.jl** -- Julia's best property-based testing framework (successor to
PropCheck.jl, inspired by Hypothesis). Provides:
- Property-based testing with integrated shrinking
- Composable generators
- Stateful testing

Test structure mirrors Haskell:
- Roundtrip tests: `compose(assoc_bwd(a,b,c), assoc_fwd(a,b,c)) == id`
- Naturality: `assoc_fwd . bimap(bimap(f,g), h) == bimap(f, bimap(g,h)) . assoc_fwd`
- Pentagon: the five-morphism diagram commutes
- Triangle: the three-morphism diagram commutes
- Hexagons: the braiding coherence diagrams commute
- Symmetry: `braiding_fwd(b,a) . braiding_fwd(a,b) == id`

Julia's `Test` stdlib provides `@testset` and `@test` for basic assertions.
Supposition.jl adds `@check` for property-based tests.

### Module structure

Julia uses `module` blocks (one per file convention), with `include()` for
file loading and `using`/`import` for namespace control. The top-level module
would be:

```julia
# src/julia/CatFoundations/src/CatFoundations.jl
module CatFoundations

include("Category.jl")
include("Functor.jl")
include("NaturalTransformation.jl")
include("NaturalIsomorphism.jl")
include("Opposite.jl")
include("Product.jl")
include("Bifunctor.jl")
include("Monoidal.jl")
include("BraidedMonoidal.jl")
include("SymmetricMonoidal.jl")

module Examples
    include("Examples/Monoidal.jl")
end

end # module
```

### Cross-language consistency

The Julia track mirrors the Haskell data track 1:1:
- Same struct names (`CategoryData`, `MonoidalData`, `BraidedData`, `SymmetricData`)
- Same field names (`cat`, `tensor`, `assoc_fwd`, `braiding_fwd`, etc.)
- Same mathematical documentation (Stacks Project tags, nLab refs)
- Same test properties (pentagon, triangle, hexagons, symmetry)

This is the same pattern used for the Lisp track -- each language implements the
same mathematical content with language-idiomatic syntax.

---

## Sources

- [Catlab.jl GitHub](https://github.com/AlgebraicJulia/Catlab.jl)
- [GATlab.jl GitHub](https://github.com/AlgebraicJulia/GATlab.jl)
- [GATlab paper (arXiv 2404.04837)](https://arxiv.org/abs/2404.04837)
- [Catlab Refactor I: GATlab Preliminaries (AlgebraicJulia blog, Feb 2025)](https://blog.algebraicjulia.org/post/2025/02/refactor1/)
- [Catlab SMC sketch](https://algebraicjulia.github.io/Catlab.jl/dev/generated/sketches/smc/)
- [Catlab standard library of theories](https://algebraicjulia.github.io/Catlab.jl/dev/apis/theories/)
- [julia2nix (codedownio)](https://github.com/codedownio/julia2nix)
- [Julia2Nix.jl (JuliaCN)](https://github.com/JuliaCN/Julia2Nix.jl)
- [Supposition.jl](https://discourse.julialang.org/t/ann-supposition-jl/111338)
- [PropCheck.jl](https://github.com/Seelengrab/PropCheck.jl)
