-- Category: the fundamental structure.
-- Reference: Stacks Project Tag 0013 (Definition 4.2.1)
-- Design: follows Hu & Carette (agda-categories) — setoid equality,
-- three universe levels (o, ℓ, e) per category.
module Cat.Category where

open import Level
open import Relation.Binary using (Rel; IsEquivalence)

record Category (o ℓ e : Level) : Set (suc (o ⊔ ℓ ⊔ e)) where
  infixr 9 _∘_
  infixr 9 _≫_
  infix  4 _≈_
  infix  1 _⇒_

  field
    Obj : Set o
    _⇒_ : Obj → Obj → Set ℓ
    _≈_ : ∀ {A B} → Rel (A ⇒ B) e
    id  : ∀ {A} → A ⇒ A
    _∘_ : ∀ {A B C} → B ⇒ C → A ⇒ B → A ⇒ C

  field
    assoc     : ∀ {A B C D} {f : A ⇒ B} {g : B ⇒ C} {h : C ⇒ D}
              → (h ∘ g) ∘ f ≈ h ∘ (g ∘ f)
    sym-assoc : ∀ {A B C D} {f : A ⇒ B} {g : B ⇒ C} {h : C ⇒ D}
              → h ∘ (g ∘ f) ≈ (h ∘ g) ∘ f
    identityˡ : ∀ {A B} {f : A ⇒ B} → id ∘ f ≈ f
    identityʳ : ∀ {A B} {f : A ⇒ B} → f ∘ id ≈ f
    identity² : ∀ {A} → id ∘ id {A} ≈ id {A}
    equiv     : ∀ {A B} → IsEquivalence (_≈_ {A} {B})
    ∘-resp-≈  : ∀ {A B C} {f h : B ⇒ C} {g i : A ⇒ B}
              → f ≈ h → g ≈ i → f ∘ g ≈ h ∘ i

  -- Diagrammatic (forward) composition: f then g.
  _≫_ : ∀ {A B C} → A ⇒ B → B ⇒ C → A ⇒ C
  f ≫ g = g ∘ f
