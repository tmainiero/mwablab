-- Symmetric monoidal category.
-- A braided monoidal category where the braiding is self-inverse:
-- σ_{B,A} ∘ σ_{A,B} = id_{A⊗B} for all objects A, B.
--
-- Equivalently, σ⁻¹_{A,B} = σ_{B,A}.  This collapses the two hexagon
-- axioms into a single condition and makes the braiding involutive.
--
-- Reference: nLab, symmetric+monoidal+category
module Cat.SymmetricMonoidal where

open import Level
open import Cat.Category
open import Cat.Monoidal
open import Cat.BraidedMonoidal

record Symmetric {o ℓ e : Level}
                 {C : Category o ℓ e}
                 {M : Monoidal C}
                 (B : Braided M) : Set (suc (o ⊔ ℓ ⊔ e)) where

  private
    module C = Category C

  open Monoidal M
  open Braided B

  -- ── Symmetry condition ───────────────────────────────────────
  -- σ_{B,A} ∘ σ_{A,B} = id_{A⊗B}.
  -- This is the defining property that upgrades a braiding to a
  -- symmetric braiding.

  field
    symmetry : ∀ (A B : C.Obj) → (σ→ B A C.∘ σ→ A B) C.≈ C.id
