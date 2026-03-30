-- Functor: structure-preserving map between categories.
-- Reference: Stacks Project Tag 001B
module Cat.Functor where

open import Level
open import Cat.Category

record Functor {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
               (C : Category o₁ ℓ₁ e₁) (D : Category o₂ ℓ₂ e₂)
               : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  private
    module C = Category C
    module D = Category D

  field
    F₀ : C.Obj → D.Obj
    F₁ : ∀ {A B} → A C.⇒ B → F₀ A D.⇒ F₀ B

  field
    identity     : ∀ {A} → F₁ (C.id {A}) D.≈ D.id
    homomorphism : ∀ {X Y Z} {f : X C.⇒ Y} {g : Y C.⇒ Z}
                 → F₁ (g C.∘ f) D.≈ (F₁ g D.∘ F₁ f)
    F-resp-≈     : ∀ {A B} {f g : A C.⇒ B}
                 → f C.≈ g → F₁ f D.≈ F₁ g
