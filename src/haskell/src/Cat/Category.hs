-- | Category -- the fundamental notion.
--
-- Mathematical definition (Stacks Project 0014):
-- A category \(\mathcal{C}\) consists of a set of objects \(\operatorname{Ob}(\mathcal{C})\),
-- for each pair \(x, y \in \operatorname{Ob}(\mathcal{C})\) a set of morphisms
-- \(\operatorname{Mor}_{\mathcal{C}}(x, y)\), for each object an identity morphism,
-- and composition satisfying associativity and unit laws.
--
-- This module provides two encodings:
--
-- 1. __Typeclass track__: locally small categories where objects are Haskell types
--    and hom-sets are Haskell types. Implicitly Set-enriched.
-- 2. __Data track__: categories reified as records, suitable for parameterization
--    and V-enrichment (Phase 1b).
module Cat.Category
  ( -- * Typeclass track
    Category(..)
  , (>>>)
    -- * Data track
  , CategoryData(..)
  , categoryDataFromClass
  ) where

import Prelude hiding (id, (.))
import Data.Kind (Type)

--------------------------------------------------------------------------------
-- Typeclass track
--------------------------------------------------------------------------------

-- | A category where objects are Haskell types of kind @k@ and morphisms
-- are values of type @cat a b@.
--
-- Laws:
--
-- [Left identity]  @'id' \`compose\` f = f@
-- [Right identity] @f \`compose\` 'id' = f@
-- [Associativity]  @h \`compose\` (g \`compose\` f) = (h \`compose\` g) \`compose\` f@
--
-- Stacks Project 0014.
class Category (cat :: k -> k -> Type) where
  -- | Identity morphism. For each object @a@, there is a morphism
  -- @id : a -> a@ such that @id \`compose\` f = f@ and @g \`compose\` id = g@.
  id :: cat a a

  -- | Composition of morphisms. Given @g : b -> c@ and @f : a -> b@,
  -- produces @g \`compose\` f : a -> c@.
  -- Conventional (right-to-left) order: @compose g f = g . f@.
  compose :: cat b c -> cat a b -> cat a c

-- | Diagrammatic (left-to-right) composition.
-- @f >>> g = compose g f@.
--
-- Convenient when reading morphism chains in diagram order:
-- @f >>> g >>> h@ means "first f, then g, then h".
(>>>) :: Category cat => cat a b -> cat b c -> cat a c
f >>> g = compose g f
{-# INLINE (>>>) #-}

infixl 1 >>>

--------------------------------------------------------------------------------
-- Data track
--------------------------------------------------------------------------------

-- | A category reified as a record. The morphism type @hom@ is a binary type
-- constructor indexed by source and target types (objects-as-types).
--
-- This is the typeclass 'Category' presented as data -- identical laws,
-- but passable as a value. Will serve as the substrate for V-enrichment
-- in Phase 1b.
--
-- Stacks Project 0014.
data CategoryData (hom :: Type -> Type -> Type) = CatData
  { catIdentity :: forall a. hom a a
    -- ^ Identity morphism for each object.
  , catCompose  :: forall a b c. hom b c -> hom a b -> hom a c
    -- ^ Composition of morphisms.
  }

-- | Reify a 'Category' typeclass instance into a 'CategoryData' record.
categoryDataFromClass :: Category cat => CategoryData cat
categoryDataFromClass = CatData id compose
