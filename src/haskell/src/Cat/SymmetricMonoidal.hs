-- | Symmetric monoidal category -- a braided monoidal category whose braiding
-- is self-inverse.
--
-- Mathematical definition (nLab: symmetric+monoidal+category):
-- A symmetric monoidal category is a braided monoidal category
-- \((\mathcal{C}, \otimes, I, \alpha, \lambda, \rho, \sigma)\) in which
-- the braiding satisfies the additional symmetry condition:
--
-- \[\sigma_{B,A} \circ \sigma_{A,B} = \mathrm{id}_{A \otimes B}\]
--
-- Equivalently, \(\sigma^{-1}_{A,B} = \sigma_{B,A}\). This means that
-- the two hexagon axioms collapse into one (the second follows from
-- the first plus symmetry).
--
-- Laws (documented here, tested via QuickCheck in "Cat.SymmetricMonoidalSpec"):
--
-- [Symmetry]
--   @compose (braidingFwd \@b \@a) (braidingFwd \@a \@b) = id@
--
-- All braided monoidal category laws also apply (see "Cat.BraidedMonoidal").
--
-- nLab: symmetric+monoidal+category.
module Cat.SymmetricMonoidal
  ( SymmetricData(..)
    -- * Projections (forgetful functors)
  , symmetricMonoidal
  , symmetricCat
  , symmetricTensor
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (CategoryData)
import Cat.Bifunctor (BifunctorData)
import Cat.BraidedMonoidal (BraidedData(..))
import Cat.Monoidal (MonoidalData(..))

-- | A symmetric monoidal category reified as a record.
--
-- The record wraps a 'BraidedData' and serves as a marker that the
-- additional symmetry law holds: the braiding is its own inverse,
-- i.e. \(\sigma_{B,A} \circ \sigma_{A,B} = \mathrm{id}\).
--
-- The type parameters are:
--
-- * @hom@ -- the morphism type of the underlying category (kind @Type -> Type -> Type@)
-- * @tensor@ -- the tensor product on objects (kind @Type -> Type -> Type@)
-- * @unit@ -- the monoidal unit (kind @Type@)
--
-- nLab: symmetric+monoidal+category.
data SymmetricData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = SymmetricData
  { symmetricBraided :: BraidedData hom tensor unit
    -- ^ The underlying braided monoidal category, whose braiding
    -- additionally satisfies \(\sigma_{B,A} \circ \sigma_{A,B} = \mathrm{id}\).
  }

-- | Extract the underlying monoidal structure.
-- Projection corresponding to the forgetful functor SMon -> Mon.
--
-- nLab: symmetric+monoidal+category.
symmetricMonoidal :: SymmetricData hom t u -> MonoidalData hom t u
symmetricMonoidal sd = braidedMonoidal (symmetricBraided sd)

-- | Extract the underlying category.
-- Projection corresponding to the forgetful functor SMon -> Cat.
--
-- nLab: symmetric+monoidal+category.
symmetricCat :: SymmetricData hom t u -> CategoryData hom
symmetricCat sd = monCat (braidedMonoidal (symmetricBraided sd))

-- | Extract the tensor bifunctor.
-- Projection corresponding to the forgetful functor SMon -> Cat
-- composed with the tensor extraction.
--
-- nLab: symmetric+monoidal+category.
symmetricTensor :: SymmetricData hom t u -> BifunctorData hom hom hom t
symmetricTensor sd = monTensor (braidedMonoidal (symmetricBraided sd))
