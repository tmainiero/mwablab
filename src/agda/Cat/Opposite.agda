-- Opposite category: reverse all morphisms.
-- Reference: Stacks Project Tag 001C (Categories, Section 4.2)
-- Hom_{C^op}(A,B) = Hom_C(B,A)
module Cat.Opposite where

open import Level
open import Function using (flip)
open import Cat.Category

_op : ∀ {o ℓ e} → Category o ℓ e → Category o ℓ e
C op = record
  { Obj       = Obj
  ; _⇒_       = flip _⇒_
  ; _≈_       = _≈_
  ; id        = id
  ; _∘_       = flip _∘_
  ; assoc     = sym-assoc
  ; sym-assoc = assoc
  ; identityˡ = identityʳ
  ; identityʳ = identityˡ
  ; identity² = identity²
  ; equiv     = equiv
  ; ∘-resp-≈  = flip ∘-resp-≈
  }
  where open Category C
