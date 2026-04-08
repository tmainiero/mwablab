-- Monoidal category with full coherence (pentagon, triangle).
-- A monoidal category (C, ⊗, I, α, λ, ρ) is a category C equipped with
-- a bifunctor ⊗ : C × C → C, a unit object I, and natural isomorphisms
-- (associator, left unitor, right unitor) satisfying the pentagon and
-- triangle coherence axioms.
-- Reference: nLab, monoidal+category
module Cat.Monoidal where

open import Level
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Relation.Binary using (IsEquivalence)
open import Cat.Category
open import Cat.Functor
open import Cat.NaturalTransformation
open import Cat.NaturalIsomorphism
open import Cat.Product
open import Cat.Bifunctor

record Monoidal {o ℓ e : Level} (C : Category o ℓ e) : Set (suc (o ⊔ ℓ ⊔ e)) where

  private
    module C = Category C

  -- Notation: we write A ⊗₀ B for the tensor product of objects and
  -- f ⊗₁ g for the tensor product of morphisms.

  field
    -- The tensor bifunctor ⊗ : C × C → C.
    tensor : Bifunctor C C C

  private
    module ⊗ = Functor tensor

  -- Convenience aliases for the tensor product.
  -- Object-level: A ⊗₀ B
  _⊗₀_ : C.Obj → C.Obj → C.Obj
  A ⊗₀ B = ⊗.F₀ (A , B)

  -- Morphism-level: f ⊗₁ g
  _⊗₁_ : ∀ {A₁ A₂ B₁ B₂} → A₁ C.⇒ A₂ → B₁ C.⇒ B₂
        → (A₁ ⊗₀ B₁) C.⇒ (A₂ ⊗₀ B₂)
  f ⊗₁ g = ⊗.F₁ (f , g)

  field
    -- The unit object I.
    unit : C.Obj

  -- ── Associator ────────────────────────────────────────────────
  -- For objects A, B, C: an isomorphism (A ⊗ B) ⊗ C ≅ A ⊗ (B ⊗ C).
  -- This is a family of isomorphisms, natural in A, B, C.

  field
    -- Forward component: α_{A,B,C} : (A ⊗ B) ⊗ C → A ⊗ (B ⊗ C)
    α→ : ∀ (A B D : C.Obj) → ((A ⊗₀ B) ⊗₀ D) C.⇒ (A ⊗₀ (B ⊗₀ D))

    -- Backward component: α⁻¹_{A,B,C} : A ⊗ (B ⊗ C) → (A ⊗ B) ⊗ C
    α← : ∀ (A B D : C.Obj) → (A ⊗₀ (B ⊗₀ D)) C.⇒ ((A ⊗₀ B) ⊗₀ D)

  -- ── Left unitor ──────────────────────────────────────────────
  -- For each object A: an isomorphism I ⊗ A ≅ A.

  field
    -- Forward: λ_A : I ⊗ A → A
    λ→ : ∀ (A : C.Obj) → (unit ⊗₀ A) C.⇒ A

    -- Backward: λ⁻¹_A : A → I ⊗ A
    λ← : ∀ (A : C.Obj) → A C.⇒ (unit ⊗₀ A)

  -- ── Right unitor ─────────────────────────────────────────────
  -- For each object A: an isomorphism A ⊗ I ≅ A.

  field
    -- Forward: ρ_A : A ⊗ I → A
    ρ→ : ∀ (A : C.Obj) → (A ⊗₀ unit) C.⇒ A

    -- Backward: ρ⁻¹_A : A → A ⊗ I
    ρ← : ∀ (A : C.Obj) → A C.⇒ (A ⊗₀ unit)

  -- ── Isomorphism conditions ───────────────────────────────────
  -- Each structural morphism is an isomorphism (forward ∘ backward = id
  -- and backward ∘ forward = id).

  field
    α-isoˡ : ∀ (A B D : C.Obj) → (α← A B D C.∘ α→ A B D) C.≈ C.id
    α-isoʳ : ∀ (A B D : C.Obj) → (α→ A B D C.∘ α← A B D) C.≈ C.id

    λ-isoˡ : ∀ (A : C.Obj) → (λ← A C.∘ λ→ A) C.≈ C.id
    λ-isoʳ : ∀ (A : C.Obj) → (λ→ A C.∘ λ← A) C.≈ C.id

    ρ-isoˡ : ∀ (A : C.Obj) → (ρ← A C.∘ ρ→ A) C.≈ C.id
    ρ-isoʳ : ∀ (A : C.Obj) → (ρ→ A C.∘ ρ← A) C.≈ C.id

  -- ── Naturality ───────────────────────────────────────────────
  -- The associator is natural in all three arguments:
  -- for f : A₁ → A₂, g : B₁ → B₂, h : D₁ → D₂,
  --   α→(A₂,B₂,D₂) ∘ ((f ⊗ g) ⊗ h) = (f ⊗ (g ⊗ h)) ∘ α→(A₁,B₁,D₁)

  field
    α-natural : ∀ {A₁ A₂ B₁ B₂ D₁ D₂}
                  (f : A₁ C.⇒ A₂) (g : B₁ C.⇒ B₂) (h : D₁ C.⇒ D₂)
              → (α→ A₂ B₂ D₂ C.∘ ((f ⊗₁ g) ⊗₁ h))
                C.≈
                ((f ⊗₁ (g ⊗₁ h)) C.∘ α→ A₁ B₁ D₁)

  -- The left unitor is natural: for f : A → B,
  --   λ→(B) ∘ (id_I ⊗ f) = f ∘ λ→(A)

    λ-natural : ∀ {A B} (f : A C.⇒ B)
              → (λ→ B C.∘ (C.id ⊗₁ f)) C.≈ (f C.∘ λ→ A)

  -- The right unitor is natural: for f : A → B,
  --   ρ→(B) ∘ (f ⊗ id_I) = f ∘ ρ→(A)

    ρ-natural : ∀ {A B} (f : A C.⇒ B)
              → (ρ→ B C.∘ (f ⊗₁ C.id)) C.≈ (f C.∘ ρ→ A)

  -- ── Pentagon axiom ───────────────────────────────────────────
  -- The two paths around the pentagonal diagram commute.
  -- For all objects A, B, D, E:
  --
  --   (id_A ⊗ α(B,D,E)) ∘ α(A, B⊗D, E) ∘ (α(A,B,D) ⊗ id_E)
  --     = α(A, B, D⊗E) ∘ α(A⊗B, D, E)
  --
  -- Starting from ((A ⊗ B) ⊗ D) ⊗ E.

  field
    pentagon : ∀ (A B D E : C.Obj)
             → ((C.id {A} ⊗₁ α→ B D E) C.∘ (α→ A (B ⊗₀ D) E C.∘ (α→ A B D ⊗₁ C.id {E})))
               C.≈
               (α→ A B (D ⊗₀ E) C.∘ α→ (A ⊗₀ B) D E)

  -- ── Triangle axiom ──────────────────────────────────────────
  -- For all objects A, B:
  --
  --   (id_A ⊗ λ→(B)) ∘ α→(A, I, B) = ρ→(A) ⊗ id_B
  --
  -- Starting from (A ⊗ I) ⊗ B.

  field
    triangle : ∀ (A B : C.Obj)
             → ((C.id {A} ⊗₁ λ→ B) C.∘ α→ A unit B)
               C.≈
               (ρ→ A ⊗₁ C.id {B})
