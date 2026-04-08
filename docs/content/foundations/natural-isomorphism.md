---
title: Natural Isomorphism
---

A *natural isomorphism* is an invertible natural transformation.
It is the correct notion of "sameness" for functors.

## Definition

Let $\Category{C}$ and $\Category{D}$ be categories,
and let $\Functor{F}, \Functor{G} \colon \Category{C} \to \Category{D}$ be functors.
A **natural isomorphism**
$\NatTrans{\alpha} \colon \Functor{F} \xRightarrow{\sim} \Functor{G}$
is a natural transformation $\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
such that for every object $X \in \Ob(\Category{C})$,
the component $\NatTrans{\alpha}_X \colon \Functor{F}(X) \to \Functor{G}(X)$
is an isomorphism in $\Category{D}$.

Equivalently,
a natural isomorphism $\Functor{F} \cong \Functor{G}$
consists of a pair of natural transformations
$\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
and
$\NatTrans{\alpha}^{-1} \colon \Functor{G} \Rightarrow \Functor{F}$
such that their vertical composites satisfy

$$\NatTrans{\alpha}^{-1} \circ \NatTrans{\alpha} = \id_{\Functor{F}}, \qquad
  \NatTrans{\alpha} \circ \NatTrans{\alpha}^{-1} = \id_{\Functor{G}}.$$

At each component, these equations assert that $\NatTrans{\alpha}_X$ and $\NatTrans{\alpha}^{-1}_X$
are mutually inverse morphisms in $\Category{D}$:

```
       α_X
F(X) ────────► G(X)
     ◄────────
      α⁻¹_X
```

