-- | Braided monoidal category -- a monoidal category equipped with a braiding.
--
-- Mathematical definition (nLab: braided+monoidal+category):
-- A braided monoidal category \((\mathcal{C}, \otimes, I, \alpha, \lambda, \rho, \sigma)\)
-- is a monoidal category together with a natural isomorphism
--
-- \[\sigma_{A,B} : A \otimes B \xrightarrow{\sim} B \otimes A\]
--
-- called the __braiding__, subject to the two hexagon axioms.
--
-- __Hexagon axiom 1__: For all objects \(A, B, C\), the following diagram commutes:
--
-- @
--                             sigma_{A,B*C}
--       (A*B)*C -----alpha-----> A*(B*C) -----------> (B*C)*A
--         |                                               |
--         | sigma_{A,B} * id_C                            | alpha_{B,C,A}
--         v                                               v
--       (B*A)*C -----alpha-----> B*(A*C) -----------> B*(C*A)
--                                         id_B * sigma_{A,C}
-- @
--
-- That is:
-- @alpha_{B,C,A} . sigma_{A,B*C} . alpha_{A,B,C}@
-- @= (id_B `bimap` sigma_{A,C}) . alpha_{B,A,C} . (sigma_{A,B} `bimap` id_C)@
--
-- __Hexagon axiom 2__: For all objects \(A, B, C\), the following diagram commutes:
--
-- @
--                           sigma_{A*B,C}
--   A*(B*C) ---alpha_inv---> (A*B)*C -----------> C*(A*B)
--       |                                             |
--       | id_A * sigma_{B,C}                          | alpha_inv_{C,A,B}
--       v                                             v
--   A*(C*B) ---alpha_inv---> (A*C)*B -----------> (C*A)*B
--                                      sigma_{A,C} * id_B
-- @
--
-- That is:
-- @alpha_inv_{C,A,B} . sigma_{A*B,C} . alpha_inv_{A,B,C}@
-- @= (sigma_{A,C} `bimap` id_B) . alpha_inv_{A,C,B} . (id_A `bimap` sigma_{B,C})@
--
-- Laws (documented here, tested via QuickCheck in "Cat.BraidedMonoidalSpec"):
--
-- [Braiding roundtrip]
--   @compose braidingBwd braidingFwd = id@
--   @compose braidingFwd braidingBwd = id@
--
-- [Braiding naturality]
--   For all @f@, @g@:
--   @braidingFwd . bimap f g = bimap g f . braidingFwd@
--
-- [Hexagon 1]
--   @alpha_{B,C,A} . sigma_{A,B*C} . alpha_{A,B,C}@
--   @= (id_B `bimap` sigma_{A,C}) . alpha_{B,A,C} . (sigma_{A,B} `bimap` id_C)@
--
-- [Hexagon 2]
--   @alpha_inv_{C,A,B} . sigma_{A*B,C} . alpha_inv_{A,B,C}@
--   @= (sigma_{A,C} `bimap` id_B) . alpha_inv_{A,C,B} . (id_A `bimap` sigma_{B,C})@
--
-- nLab: braided+monoidal+category.
module Cat.BraidedMonoidal
  ( BraidedData(..)
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Monoidal (MonoidalData(..))

-- | A braided monoidal category reified as a record.
--
-- The type parameters are:
--
-- * @hom@ -- the morphism type of the underlying category (kind @Type -> Type -> Type@)
-- * @tensor@ -- the tensor product on objects (kind @Type -> Type -> Type@)
-- * @unit@ -- the monoidal unit (kind @Type@)
--
-- The braiding is stored as forward and backward component families,
-- analogous to the associator and unitors in 'MonoidalData'.
--
-- nLab: braided+monoidal+category.
data BraidedData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = BraidedData
  { braidedMonoidal :: MonoidalData hom tensor unit
    -- ^ The underlying monoidal category.
  , braidingFwd :: forall a b. hom (tensor a b) (tensor b a)
    -- ^ The braiding: \(\sigma_{A,B} : A \otimes B \to B \otimes A\).
  , braidingBwd :: forall a b. hom (tensor b a) (tensor a b)
    -- ^ The inverse braiding: \(\sigma^{-1}_{A,B} : B \otimes A \to A \otimes B\).
  }
