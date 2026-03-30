-- | Functor — structure-preserving map between categories.
--
-- Mathematical definition (Stacks Project 0014):
-- A functor \(F : \mathcal{C} \to \mathcal{D}\) consists of a map on objects
-- and a map on morphisms preserving identity and composition.
--
-- Laws:
--
-- [Identity]    @fmap id = id@
-- [Composition] @fmap (g ∘ f) = fmap g ∘ fmap f@
module Cat.Functor
  ( -- * Typeclass track
    CFunctor(..)
    -- * Data track
  , FunctorData(..)
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..))

--------------------------------------------------------------------------------
-- Typeclass track
--------------------------------------------------------------------------------

-- | A functor between categories @cat1@ and @cat2@, mapping objects via
-- the type constructor @f@ and morphisms via 'cmap'.
--
-- Named 'CFunctor' (categorical functor) to avoid collision with
-- @Prelude.Functor@.
--
-- Laws:
--
-- [Identity]    @'cmap' 'id' = 'id'@
-- [Composition] @'cmap' (g '∘' f) = 'cmap' g '∘' 'cmap' f@
--
-- Stacks Project 0014, Definition 3.2.
class (Category cat1, Category cat2)
    ⇒ CFunctor (f ∷ k1 → k2) (cat1 ∷ k1 → k1 → Type) (cat2 ∷ k2 → k2 → Type)
    | f → cat1 cat2 where
  -- | The action of the functor on morphisms. Given @g : a → b@ in @cat1@,
  -- produces @F(g) : F(a) → F(b)@ in @cat2@.
  cmap ∷ cat1 a b → cat2 (f a) (f b)

--------------------------------------------------------------------------------
-- Data track
--------------------------------------------------------------------------------

-- | A functor reified as data. Carries the morphism-mapping function
-- without requiring a typeclass instance.
--
-- Stacks Project 0014.
newtype FunctorData (hom1 ∷ Type → Type → Type) (hom2 ∷ Type → Type → Type) (f ∷ Type → Type)
  = FunctorData
  { fmapData ∷ ∀ a b. hom1 a b → hom2 (f a) (f b)
    -- ^ Action on morphisms.
  }
