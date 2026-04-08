---
title: Braided Monoidal Category
---

A *braided monoidal category* equips a monoidal category
with a coherent notion of "swapping" the two factors of a tensor product.

## Definition

A **braided monoidal category** is a monoidal category
$(\Category{C}, \otimes, I, \alpha, \lambda, \rho)$
equipped with a natural isomorphism, the **braiding**, with components

$$\sigma_{A,B} \colon A \otimes B \xrightarrow{\;\sim\;} B \otimes A$$

natural in $A$ and $B$,
subject to the two hexagon axioms.

Reference: [nLab, braided monoidal category](https://ncatlab.org/nlab/show/braided+monoidal+category);
Joyal--Street, *Braided tensor categories*, Advances in Mathematics 102, 1993.

---

## First hexagon axiom

For all objects $A, B, C \in \Ob(\Category{C})$,
the following diagram commutes:

```
                              σ_{A,B⊗C}
  (A⊗B)⊗C ──α_{A,B,C}──► A⊗(B⊗C) ──────────► (B⊗C)⊗A
      │                                             │
      │ σ_{A,B} ⊗ id_C                              │ α_{B,C,A}
      ▼                                             ▼
  (B⊗A)⊗C ──α_{B,A,C}──► B⊗(A⊗C) ──────────► B⊗(C⊗A)
                                   id_B ⊗ σ_{A,C}
```

The two composite paths from $(A \otimes B) \otimes C$ to $B \otimes (C \otimes A)$ are equal.

---

## Second hexagon axiom

For all objects $A, B, C \in \Ob(\Category{C})$,
the following diagram commutes:

```
                                σ_{A⊗B,C}
  A⊗(B⊗C) ──α⁻¹_{A,B,C}──► (A⊗B)⊗C ──────────► C⊗(A⊗B)
      │                                               │
      │ id_A ⊗ σ_{B,C}                                │ α⁻¹_{C,A,B}
      ▼                                               ▼
  A⊗(C⊗B) ──α⁻¹_{A,C,B}──► (A⊗C)⊗B ──────────► (C⊗A)⊗B
                                      σ_{A,C} ⊗ id_B
```

The two composite paths from $A \otimes (B \otimes C)$ to $(C \otimes A) \otimes B$ are equal.

---

## Naturality and the Yang--Baxter equation

**Naturality of the braiding.** For all morphisms $f \colon A \to A'$ and $g \colon B \to B'$:

$$\sigma_{A',B'} \circ (f \otimes g) = (g \otimes f) \circ \sigma_{A,B}.$$

**Yang--Baxter equation.** In a braided monoidal category, the braiding satisfies:

$$(\id_B \otimes \sigma_{A,C}) \circ (\sigma_{A,B} \otimes \id_C) \circ (\id_A \otimes \sigma_{B,C})
  = (\sigma_{B,C} \otimes \id_A) \circ (\id_B \otimes \sigma_{A,C}) \circ (\sigma_{A,B} \otimes \id_C)$$

as morphisms $A \otimes B \otimes C \to C \otimes B \otimes A$
(suppressing associators by Mac Lane's coherence theorem).
This follows from the hexagon axioms alone.

---

## Haskell

Source: `src/haskell/src/Cat/BraidedMonoidal.hs`

```haskell
data BraidedData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = BraidedData
  { braidedMonoidal :: MonoidalData hom tensor unit
  , braidingFwd     :: forall a b. hom (tensor a b) (tensor b a)
  , braidingBwd     :: forall a b. hom (tensor b a) (tensor a b)
  }
```

The record wraps a `MonoidalData` and adds forward and backward components
for the braiding $\sigma_{A,B} \colon A \otimes B \to B \otimes A$
and its inverse $\sigma^{-1}_{A,B}$.

---

## Agda

Source: `src/agda/Cat/BraidedMonoidal.agda`

```agda
record Braided {o ℓ e : Level} {C : Category o ℓ e} (M : Monoidal C)
               : Set (suc (o ⊔ ℓ ⊔ e)) where
  field
    σ→        : ∀ (A B : C.Obj) → (A ⊗₀ B) C.⇒ (B ⊗₀ A)
    σ←        : ∀ (A B : C.Obj) → (B ⊗₀ A) C.⇒ (A ⊗₀ B)
    σ-isoˡ    : ∀ (A B : C.Obj) → (σ← A B C.∘ σ→ A B) C.≈ C.id
    σ-isoʳ    : ∀ (A B : C.Obj) → (σ→ A B C.∘ σ← A B) C.≈ C.id
    σ-natural : ...
    hexagon₁  : ...
    hexagon₂  : ...
```

The record takes a `Monoidal C` as a parameter and adds the braiding morphisms,
isomorphism proofs, naturality, and both hexagon axioms as proof obligations.

---

## Common Lisp

Source: `src/lisp/src/braided-monoidal.lisp`

```common-lisp
(defclass braided-monoidal-category ()
  ((base-monoidal     :initarg :base-monoidal     :accessor braided-base-monoidal)
   (braiding-forward  :initarg :braiding-forward   :accessor braided-braiding-forward)
   (braiding-backward :initarg :braiding-backward  :accessor braided-braiding-backward)))
```

The CLOS class stores the underlying monoidal category and function-valued slots
for the braiding and its inverse.
Generic functions `braiding-at` and `braiding-inverse-at` retrieve components at specific objects.

---

## Laws

Source: `src/haskell/test/Cat/BraidedMonoidalSpec.hs`

**Braiding roundtrip:**
$$\sigma^{-1}_{A,B} \circ \sigma_{A,B} = \id, \qquad \sigma_{A,B} \circ \sigma^{-1}_{A,B} = \id$$

**Braiding naturality:** for all $f$, $g$:
$$\sigma \circ (f \otimes g) = (g \otimes f) \circ \sigma$$

**Hexagon 1:**
$$\alpha_{B,C,A} \circ \sigma_{A, B \otimes C} \circ \alpha_{A,B,C}
  = (\id_B \otimes \sigma_{A,C}) \circ \alpha_{B,A,C} \circ (\sigma_{A,B} \otimes \id_C)$$

**Hexagon 2:**
$$\alpha^{-1}_{C,A,B} \circ \sigma_{A \otimes B, C} \circ \alpha^{-1}_{A,B,C}
  = (\sigma_{A,C} \otimes \id_B) \circ \alpha^{-1}_{A,C,B} \circ (\id_A \otimes \sigma_{B,C})$$
