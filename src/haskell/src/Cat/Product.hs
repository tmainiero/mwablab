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
-- This module provides the data-track encoding of product categories,
-- using value-level pairs as objects and 'ProdHom' as morphisms.
module Cat.Product
  ( -- * Value-level pair projections
    Fst'
  , Snd'
    -- * Product morphisms (data track)
  , ProdHom(..)
  , productData
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (CategoryData(..))

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
