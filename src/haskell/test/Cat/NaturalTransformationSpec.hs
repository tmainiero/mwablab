module Cat.NaturalTransformationSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Functor
import Cat.NaturalTransformation
import Cat.Examples ()  -- (→) and Maybe instances

newtype Id a = Id { runId ∷ a }
  deriving stock (Eq, Show)

instance CFunctor Id (→) (→) where
  cmap f (Id a) = Id (f a)

-- | η : Id ⟹ Maybe, defined by η_a = Just ∘ runId
ηJust ∷ NatTrans (→) Id Maybe
ηJust = NatTrans (Just ∘ runId)

-- | α : Maybe ⟹ Maybe, defined by α_a = fmap (+1) (only on Int, but polymorphic wrapper)
-- Instead, a simpler example: ε : Maybe ⟹ Id, with ε_a = Id . fromMaybe (error "...")
-- Better: use identity natural transformation for clean tests.

tests ∷ TestTree
tests = testGroup "Cat.NaturalTransformation"
  [ testGroup "Identity natural transformation"
    [ testProperty "idNat component is id" prop_idNatComponent
    ]
  , testGroup "Naturality of η : Id ⟹ Maybe"
    [ testProperty "naturality: cmap f ∘ η_a = η_b ∘ cmap f" prop_natJust
    ]
  , testGroup "Vertical composition"
    [ testProperty "idNat • idNat = idNat" prop_vertCompIdentity
    , testProperty "(η • idNat) = η" prop_vertCompRightId
    ]
  ]

-- idNat for (→) on Maybe
prop_idNatComponent ∷ Maybe Int → Bool
prop_idNatComponent mx =
  let η = idNat ∷ NatTrans (→) Maybe Maybe
  in  component η mx == mx

-- Naturality square for ηJust: Maybe(f) ∘ η_a = η_b ∘ Id(f)
-- i.e. cmap f ∘ (Just . runId) = (Just . runId) ∘ cmap f
prop_natJust ∷ Fun Int Int → Int → Bool
prop_natJust (Fun _ f) x =
  let lhs = (cmap f ∘ component ηJust) (Id x)   -- Maybe side
      rhs = (component ηJust ∘ cmap f) (Id x)     -- Id side
  in  lhs == rhs

-- Vertical composition: idNat • idNat = idNat
prop_vertCompIdentity ∷ Maybe Int → Bool
prop_vertCompIdentity mx =
  let η = vertComp (idNat ∷ NatTrans (→) Maybe Maybe)
                    (idNat ∷ NatTrans (→) Maybe Maybe)
  in  component η mx == mx

-- (ηJust • idNat) = ηJust
prop_vertCompRightId ∷ Int → Bool
prop_vertCompRightId x =
  let composed = vertComp ηJust (idNat ∷ NatTrans (→) Id Id)
  in  component composed (Id x) == component ηJust (Id x)
