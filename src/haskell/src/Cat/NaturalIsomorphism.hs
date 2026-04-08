-- | Natural isomorphism -- an invertible natural transformation.
--
-- Mathematical definition:
-- A natural isomorphism \(\alpha : F \xRightarrow{\sim} G\) between functors
-- \(F, G : \mathcal{C} \to \mathcal{D}\) is a natural transformation whose
-- components are all isomorphisms. Equivalently, it is a pair of natural
-- transformations \(\alpha : F \Rightarrow G\) and \(\alpha^{-1} : G \Rightarrow F\)
-- such that \(\alpha^{-1} \circ \alpha = \mathrm{id}_F\) and
-- \(\alpha \circ \alpha^{-1} = \mathrm{id}_G\) (vertical composition).
--
-- Natural isomorphisms are the isomorphisms in the functor category
-- \([\mathcal{C}, \mathcal{D}]\).
--
-- Reference: nLab, natural+isomorphism.
module Cat.NaturalIsomorphism
  ( -- * Natural isomorphisms
    NatIso(..)
    -- * Construction
  , idNatIso
  , composeNatIso
  , invertNatIso
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..))
import Cat.NaturalTransformation (NatTrans(..), vertComp)

--------------------------------------------------------------------------------
-- Natural isomorphisms
--------------------------------------------------------------------------------

-- | A natural isomorphism \(\alpha : F \xRightarrow{\sim} G\) between functors
-- @f@ and @g@ landing in a category with morphisms @cat2@.
--
-- Structurally, a natural isomorphism is a pair of natural transformations
-- (forward and backward) that are mutual inverses. Instances must satisfy:
--
-- [Left inverse]  @vertComp (niBackward iso) (niForward iso) = idNat@
-- [Right inverse] @vertComp (niForward iso) (niBackward iso) = idNat@
-- [Naturality]    Both 'niForward' and 'niBackward' are natural transformations
--                 (see 'Cat.NaturalTransformation.NatTrans').
--
-- Reference: nLab, natural+isomorphism.
data NatIso (cat2 :: k2 -> k2 -> Type) (f :: k1 -> k2) (g :: k1 -> k2) = NatIso
  { niForward  :: NatTrans cat2 f g
    -- ^ The forward natural transformation \(\alpha : F \Rightarrow G\).
  , niBackward :: NatTrans cat2 g f
    -- ^ The backward natural transformation \(\alpha^{-1} : G \Rightarrow F\).
  }

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

-- | The identity natural isomorphism \(\mathrm{id}_F : F \xRightarrow{\sim} F\).
-- Both forward and backward components are identity morphisms.
--
-- Reference: nLab, natural+isomorphism.
idNatIso :: Category cat2 => NatIso cat2 f f
idNatIso = NatIso (NatTrans id) (NatTrans id)

-- | Composition of natural isomorphisms.
-- Given \(\alpha : F \xRightarrow{\sim} G\) and \(\beta : G \xRightarrow{\sim} H\),
-- the composite \(\beta \circ \alpha : F \xRightarrow{\sim} H\) has
-- forward components \(\beta_a \circ \alpha_a\)
-- and backward components \(\alpha^{-1}_a \circ \beta^{-1}_a\).
--
-- Note: argument order follows vertical composition convention (diagrammatic
-- order reversed): @composeNatIso beta alpha@ means \(\beta\) after \(\alpha\).
--
-- Reference: nLab, natural+isomorphism.
composeNatIso :: Category cat2
              => NatIso cat2 g h -> NatIso cat2 f g -> NatIso cat2 f h
composeNatIso beta alpha = NatIso
  { niForward  = vertComp (niForward beta) (niForward alpha)
  , niBackward = vertComp (niBackward alpha) (niBackward beta)
  }

-- | Inverse of a natural isomorphism.
-- Given \(\alpha : F \xRightarrow{\sim} G\), returns
-- \(\alpha^{-1} : G \xRightarrow{\sim} F\) by swapping forward and backward.
--
-- Reference: nLab, natural+isomorphism.
invertNatIso :: NatIso cat2 f g -> NatIso cat2 g f
invertNatIso iso = NatIso
  { niForward  = niBackward iso
  , niBackward = niForward iso
  }
