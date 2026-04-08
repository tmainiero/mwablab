-- | Concrete monoidal category instances for reuse and testing.
--
-- This module provides the two canonical symmetric monoidal structures
-- on the category of sets (Haskell types with functions):
--
-- 1. The __cartesian__ monoidal structure @(Set, (,), ())@,
--    where the tensor product is the cartesian product.
--
-- 2. The __cocartesian__ monoidal structure @(Set, Either, Void)@,
--    where the tensor product is the coproduct (disjoint union).
--
-- Both are symmetric monoidal categories. The constructions are built
-- bottom-up: 'MonoidalData' -> 'BraidedData' -> 'SymmetricData'.
--
-- nLab: cartesian+monoidal+category, cocartesian+monoidal+category.
module Cat.Examples.Monoidal
  ( -- * Cartesian monoidal structure (Set, (,), ())
    setProduct
  , setProductBraided
  , setProductMonoidal
    -- * Cocartesian monoidal structure (Set, Either, Void)
  , setCoproduct
  , setCoproductBraided
  , setCoproductMonoidal
  ) where

import Prelude hiding (id, (.))
import Data.Void (Void, absurd)

import Cat.Category (categoryDataFromClass)
import Cat.Examples ()  -- (->) Category instance
import Cat.Bifunctor (BifunctorData(..))
import Cat.Monoidal (MonoidalData(..))
import Cat.BraidedMonoidal (BraidedData(..))
import Cat.SymmetricMonoidal (SymmetricData(..))

--------------------------------------------------------------------------------
-- Cartesian monoidal structure: (Set, (,), ())
--------------------------------------------------------------------------------

-- | The cartesian monoidal structure on Set.
-- Tensor product is @(,)@, unit is @()@.
-- This is a symmetric monoidal category.
--
-- * Tensor: @bimap f g (a, b) = (f a, g b)@
-- * Associator: @((a,b),c) <-> (a,(b,c))@
-- * Left unitor: @((),a) <-> a@
-- * Right unitor: @(a,()) <-> a@
-- * Braiding: @(a,b) <-> (b,a)@ (swap)
--
-- nLab: cartesian+monoidal+category.
setProduct :: SymmetricData (->) (,) ()
setProduct = SymmetricData
  { symmetricBraided = BraidedData
    { braidedMonoidal = MonoidalData
      { monCat = categoryDataFromClass
      , monTensor = BifunctorData
        { bimap = \f g (a, b) -> (f a, g b) }
      , monAssocFwd = \((a, b), c) -> (a, (b, c))
      , monAssocBwd = \(a, (b, c)) -> ((a, b), c)
      , monLeftUnitorFwd = \((), a) -> a
      , monLeftUnitorBwd = \a -> ((), a)
      , monRightUnitorFwd = \(a, ()) -> a
      , monRightUnitorBwd = \a -> (a, ())
      }
    , braidingFwd = \(a, b) -> (b, a)
    , braidingBwd = \(a, b) -> (b, a)
    }
  }

-- | The braided monoidal structure underlying 'setProduct'.
setProductBraided :: BraidedData (->) (,) ()
setProductBraided = symmetricBraided setProduct

-- | The monoidal structure underlying 'setProduct'.
setProductMonoidal :: MonoidalData (->) (,) ()
setProductMonoidal = braidedMonoidal (symmetricBraided setProduct)

--------------------------------------------------------------------------------
-- Cocartesian monoidal structure: (Set, Either, Void)
--------------------------------------------------------------------------------

-- | The cocartesian monoidal structure on Set.
-- Tensor product is @Either@, unit is @Void@ (empty type).
-- This is a symmetric monoidal category.
--
-- * Tensor: @bimap f g (Left a) = Left (f a); bimap f g (Right b) = Right (g b)@
-- * Associator: @Either (Either a b) c <-> Either a (Either b c)@
-- * Left unitor: @Either Void a <-> a@
-- * Right unitor: @Either a Void <-> a@
-- * Braiding: @Left a <-> Right a; Right b <-> Left b@
--
-- nLab: cocartesian+monoidal+category.
setCoproduct :: SymmetricData (->) Either Void
setCoproduct = SymmetricData
  { symmetricBraided = BraidedData
    { braidedMonoidal = MonoidalData
      { monCat = categoryDataFromClass
      , monTensor = BifunctorData
        { bimap = \f g x -> case x of
            Left a  -> Left (f a)
            Right b -> Right (g b)
        }
      , monAssocFwd = \x -> case x of
          Left (Left a)   -> Left a
          Left (Right b)  -> Right (Left b)
          Right c         -> Right (Right c)
      , monAssocBwd = \x -> case x of
          Left a          -> Left (Left a)
          Right (Left b)  -> Left (Right b)
          Right (Right c) -> Right c
      , monLeftUnitorFwd = \x -> case x of
          Left v  -> absurd v
          Right a -> a
      , monLeftUnitorBwd = \a -> Right a
      , monRightUnitorFwd = \x -> case x of
          Left a  -> a
          Right v -> absurd v
      , monRightUnitorBwd = \a -> Left a
      }
    , braidingFwd = \x -> case x of
        Left a  -> Right a
        Right b -> Left b
    , braidingBwd = \x -> case x of
        Left a  -> Right a
        Right b -> Left b
    }
  }

-- | The braided monoidal structure underlying 'setCoproduct'.
setCoproductBraided :: BraidedData (->) Either Void
setCoproductBraided = symmetricBraided setCoproduct

-- | The monoidal structure underlying 'setCoproduct'.
setCoproductMonoidal :: MonoidalData (->) Either Void
setCoproductMonoidal = braidedMonoidal (symmetricBraided setCoproduct)
