-- Bifunctor: a functor from a product category C × D to E.
-- A bifunctor F : C × D → E is simply a Functor from (Product C D) to E.
-- Reference: nLab, bifunctor.
module Cat.Bifunctor where

open import Level
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Cat.Category
open import Cat.Functor
open import Cat.Product

-- A bifunctor is a functor from the product category.
-- We define it as a type alias for clarity.
Bifunctor : ∀ {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ o₃ ℓ₃ e₃}
          → Category o₁ ℓ₁ e₁
          → Category o₂ ℓ₂ e₂
          → Category o₃ ℓ₃ e₃
          → Set _
Bifunctor C D E = Functor (Product C D) E

-- Convenience module for working with bifunctors.
module BifunctorOps {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ o₃ ℓ₃ e₃}
                    {C : Category o₁ ℓ₁ e₁}
                    {D : Category o₂ ℓ₂ e₂}
                    {E : Category o₃ ℓ₃ e₃}
                    (F : Bifunctor C D E) where

  private
    module C = Category C
    module D = Category D
    module E = Category E
    module F = Functor F

  -- The action on pairs of objects.
  bimap₀ : C.Obj × D.Obj → E.Obj
  bimap₀ = F.F₀

  -- The action on pairs of morphisms (the bimap operation).
  bimap₁ : ∀ {A₁ A₂ B₁ B₂}
         → A₁ C.⇒ A₂ → B₁ D.⇒ B₂
         → F.F₀ (A₁ , B₁) E.⇒ F.F₀ (A₂ , B₂)
  bimap₁ f g = F.F₁ (f , g)

  -- Apply in the first argument only, holding the second at identity.
  -- This gives the partial functor F(-, d).
  first₁ : ∀ {A₁ A₂ B}
          → A₁ C.⇒ A₂
          → F.F₀ (A₁ , B) E.⇒ F.F₀ (A₂ , B)
  first₁ f = bimap₁ f D.id

  -- Apply in the second argument only, holding the first at identity.
  -- This gives the partial functor F(c, -).
  second₁ : ∀ {A B₁ B₂}
           → B₁ D.⇒ B₂
           → F.F₀ (A , B₁) E.⇒ F.F₀ (A , B₂)
  second₁ g = bimap₁ C.id g
