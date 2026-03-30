-- | Concrete category instances.
--
-- This module provides instances of the 'Category' typeclass for
-- standard Haskell types, plus small example categories useful
-- for testing and exploration.
{-# OPTIONS_GHC -Wno-orphans #-}
module Cat.Examples
  ( -- * Discrete category
    Discrete(..)
    -- * Kleisli category
  , Kleisli(..)
  ) where

import Prelude hiding (id, (.))
import Control.Monad ((>=>))
import Data.Kind (Type)

import Cat.Category (Category(..))
import Cat.Functor (CFunctor(..))

--------------------------------------------------------------------------------
-- Hask: the category of Haskell types and functions
--------------------------------------------------------------------------------

-- | The category of Haskell types and functions @(->)@.
-- This is the prototypical Set-enriched category in Haskell.
--
-- * Objects: Haskell types
-- * Morphisms: functions @a -> b@
-- * Identity: @\x -> x@
-- * Composition: @(Prelude..)@
--
-- nLab: Hask.
instance Category (->) where
  id x = x
  compose g f x = g (f x)

--------------------------------------------------------------------------------
-- Discrete category
--------------------------------------------------------------------------------

-- | The discrete category on a type @a@: the only morphisms are identities.
--
-- \(\operatorname{Mor}(x, y) = \begin{cases} \{id_x\} & x = y \\ \emptyset & x \neq y \end{cases}\)
--
-- nLab: discrete category.
data Discrete (a :: Type) (b :: Type) where
  Refl :: Discrete a a

-- | Discrete categories are trivially categories.
instance Category Discrete where
  id = Refl
  compose Refl Refl = Refl

--------------------------------------------------------------------------------
-- Maybe as a functor on Hask
--------------------------------------------------------------------------------

-- | Maybe as an endofunctor on Hask (the category of Haskell types and functions).
--
-- nLab: maybe monad.
instance CFunctor Maybe (->) (->) where
  cmap _ Nothing  = Nothing
  cmap f (Just a) = Just (f a)

--------------------------------------------------------------------------------
-- Kleisli category
--------------------------------------------------------------------------------

-- | The Kleisli category of a monad @m@.
--
-- * Objects: Haskell types
-- * Morphisms: @a -> m b@ (Kleisli arrows)
-- * Identity: @return@
-- * Composition: @(g <=< f) x = f x >>= g@
--
-- Stacks Project does not cover Kleisli directly, but see
-- nLab: Kleisli category.
newtype Kleisli (m :: Type -> Type) (a :: Type) (b :: Type)
  = Kleisli { runKleisli :: a -> m b }

-- | The Kleisli category for any 'Monad'.
instance Monad m => Category (Kleisli m) where
  id = Kleisli pure
  compose (Kleisli g) (Kleisli f) = Kleisli (f >=> g)
