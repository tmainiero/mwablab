-- | Product category C x D.
--
-- Mathematical definition (nLab: product+category):
-- Given categories C and D, the product category C x D has:
--
-- * Objects: pairs (X, Y) with X in Ob(C) and Y in Ob(D)
-- * Morphisms: pairs (f, g) with f : X1 -> X2 in C and g : Y1 -> Y2 in D
-- * Identity: (id_X, id_Y)
-- * Composition: (f2, g2) . (f1, g1) = (f2 . f1, g2 . g1)
--
-- This module provides both typeclass and data track encodings.
module Cat.Product
  ( -- * Type-level pair projections
    Fst
  , Snd
    -- * Product morphisms (typeclass track)
  , Prod(..)
    -- * Projection functors (typeclass track)
  , FstProj(..)
  , SndProj(..)
    -- * Data track
  , ProdHom(..)
  , productData
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..), CategoryData(..))

--------------------------------------------------------------------------------
-- Type-level pair projections
--------------------------------------------------------------------------------

-- | Extract the first component of a promoted pair @'(a, b)@.
type family Fst (p :: (a, b)) :: a where
  Fst '(x, _) = x

-- | Extract the second component of a promoted pair @'(a, b)@.
type family Snd (p :: (a, b)) :: b where
  Snd '(_, y) = y

--------------------------------------------------------------------------------
-- Product morphisms (typeclass track)
--------------------------------------------------------------------------------

-- | A morphism in the product category C x D.
--
-- Source and target are type-level pairs @'(a1, a2)@ and @'(b1, b2)@.
-- A morphism @(a1,a2) -> (b1,b2)@ is a pair of morphisms
-- @f : a1 -> b1@ in @cat1@ and @g : a2 -> b2@ in @cat2@.
--
-- nLab: product+category.
newtype Prod (cat1 :: Type -> Type -> Type)
             (cat2 :: Type -> Type -> Type)
             (a :: (Type, Type))
             (b :: (Type, Type))
  = Prod { unProd :: (cat1 (Fst a) (Fst b), cat2 (Snd a) (Snd b)) }

-- | The product of two categories is a category.
--
-- Identity and composition are componentwise:
--
-- @
-- id                             = Prod (id, id)
-- compose (Prod (f1, f2))
--         (Prod (g1, g2))        = Prod (compose f1 g1, compose f2 g2)
-- @
--
-- nLab: product+category.
instance (Category cat1, Category cat2) => Category (Prod cat1 cat2) where
  id = Prod (id, id)
  compose (Prod (f1, f2)) (Prod (g1, g2)) = Prod (compose f1 g1, compose f2 g2)

--------------------------------------------------------------------------------
-- Projection functors (typeclass track)
--------------------------------------------------------------------------------

-- | Object wrapper for the first projection functor pi_1 : C x D -> C.
--
-- Maps an object @'(a, b)@ of the product category to @a@.
--
-- nLab: product+category.
newtype FstProj (a :: (Type, Type)) = FstProj { unFstProj :: Fst a }

-- | Object wrapper for the second projection functor pi_2 : C x D -> D.
--
-- Maps an object @'(a, b)@ of the product category to @b@.
--
-- nLab: product+category.
newtype SndProj (a :: (Type, Type)) = SndProj { unSndProj :: Snd a }

--------------------------------------------------------------------------------
-- Data track
--------------------------------------------------------------------------------

-- | A morphism in the product category, indexed by plain types rather than
-- promoted pairs. This lets 'productData' produce a @CategoryData@ value
-- (which requires kind @Type -> Type -> Type@).
--
-- The four type parameters encode the pair structure:
-- @ProdHom cat1 cat2 (a1,a2) (b1,b2)@ but at the flat kind level,
-- objects are represented as nested pairs @(a1, a2)@.
--
-- nLab: product+category.
newtype ProdHom (cat1 :: Type -> Type -> Type)
                (cat2 :: Type -> Type -> Type)
                (a :: Type)
                (b :: Type)
  = ProdHom { unProdHom :: (cat1 (Fst' a) (Fst' b), cat2 (Snd' a) (Snd' b)) }

-- | Extract the first component of a value-level pair type.
type family Fst' (p :: Type) :: Type where
  Fst' (a, b) = a

-- | Extract the second component of a value-level pair type.
type family Snd' (p :: Type) :: Type where
  Snd' (a, b) = b

-- | Build the product category C x D from data-track representations of
-- C and D.
--
-- Objects are Haskell pair types @(a, b)@. Morphisms @(a1,a2) -> (b1,b2)@
-- are pairs of component morphisms wrapped in 'ProdHom'.
-- Identity and composition are componentwise.
--
-- nLab: product+category.
productData :: CategoryData cat1 -> CategoryData cat2 -> CategoryData (ProdHom cat1 cat2)
productData c d = CatData
  { catIdentity = ProdHom (catIdentity c, catIdentity d)
  , catCompose  = \(ProdHom (f1, f2)) (ProdHom (g1, g2)) ->
      ProdHom (catCompose c f1 g1, catCompose d f2 g2)
  }