Reference: [nLab, natural isomorphism](https://ncatlab.org/nlab/show/natural+isomorphism).

---

## Composition and inversion

**Identity natural isomorphism.**
The identity natural isomorphism
$\id_{\Functor{F}} \colon \Functor{F} \xRightarrow{\sim} \Functor{F}$
has forward and backward components both equal to the identity:
$(\id_{\Functor{F}})_X = \id_{\Functor{F}(X)}$.

**Composition.**
Given natural isomorphisms
$\NatTrans{\alpha} \colon \Functor{F} \xRightarrow{\sim} \Functor{G}$
and
$\NatTrans{\beta} \colon \Functor{G} \xRightarrow{\sim} \Functor{H}$,
their composite
$\NatTrans{\beta} \circ \NatTrans{\alpha} \colon \Functor{F} \xRightarrow{\sim} \Functor{H}$
has forward components
$(\NatTrans{\beta} \circ \NatTrans{\alpha})_X = \NatTrans{\beta}_X \circ \NatTrans{\alpha}_X$
and backward components
$(\NatTrans{\beta} \circ \NatTrans{\alpha})^{-1}_X = \NatTrans{\alpha}^{-1}_X \circ \NatTrans{\beta}^{-1}_X$.

**Inverse.**
Given $\NatTrans{\alpha} \colon \Functor{F} \xRightarrow{\sim} \Functor{G}$,
its inverse
$\NatTrans{\alpha}^{-1} \colon \Functor{G} \xRightarrow{\sim} \Functor{F}$
is obtained by swapping forward and backward components.

Natural isomorphisms are the isomorphisms in the functor category
$[\Category{C}, \Category{D}]$.
Two functors are **naturally isomorphic**, written $\Functor{F} \cong \Functor{G}$,
when there exists a natural isomorphism between them.

---

## Haskell

Source: `src/haskell/src/Cat/NaturalIsomorphism.hs`

```haskell
data NatIso (cat2 :: k2 -> k2 -> Type) (f :: k1 -> k2) (g :: k1 -> k2) = NatIso
  { niForward  :: forall (a :: k1). cat2 (f a) (g a)
  , niBackward :: forall (a :: k1). cat2 (g a) (f a)
  }
```

`NatIso cat2 f g` represents $\NatTrans{\alpha} \colon \Functor{f} \xRightarrow{\sim} \Functor{g}$,
storing both the forward family $\NatTrans{\alpha}_a$ and the backward family $\NatTrans{\alpha}^{-1}_a$.
The isomorphism and naturality conditions are laws, not enforced by the type.

Construction helpers:

```haskell
idNatIso      :: Category cat2 => NatIso cat2 f f
composeNatIso :: Category cat2 => NatIso cat2 g h -> NatIso cat2 f g -> NatIso cat2 f h
invertNatIso  :: NatIso cat2 f g -> NatIso cat2 g f
```

---

## Agda

Source: `src/agda/Cat/NaturalIsomorphism.agda`

```agda
record NaturalIsomorphism {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
                          {C : Category o₁ ℓ₁ e₁} {D : Category o₂ ℓ₂ e₂}
                          (F G : Functor C D)
                          : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  field
    forward  : NaturalTransformation F G
    backward : NaturalTransformation G F

  field
    isoˡ : ∀ (X : C.Obj) → (bwd.η X D.∘ fwd.η X) D.≈ D.id
    isoʳ : ∀ (X : C.Obj) → (fwd.η X D.∘ bwd.η X) D.≈ D.id
```

The record bundles forward and backward natural transformations
with proof fields `isoˡ` and `isoʳ` witnessing the roundtrip conditions at each component.

---

## Common Lisp

Source: `src/lisp/src/natural-isomorphism.lisp`

```common-lisp
(defclass natural-isomorphism ()
  ((forward
    :initarg :forward
    :accessor nat-iso-forward
    :type natural-transformation)
   (backward
    :initarg :backward
    :accessor nat-iso-backward
    :type natural-transformation)))
```

A `natural-isomorphism` stores the forward $\NatTrans{\alpha} \colon \Functor{F} \Rightarrow \Functor{G}$
and backward $\NatTrans{\alpha}^{-1} \colon \Functor{G} \Rightarrow \Functor{F}$ natural transformations.
Operations `invert-nat-iso`, `compose-nat-iso`, and `identity-nat-iso` mirror the mathematical constructions.

---

## Julia

Source: `src/julia/src/NaturalIsomorphism.jl`

GATlab encodes a natural isomorphism by extending the natural transformation theory with an inverse component family and roundtrip axioms.

```julia
@theory ThNaturalIsomorphism begin
    # Source/target categories, functors F and G (inlined)
    # Forward component
    component(a::ObC)::HomD(fob(a), gob(a))
    # Naturality of forward component
    composeD(fhom(f), component(b)) == composeD(component(a), ghom(f)) ⊣
        [a::ObC, b::ObC, f::HomC(a, b)]

    # Inverse component
    component_inv(a::ObC)::HomD(gob(a), fob(a))

    # Roundtrip axioms
    composeD(component(a), component_inv(a)) == idD(fob(a)) ⊣ [a::ObC]
    composeD(component_inv(a), component(a)) == idD(gob(a)) ⊣ [a::ObC]

    # Naturality of inverse
    composeD(ghom(f), component_inv(b)) == composeD(component_inv(a), fhom(f)) ⊣
        [a::ObC, b::ObC, f::HomC(a, b)]
end
```

The theory includes forward and backward naturality plus both roundtrip axioms as first-class equations. The inverse naturality axiom is stated explicitly for clarity, although it follows from forward naturality and the roundtrips. Uses GATlab v0.2.2.

Reference: [nLab, natural isomorphism](https://ncatlab.org/nlab/show/natural+isomorphism).

---

## Laws

Source: `src/haskell/test/Cat/NaturalIsomorphismSpec.hs`

**Left inverse** --- $\NatTrans{\alpha}^{-1} \circ \NatTrans{\alpha} = \id_{\Functor{F}}$:

$$\text{compose (niBackward iso) (niForward iso)} = \text{id}$$

**Right inverse** --- $\NatTrans{\alpha} \circ \NatTrans{\alpha}^{-1} = \id_{\Functor{G}}$:

$$\text{compose (niForward iso) (niBackward iso)} = \text{id}$$

**Naturality** of both forward and backward components (inherited from natural transformations).
