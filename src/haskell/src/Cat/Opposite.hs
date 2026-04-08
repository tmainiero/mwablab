-- | Opposite category \(\mathcal{C}^{\mathrm{op}}\).
--
-- Mathematical definition (Stacks Project 001M; nLab: opposite+category):
-- Given a category \(\mathcal{C}\), the opposite category \(\mathcal{C}^{\mathrm{op}}\)
-- has the same objects, with
-- \(\operatorname{Mor}_{\mathcal{C}^{\mathrm{op}}}(x, y) = \operatorname{Mor}_{\mathcal{C}}(y, x)\).
-- Composition is reversed: \(f \circ^{\mathrm{op}} g = g \circ f\).
module Cat.Opposite
  ( -- * Opposite morphisms
    Op(..)
    -- * Data track
  , oppositeData
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

import Cat.Category (Category(..), CategoryData(..))

--------------------------------------------------------------------------------
-- Opposite category
--------------------------------------------------------------------------------

-- | @Op cat a b@ wraps a morphism @cat b a@ -- the reversal of source and target
-- that defines the opposite category.
--
-- \(\operatorname{Hom}_{\mathcal{C}^{\mathrm{op}}}(a, b) = \operatorname{Hom}_{\mathcal{C}}(b, a)\)
--
-- Stacks Project 001M.
newtype Op (cat :: k -> k -> Type) (a :: k) (b :: k) = Op { getOp :: cat b a }

-- | The opposite category is a category. Identity is preserved;
-- composition is reversed.
--
-- @
-- id^{op} = id
-- compose^{op} f g = (compose g f)^{op}
-- @
instance Category cat => Category (Op cat) where
  id = Op id
  compose (Op f) (Op g) = Op (compose g f)

--------------------------------------------------------------------------------
-- Data track
--------------------------------------------------------------------------------

-- | Construct the opposite of a 'CategoryData' record.
-- Reverses the direction of composition.
oppositeData :: CategoryData hom -> CategoryData (Op hom)
oppositeData (CatData ident comp) = CatData
  { catIdentity = Op ident
  , catCompose  = \(Op f) (Op g) -> Op (comp g f)
  }
