-- | Monoidal category -- a category equipped with a tensor product and unit.
--
-- Mathematical definition (nLab: monoidal+category):
-- A monoidal category \((\mathcal{C}, \otimes, I, \alpha, \lambda, \rho)\)
-- consists of:
--
-- * A category \(\mathcal{C}\)
-- * A bifunctor \(\otimes : \mathcal{C} \times \mathcal{C} \to \mathcal{C}\) (the tensor product)
-- * An object \(I \in \mathcal{C}\) (the monoidal unit)
-- * A natural isomorphism \(\alpha_{A,B,C} : (A \otimes B) \otimes C \xrightarrow{\sim} A \otimes (B \otimes C)\) (the associator)
-- * A natural isomorphism \(\lambda_A : I \otimes A \xrightarrow{\sim} A\) (the left unitor)
-- * A natural isomorphism \(\rho_A : A \otimes I \xrightarrow{\sim} A\) (the right unitor)
--
-- subject to the pentagon and triangle coherence axioms.
--
-- __Pentagon axiom__: For all objects \(A, B, C, D\), the following diagram commutes:
--
-- @
--                          alpha_{A,B,C} * id_D
--   ((A*B)*C)*D  -------------------------------->  (A*(B*C))*D
--        |                                               |
--        | alpha_{A*B,C,D}                               | alpha_{A,B*C,D}
--        v                                               v
--   (A*B)*(C*D)                                    A*((B*C)*D)
--        |                                               |
--        | alpha_{A,B,C*D}                               | id_A * alpha_{B,C,D}
--        v                                               v
--   A*(B*(C*D))  <================================  A*(B*(C*D))
-- @
--
-- That is:
-- @(id_A `bimap` alpha_{B,C,D}) . alpha_{A,B*C,D} . (alpha_{A,B,C} `bimap` id_D)@
-- @= alpha_{A,B,C*D} . alpha_{A*B,C,D}@
--
-- __Triangle axiom__: For all objects \(A, B\), the following diagram commutes:
--
-- @
--   (A*I)*B ---alpha_{A,I,B}---> A*(I*B)
--       \                         /
--        \                       /
--    rho_A * id_B         id_A * lambda_B
--          \                   /
--           v                 v
--               A * B
-- @
--
-- That is:
-- @(id_A `bimap` lambda_B) . alpha_{A,I,B} = rho_A `bimap` id_B@
--
-- This module provides the data track encoding only (records, not typeclasses).
-- The associator and unitors are stored as rank-2 component families rather than
-- as 'NatIso' values, since the associator is a natural isomorphism between
-- /trifunctors/ \(\mathcal{C}^3 \to \mathcal{C}\), which does not fit the
-- shape of 'NatIso' (parameterized over unary type constructors).
--
-- Laws (documented here, tested via QuickCheck in "Cat.MonoidalSpec"):
--
-- [Associator roundtrip]
--   @compose monAssocBwd monAssocFwd = id@
--   @compose monAssocFwd monAssocBwd = id@
--
-- [Left unitor roundtrip]
--   @compose monLeftUnitorBwd monLeftUnitorFwd = id@
--   @compose monLeftUnitorFwd monLeftUnitorBwd = id@
--
-- [Right unitor roundtrip]
--   @compose monRightUnitorBwd monRightUnitorFwd = id@
--   @compose monRightUnitorFwd monRightUnitorBwd = id@
--
-- [Associator naturality]
--   For all @f@, @g@, @h@:
--   @monAssocFwd . bimap (bimap f g) h = bimap f (bimap g h) . monAssocFwd@
--
-- [Pentagon]
--   @compose (bimap id monAssocFwd) (compose monAssocFwd (bimap monAssocFwd id))@
--   @= compose monAssocFwd monAssocFwd@
--
-- [Triangle]
--   @compose (bimap id monLeftUnitorFwd) monAssocFwd = bimap monRightUnitorFwd id@
--
-- nLab: monoidal+category.
module Cat.Monoidal
  ( MonoidalData(..)
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (CategoryData(..))
import Cat.Bifunctor (BifunctorData(..))

-- | A monoidal category reified as a record.
--
-- The type parameters are:
--
-- * @hom@ -- the morphism type of the underlying category (kind @Type -> Type -> Type@)
-- * @tensor@ -- the tensor product on objects (kind @Type -> Type -> Type@)
-- * @unit@ -- the monoidal unit (kind @Type@)
--
-- The coherence isomorphisms (associator, left unitor, right unitor) are stored
-- as forward and backward component families. This is the correct representation
-- for the data track: the associator is a natural isomorphism between trifunctors,
-- and the unitors are natural isomorphisms between endofunctors, but we store their
-- components directly rather than wrapping them in 'NatIso'.
--
-- nLab: monoidal+category.
data MonoidalData
  (hom :: Type -> Type -> Type)
  (tensor :: Type -> Type -> Type)
  (unit :: Type)
  = MonoidalData
  { monCat :: CategoryData hom
    -- ^ The underlying category.
  , monTensor :: BifunctorData hom hom hom tensor
    -- ^ The tensor product bifunctor \(\otimes : \mathcal{C} \times \mathcal{C} \to \mathcal{C}\).
  , monAssocFwd :: forall a b c. hom (tensor (tensor a b) c) (tensor a (tensor b c))
    -- ^ The forward component of the associator:
    -- \(\alpha_{A,B,C} : (A \otimes B) \otimes C \to A \otimes (B \otimes C)\).
  , monAssocBwd :: forall a b c. hom (tensor a (tensor b c)) (tensor (tensor a b) c)
    -- ^ The backward component of the associator:
    -- \(\alpha^{-1}_{A,B,C} : A \otimes (B \otimes C) \to (A \otimes B) \otimes C\).
  , monLeftUnitorFwd :: forall a. hom (tensor unit a) a
    -- ^ The forward component of the left unitor:
    -- \(\lambda_A : I \otimes A \to A\).
  , monLeftUnitorBwd :: forall a. hom a (tensor unit a)
    -- ^ The backward component of the left unitor:
    -- \(\lambda^{-1}_A : A \to I \otimes A\).
  , monRightUnitorFwd :: forall a. hom (tensor a unit) a
    -- ^ The forward component of the right unitor:
    -- \(\rho_A : A \otimes I \to A\).
  , monRightUnitorBwd :: forall a. hom a (tensor a unit)
    -- ^ The backward component of the right unitor:
    -- \(\rho^{-1}_A : A \to A \otimes I\).
  }
