-- Product category C × D.
-- Reference: nLab product+category
-- Objects are pairs, morphisms are pairs, laws hold componentwise.
module Cat.Product where

open import Level
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Relation.Binary using (Rel; IsEquivalence)
open import Cat.Category

Product : ∀ {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂}
        → Category o₁ ℓ₁ e₁ → Category o₂ ℓ₂ e₂
        → Category (o₁ ⊔ o₂) (ℓ₁ ⊔ ℓ₂) (e₁ ⊔ e₂)
Product C D = record
  { Obj       = C.Obj × D.Obj
  ; _⇒_       = λ { (a₁ , a₂) (b₁ , b₂) → (a₁ C.⇒ b₁) × (a₂ D.⇒ b₂) }
  ; _≈_       = λ { (f₁ , f₂) (g₁ , g₂) → (f₁ C.≈ g₁) × (f₂ D.≈ g₂) }
  ; id        = C.id , D.id
  ; _∘_       = λ { (f₁ , f₂) (g₁ , g₂) → (f₁ C.∘ g₁) , (f₂ D.∘ g₂) }
  ; assoc     = C.assoc , D.assoc
  ; sym-assoc = C.sym-assoc , D.sym-assoc
  ; identityˡ = C.identityˡ , D.identityˡ
  ; identityʳ = C.identityʳ , D.identityʳ
  ; identity² = C.identity² , D.identity²
  ; equiv     = record
    { refl  = C-equiv.refl , D-equiv.refl
    ; sym   = λ { (p , q) → C-equiv.sym p , D-equiv.sym q }
    ; trans = λ { (p₁ , q₁) (p₂ , q₂) → C-equiv.trans p₁ p₂ , D-equiv.trans q₁ q₂ }
    }
  ; ∘-resp-≈  = λ { (p₁ , q₁) (p₂ , q₂) → C.∘-resp-≈ p₁ p₂ , D.∘-resp-≈ q₁ q₂ }
  }
  where
    module C = Category C
    module D = Category D
    module C-equiv {A} {B} = IsEquivalence (C.equiv {A} {B})
    module D-equiv {A} {B} = IsEquivalence (D.equiv {A} {B})
