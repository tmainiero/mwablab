-- Braided monoidal category.
-- A monoidal category equipped with a braiding natural isomorphism
-- σ_{A,B} : A ⊗ B → B ⊗ A satisfying two hexagon coherence axioms.
--
-- The hexagon axioms ensure that the braiding is compatible with
-- the associator: the two distinct ways of moving an object past
-- a tensor product (one factor at a time vs. all at once, after
-- reassociating) yield the same morphism.
--
-- Reference: nLab, braided+monoidal+category
module Cat.BraidedMonoidal where

open import Level
open import Cat.Category
open import Cat.Functor
open import Cat.Product
open import Cat.Monoidal

record Braided {o ℓ e : Level} {C : Category o ℓ e} (M : Monoidal C) : Set (suc (o ⊔ ℓ ⊔ e)) where

  private
    module C = Category C

  open Monoidal M

  -- ── Braiding ─────────────────────────────────────────────────
  -- A natural isomorphism σ_{A,B} : A ⊗ B ≅ B ⊗ A.

  field
    -- Forward component: σ_{A,B} : A ⊗ B → B ⊗ A
    σ→ : ∀ (A B : C.Obj) → (A ⊗₀ B) C.⇒ (B ⊗₀ A)

    -- Backward component: σ⁻¹_{A,B} : B ⊗ A → A ⊗ B
    σ← : ∀ (A B : C.Obj) → (B ⊗₀ A) C.⇒ (A ⊗₀ B)

  -- ── Isomorphism conditions ───────────────────────────────────
  -- σ⁻¹ ∘ σ = id  and  σ ∘ σ⁻¹ = id.

  field
    σ-isoˡ : ∀ (A B : C.Obj) → (σ← A B C.∘ σ→ A B) C.≈ C.id
    σ-isoʳ : ∀ (A B : C.Obj) → (σ→ A B C.∘ σ← A B) C.≈ C.id

  -- ── Naturality ───────────────────────────────────────────────
  -- For f : A₁ → A₂, g : B₁ → B₂:
  --   σ→(A₂,B₂) ∘ (f ⊗ g) = (g ⊗ f) ∘ σ→(A₁,B₁)

  field
    σ-natural : ∀ {A₁ A₂ B₁ B₂}
                  (f : A₁ C.⇒ A₂) (g : B₁ C.⇒ B₂)
              → (σ→ A₂ B₂ C.∘ (f ⊗₁ g))
                C.≈
                ((g ⊗₁ f) C.∘ σ→ A₁ B₁)

  -- ── Hexagon axiom 1 ─────────────────────────────────────────
  -- Moving A past B ⊗ C via the associator:
  --
  --   α→(B,C,A) ∘ σ→(A, B⊗C) ∘ α→(A,B,C)
  --     = (id_B ⊗ σ→(A,C)) ∘ α→(B,A,C) ∘ (σ→(A,B) ⊗ id_C)
  --
  -- Starting from (A ⊗ B) ⊗ C.

  field
    hexagon₁ : ∀ (A B D : C.Obj)
             → (α→ B D A C.∘ (σ→ A (B ⊗₀ D) C.∘ α→ A B D))
               C.≈
               ((C.id {B} ⊗₁ σ→ A D) C.∘ (α→ B A D C.∘ (σ→ A B ⊗₁ C.id {D})))

  -- ── Hexagon axiom 2 ─────────────────────────────────────────
  -- Moving C past A ⊗ B via the associator:
  --
  --   α←(C,A,B) ∘ σ→(A⊗B, C) ∘ α←(A,B,C)
  --     = (σ→(A,C) ⊗ id_B) ∘ α←(A,C,B) ∘ (id_A ⊗ σ→(B,C))
  --
  -- Starting from A ⊗ (B ⊗ C).

  field
    hexagon₂ : ∀ (A B D : C.Obj)
             → (α← D A B C.∘ (σ→ (A ⊗₀ B) D C.∘ α← A B D))
               C.≈
               ((σ→ A D ⊗₁ C.id {B}) C.∘ (α← A D B C.∘ (C.id {A} ⊗₁ σ→ B D)))
