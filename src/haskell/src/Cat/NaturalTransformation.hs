-- | Natural transformation -- morphism between functors.
--
-- Mathematical definition (Stacks Project 0015):
-- Given functors \(F, G : \mathcal{C} \to \mathcal{D}\), a natural transformation
-- \(\eta : F \Rightarrow G\) is a family of morphisms
-- \(\eta_a : F(a) \to G(a)\) for each object \(a\) in \(\mathcal{C}\),
-- such that for every morphism \(f : a \to b\) in \(\mathcal{C}\),
-- the naturality square commutes:
-- \(G(f) \circ \eta_a = \eta_b \circ F(f)\).
module Cat.NaturalTransformation
  ( -- * Natural transformations
    NatTrans(..)
    -- * Vertical composition
  , idNat
  , vertComp
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..))

--------------------------------------------------------------------------------
-- Natural transformations
--------------------------------------------------------------------------------

-- | A natural transformation \(\eta : F \Rightarrow G\) between functors
-- @f@ and @g@ landing in a category with morphisms @cat2@.
--
-- The naturality condition is not enforced by the type system but is a
-- law that instances must satisfy:
--
-- @G(h) \`compose\` component eta = component eta \`compose\` F(h)@
--
-- for all morphisms @h@ in the source category.
--
-- Stacks Project 0015, Definition 3.4.
newtype NatTrans (cat2 :: k2 -> k2 -> Type) (f :: k1 -> k2) (g :: k1 -> k2) = NatTrans
  { component :: forall (a :: k1). cat2 (f a) (g a)
    -- ^ The component at object @a@: a morphism \(\eta_a : F(a) \to G(a)\).
  }

--------------------------------------------------------------------------------
-- Vertical composition
--------------------------------------------------------------------------------

-- | The identity natural transformation \(\mathrm{id}_F : F \Rightarrow F\).
-- Each component is the identity morphism: \((\mathrm{id}_F)_a = \mathrm{id}_{F(a)}\).
--
-- nLab: identity natural transformation.
idNat :: Category cat2 => NatTrans cat2 f f
idNat = NatTrans id

-- | Vertical composition of natural transformations.
-- Given \(\alpha : F \Rightarrow G\) and \(\beta : G \Rightarrow H\),
-- \((\beta \bullet \alpha)_a = \beta_a \circ \alpha_a\).
--
-- Stacks Project 0016.
vertComp :: Category cat2 => NatTrans cat2 g h -> NatTrans cat2 f g -> NatTrans cat2 f h
vertComp (NatTrans beta) (NatTrans alpha) = NatTrans (compose beta alpha)
