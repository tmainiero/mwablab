-- Natural transformation: morphism between functors.
-- Reference: Stacks Project Tag 001I
module Cat.NaturalTransformation where

open import Level
open import Cat.Category
open import Cat.Functor

record NaturalTransformation {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
                             {C : Category o₁ ℓ₁ e₁} {D : Category o₂ ℓ₂ e₂}
                             (F G : Functor C D)
                             : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  private
    module C = Category C
    module D = Category D
    module F = Functor F
    module G = Functor G

  field
    η           : ∀ (X : C.Obj) → F.F₀ X D.⇒ G.F₀ X
    commute     : ∀ {X Y} (f : X C.⇒ Y)
                → (η Y D.∘ F.F₁ f) D.≈ (G.F₁ f D.∘ η X)
    sym-commute : ∀ {X Y} (f : X C.⇒ Y)
                → (G.F₁ f D.∘ η X) D.≈ (η Y D.∘ F.F₁ f)
