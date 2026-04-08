-- Natural isomorphism: an invertible natural transformation.
-- A natural isomorphism α : F ≅ G is a pair of natural transformations
-- (forward, backward) whose vertical composites are identity in both directions.
-- Reference: nLab, natural+isomorphism
module Cat.NaturalIsomorphism where

open import Level
open import Cat.Category
open import Cat.Functor
open import Cat.NaturalTransformation

record NaturalIsomorphism {o₁ ℓ₁ e₁ o₂ ℓ₂ e₂ : Level}
                          {C : Category o₁ ℓ₁ e₁} {D : Category o₂ ℓ₂ e₂}
                          (F G : Functor C D)
                          : Set (o₁ ⊔ ℓ₁ ⊔ e₁ ⊔ o₂ ⊔ ℓ₂ ⊔ e₂) where
  private
    module C = Category C
    module D = Category D
    module F = Functor F
    module G = Functor G

  field
    forward  : NaturalTransformation F G
    backward : NaturalTransformation G F

  private
    module fwd = NaturalTransformation forward
    module bwd = NaturalTransformation backward

  field
    isoˡ : ∀ (X : C.Obj) → (bwd.η X D.∘ fwd.η X) D.≈ D.id
    isoʳ : ∀ (X : C.Obj) → (fwd.η X D.∘ bwd.η X) D.≈ D.id
