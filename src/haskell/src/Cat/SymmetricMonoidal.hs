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
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.BraidedMonoidal (BraidedData(..))

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
