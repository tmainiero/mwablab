---
title: Symmetric Monoidal Category
---

A *symmetric monoidal category* is a braided monoidal category
whose braiding is involutive:
swapping twice is the identity.

## Definition

A **symmetric monoidal category** is a braided monoidal category
$(\Category{C}, \otimes, I, \alpha, \lambda, \rho, \sigma)$
satisfying the **symmetry axiom**.

Reference: [nLab, symmetric monoidal category](https://ncatlab.org/nlab/show/symmetric+monoidal+category);
Mac Lane, *Categories for the Working Mathematician*, Chapter XI.

---

## Symmetry axiom

For all objects $A, B \in \Ob(\Category{C})$,
the braiding is its own inverse:

$$\sigma_{B,A} \circ \sigma_{A,B} = \id_{A \otimes B}.$$

Equivalently, $\sigma_{A,B}^{-1} = \sigma_{B,A}$ for all $A$ and $B$.

---

## Remarks

**Redundancy of the second hexagon.** In a symmetric monoidal category,
the second hexagon axiom follows from the first hexagon axiom
together with the symmetry condition $\sigma_{A,B}^{-1} = \sigma_{B,A}$.
Thus a symmetric monoidal category can equivalently be defined as
a monoidal category with a natural isomorphism $\sigma$
satisfying symmetry and the first hexagon axiom alone.

**Symmetric vs. braided.** Not every braided monoidal category is symmetric.
The category of representations of a non-cocommutative quantum group
provides a standard family of braided monoidal categories that are not symmetric.
The distinction is invisible for categories like $\operatorname{Set}$, $\operatorname{Ab}$,
or $R$-$\mathsf{Mod}$,
where the swap $A \otimes B \cong B \otimes A$ is always involutive.

**Coherence.** Mac Lane's coherence theorem extends to the symmetric setting:
every diagram built from $\alpha$, $\lambda$, $\rho$, $\sigma$,
their inverses, identities, and tensor products of these commutes,
provided the two paths induce the same underlying permutation of tensor factors
(Mac Lane, *CWM* XI.1).

---

## Haskell

Source: `src/haskell/src/Cat/SymmetricMonoidal.hs`

```haskell
data SymmetricData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = SymmetricData
  { symmetricBraided :: BraidedData hom tensor unit
  }
```

The record wraps a `BraidedData` and serves as a marker that the
additional symmetry law holds: $\sigma_{B,A} \circ \sigma_{A,B} = \id$.
The inverse braiding is redundant (it equals the braiding with swapped arguments)
but is retained in `BraidedData` for uniformity.

---

## Agda

Source: `src/agda/Cat/SymmetricMonoidal.agda`

```agda
record Symmetric {o ℓ e : Level}
                 {C : Category o ℓ e}
                 {M : Monoidal C}
                 (B : Braided M) : Set (suc (o ⊔ ℓ ⊔ e)) where
  field
    symmetry : ∀ (A B : C.Obj) → (σ→ B A C.∘ σ→ A B) C.≈ C.id
```

The record takes a `Braided M` as parameter and adds a single proof field:
$\sigma_{B,A} \circ \sigma_{A,B} \approx \id$.
This is the only additional obligation beyond the braided monoidal structure.

---

## Common Lisp

Source: `src/lisp/src/symmetric-monoidal.lisp`

```common-lisp
(defclass symmetric-monoidal-category (braided-monoidal-category)
  ()
  (:documentation "A braided monoidal category where σ_{B,A} ∘ σ_{A,B} = id."))
```

The CLOS class inherits from `braided-monoidal-category` with no additional slots.
The symmetry condition is a mathematical requirement on the braiding.
The generic function `symmetry-check` provides runtime verification
that the braiding is involutive at specific objects.

---

## Julia

Source: `src/julia/src/SymmetricMonoidal.jl`

GATlab adds the symmetry axiom as a single equation extending the braided monoidal theory.

```julia
@theory ThSymmetricMonoidalCategory <: ThBraidedMonoidalCategory begin
    compose(braid(a, b), braid(b, a)) == id(otimes(a, b)) ⊣ [a::Ob, b::Ob]
end
```

The theory inherits all braided monoidal structure and adds one axiom: $\sigma_{B,A} \circ \sigma_{A,B} = \id_{A \otimes B}$. This implies $\sigma^{-1}_{A,B} = \sigma_{B,A}$, making `braid_inv` redundant (but retained from the parent theory for uniformity). The theory extension chain `ThCategory <: ThMonoidalCategory <: ThBraidedMonoidalCategory <: ThSymmetricMonoidalCategory` mirrors the mathematical refinement hierarchy. Uses GATlab v0.2.2.

Reference: [nLab, symmetric monoidal category](https://ncatlab.org/nlab/show/symmetric+monoidal+category).

---

## Laws

Source: `src/haskell/test/Cat/SymmetricMonoidalSpec.hs`

**Symmetry:**
$$\sigma_{B,A} \circ \sigma_{A,B} = \id_{A \otimes B}$$

All braided monoidal category laws (braiding roundtrip, naturality, hexagon axioms) also apply.
