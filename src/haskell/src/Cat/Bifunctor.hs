-- | Bifunctor -- a functor from a product category C x D to E.
--
-- Mathematical definition (nLab: bifunctor):
-- A bifunctor \(F : \mathcal{C} \times \mathcal{D} \to \mathcal{E}\)
-- is a functor from the product category
-- \(\mathcal{C} \times \mathcal{D}\) to \(\mathcal{E}\).
-- Equivalently, a map that is functorial in each argument separately,
-- with a compatibility (interchange) condition.
--
-- This module provides the data track encoding only (records, not typeclasses),
-- consistent with the monoidal phase design.
--
-- Laws:
--
-- [Identity]    @bimap id id = id@
-- [Composition] @bimap (compose f2 f1) (compose g2 g1) = compose (bimap f2 g2) (bimap f1 g1)@
module Cat.Bifunctor
  ( -- * Data track
    BifunctorData(..)
  , firstData
  , secondData
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..))

--------------------------------------------------------------------------------
-- Data track
--------------------------------------------------------------------------------

-- | A bifunctor reified as data. The type parameter @f@ has kind
-- @Type -> Type -> Type@, mapping pairs of objects to objects of E.
--
-- The three hom-type parameters @hom1@, @hom2@, @hom3@ represent
-- the morphism types of categories C, D, and E respectively.
--
-- Given morphisms @f : a1 -> b1@ in C (via @hom1@) and
-- @g : a2 -> b2@ in D (via @hom2@), the action
-- @bimap f g : F(a1,a2) -> F(b1,b2)@ in E (via @hom3@).
--
-- Laws:
--
-- [Identity]    @bimap id id = id@
-- [Composition] @bimap (compose f2 f1) (compose g2 g1) = compose (bimap f2 g2) (bimap f1 g1)@
--
-- nLab: bifunctor.
data BifunctorData (hom1 :: Type -> Type -> Type)
                   (hom2 :: Type -> Type -> Type)
                   (hom3 :: Type -> Type -> Type)
                   (f :: Type -> Type -> Type) = BifunctorData
  { bimap :: forall a1 b1 a2 b2. hom1 a1 b1 -> hom2 a2 b2 -> hom3 (f a1 a2) (f b1 b2)
    -- ^ The action on morphisms. Given @f : a1 -> b1@ in C and @g : a2 -> b2@ in D,
    -- produces @bimap f g : F(a1,a2) -> F(b1,b2)@ in E.
  }

-- | Apply a bifunctor in the first argument only, holding the second
-- argument at the identity morphism.
--
-- @firstData bf f = bimap bf f id@
--
-- This corresponds to the partial functor F(-, d) for a fixed object d.
--
-- nLab: bifunctor.
firstData :: Category hom2
          => BifunctorData hom1 hom2 hom3 f
          -> hom1 a b
          -> hom3 (f a c) (f b c)
firstData bf f = bimap bf f id

-- | Apply a bifunctor in the second argument only, holding the first
-- argument at the identity morphism.
--
-- @secondData bf g = bimap bf id g@
--
-- This corresponds to the partial functor F(c, -) for a fixed object c.
--
-- nLab: bifunctor.
secondData :: Category hom1
           => BifunctorData hom1 hom2 hom3 f
           -> hom2 a b
           -> hom3 (f c a) (f c b)
secondData bf g = bimap bf id g
