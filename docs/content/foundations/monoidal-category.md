---
title: Monoidal Category
---

A *monoidal category* equips a category with a notion of "multiplication"
of objects and morphisms,
coherently associative and unital up to natural isomorphism.

## Definition

A **monoidal category**
$(\Category{C}, \otimes, I, \alpha, \lambda, \rho)$
consists of:

1. A category $\Category{C}$.

2. A **tensor product** bifunctor
   $\otimes \colon \Category{C} \times \Category{C} \to \Category{C}$.
   We write $A \otimes B$ for $\otimes(A, B)$ on objects
   and $f \otimes g$ for $\operatorname{bimap}(f, g)$ on morphisms.

3. A **unit object** $I \in \Ob(\Category{C})$.

4. An **associator**, a natural isomorphism with components
   $$\alpha_{A,B,C} \colon (A \otimes B) \otimes C \xrightarrow{\;\sim\;} A \otimes (B \otimes C)$$
   natural in $A$, $B$, and $C$.

5. A **left unitor**, a natural isomorphism with components
   $$\lambda_A \colon I \otimes A \xrightarrow{\;\sim\;} A$$
   natural in $A$.

6. A **right unitor**, a natural isomorphism with components
   $$\rho_A \colon A \otimes I \xrightarrow{\;\sim\;} A$$
   natural in $A$.

These data are subject to the pentagon and triangle coherence axioms.

Reference: [nLab, monoidal category](https://ncatlab.org/nlab/show/monoidal+category);
Mac Lane, *Categories for the Working Mathematician*, Chapter VII.

---

## Pentagon axiom

For all objects $A, B, C, D \in \Ob(\Category{C})$, the following diagram commutes:

```
                        α_{A,B,C} ⊗ id_D
  ((A⊗B)⊗C)⊗D  ──────────────────────────►  (A⊗(B⊗C))⊗D
        │                                           │
        │ α_{A⊗B,C,D}                              │ α_{A,B⊗C,D}
        ▼                                           ▼
  (A⊗B)⊗(C⊗D)                                A⊗((B⊗C)⊗D)
        │                                           │
        │ α_{A,B,C⊗D}                              │ id_A ⊗ α_{B,C,D}
        ▼                                           ▼
  A⊗(B⊗(C⊗D))  ◄══════════════════════════  A⊗(B⊗(C⊗D))
```

The two composite paths from $((A \otimes B) \otimes C) \otimes D$
to $A \otimes (B \otimes (C \otimes D))$ are equal.

---

## Triangle axiom

For all objects $A, B \in \Ob(\Category{C})$, the following diagram commutes:

```
  (A⊗I)⊗B ────α_{A,I,B}────► A⊗(I⊗B)
       \                        /
    ρ_A ⊗ id_B          id_A ⊗ λ_B
         \                    /
          ▼                  ▼
              A ⊗ B
```

That is, $(\id_A \otimes \lambda_B) \circ \alpha_{A,I,B} = \rho_A \otimes \id_B$.

---

## Coherence and strictness

**Coherence theorem.** Mac Lane's coherence theorem states that
every diagram whose edges are built from
$\alpha$, $\lambda$, $\rho$, their inverses,
identities, and tensor products of these
commutes.
The pentagon and triangle axioms suffice to ensure coherence
of all re-bracketing and unit-insertion paths (Mac Lane, *CWM* VII.2).

**Strictness.** A **strict monoidal category** is one where
$\alpha$, $\lambda$, and $\rho$ are all identity natural transformations.
By the coherence theorem,
every monoidal category is monoidally equivalent to a strict one.
This definition uses the non-strict formulation.

---

## Haskell

Source: `src/haskell/src/Cat/Monoidal.hs`

The module provides a data track encoding only (records, not typeclasses).
The associator and unitors are stored as rank-2 component families
rather than as `NatIso` values, since the associator is a natural isomorphism
between *trifunctors* $\Category{C}^3 \to \Category{C}$.

```haskell
data MonoidalData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = MonoidalData
  { monCat             :: CategoryData hom
  , monTensor          :: BifunctorData hom hom hom tensor
  , monAssocFwd        :: forall a b c. hom (tensor (tensor a b) c) (tensor a (tensor b c))
  , monAssocBwd        :: forall a b c. hom (tensor a (tensor b c)) (tensor (tensor a b) c)
  , monLeftUnitorFwd   :: forall a. hom (tensor unit a) a
  , monLeftUnitorBwd   :: forall a. hom a (tensor unit a)
  , monRightUnitorFwd  :: forall a. hom (tensor a unit) a
  , monRightUnitorBwd  :: forall a. hom a (tensor a unit)
  }
```

The record stores the underlying category, the tensor bifunctor,
and forward/backward components for each coherence isomorphism.

---

## Agda

Source: `src/agda/Cat/Monoidal.agda`

```agda
record Monoidal {o ℓ e : Level} (C : Category o ℓ e) : Set (suc (o ⊔ ℓ ⊔ e)) where
  field
    tensor : Bifunctor C C C
    unit   : C.Obj
    α→     : ∀ (A B D : C.Obj) → ((A ⊗₀ B) ⊗₀ D) C.⇒ (A ⊗₀ (B ⊗₀ D))
    α←     : ∀ (A B D : C.Obj) → (A ⊗₀ (B ⊗₀ D)) C.⇒ ((A ⊗₀ B) ⊗₀ D)
    λ→     : ∀ (A : C.Obj) → (unit ⊗₀ A) C.⇒ A
    λ←     : ∀ (A : C.Obj) → A C.⇒ (unit ⊗₀ A)
    ρ→     : ∀ (A : C.Obj) → (A ⊗₀ unit) C.⇒ A
    ρ←     : ∀ (A : C.Obj) → A C.⇒ (A ⊗₀ unit)
```

The record includes proof fields for:
isomorphism roundtrips (`α-isoˡ`, `α-isoʳ`, `λ-isoˡ`, `λ-isoʳ`, `ρ-isoˡ`, `ρ-isoʳ`),
naturality (`α-natural`, `λ-natural`, `ρ-natural`),
and the coherence axioms (`pentagon`, `triangle`).
All conditions are compile-time proof obligations.

---

## Common Lisp

Source: `src/lisp/src/monoidal-category.lisp`

```common-lisp
(defclass monoidal-category ()
  ((base-category        :initarg :base-category        :accessor monoidal-base-category)
   (tensor               :initarg :tensor               :accessor monoidal-tensor)
   (unit-object          :initarg :unit-object          :accessor monoidal-unit)
   (associator-forward   :initarg :associator-forward   :accessor monoidal-associator-forward)
   (associator-backward  :initarg :associator-backward  :accessor monoidal-associator-backward)
   (left-unitor-forward  :initarg :left-unitor-forward  :accessor monoidal-left-unitor-forward)
   (left-unitor-backward :initarg :left-unitor-backward :accessor monoidal-left-unitor-backward)
   (right-unitor-forward :initarg :right-unitor-forward :accessor monoidal-right-unitor-forward)
   (right-unitor-backward :initarg :right-unitor-backward :accessor monoidal-right-unitor-backward)))
```

The CLOS class stores the underlying category, tensor bifunctor, unit object,
and function-valued slots for each coherence morphism family.
Generic functions `tensor-objects`, `tensor-morphisms`, `associator-at`,
`left-unitor-at`, and `right-unitor-at` provide the public interface.

---

## Julia

Source: `src/julia/src/Monoidal.jl`

GATlab expresses monoidal categories as a theory extending `ThCategory` with tensor product, unit, and coherence isomorphisms.

```julia
@theory ThMonoidalCategory <: ThCategory begin
    otimes(a::Ob, b::Ob)::Ob
    otimes(f::Hom(a, b), g::Hom(c, d))::Hom(otimes(a, c), otimes(b, d)) ⊣
        [a::Ob, b::Ob, c::Ob, d::Ob]

    munit()::Ob

    associator(a::Ob, b::Ob, c::Ob)::Hom(otimes(otimes(a, b), c), otimes(a, otimes(b, c)))
    associator_inv(a::Ob, b::Ob, c::Ob)::Hom(otimes(a, otimes(b, c)), otimes(otimes(a, b), c))
    left_unitor(a::Ob)::Hom(otimes(munit(), a), a)
    left_unitor_inv(a::Ob)::Hom(a, otimes(munit(), a))
    right_unitor(a::Ob)::Hom(otimes(a, munit()), a)
    right_unitor_inv(a::Ob)::Hom(a, otimes(a, munit()))

    # Roundtrip, bifunctoriality axioms as equations
    # Pentagon and triangle verified in tests (term depth may exceed parser)
end
```

The `<:` syntax declares theory extension, inheriting all of `ThCategory`. The overloaded `otimes` on both `Ob` and `Hom` sorts encodes the tensor bifunctor directly. Roundtrip axioms for all three isomorphisms and bifunctoriality of the tensor are stated as equational axioms. The pentagon and triangle coherence axioms are verified in tests rather than inline, as their nested term depth may exceed GATlab's equation parser. Uses GATlab v0.2.2.

Reference: [nLab, monoidal category](https://ncatlab.org/nlab/show/monoidal+category).

---

## Laws

Source: `src/haskell/test/Cat/MonoidalSpec.hs`

**Associator roundtrip:**
$$\alpha^{-1} \circ \alpha = \id, \qquad \alpha \circ \alpha^{-1} = \id$$

**Unitor roundtrips:**
$$\lambda^{-1} \circ \lambda = \id, \qquad \rho^{-1} \circ \rho = \id$$

**Associator naturality:** for all $f$, $g$, $h$:
$$\alpha \circ ((f \otimes g) \otimes h) = (f \otimes (g \otimes h)) \circ \alpha$$

**Pentagon:**
$$(\id_A \otimes \alpha_{B,C,D}) \circ \alpha_{A, B \otimes C, D} \circ (\alpha_{A,B,C} \otimes \id_D) = \alpha_{A,B, C \otimes D} \circ \alpha_{A \otimes B, C, D}$$

**Triangle:**
$$(\id_A \otimes \lambda_B) \circ \alpha_{A,I,B} = \rho_A \otimes \id_B$$
