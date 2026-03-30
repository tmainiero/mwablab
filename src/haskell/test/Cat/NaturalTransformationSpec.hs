module Cat.NaturalTransformationSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Functor
import Cat.NaturalTransformation
import Cat.Examples ()  -- (->) and Maybe instances

newtype Id a = Id { runId :: a }
  deriving stock (Eq, Show)

instance CFunctor Id (->) (->) where
  cmap f (Id a) = Id (f a)

-- | eta : Id ==> Maybe, defined by eta_a = Just . runId
etaJust :: NatTrans (->) Id Maybe
etaJust = NatTrans (compose Just runId)

-- | alpha : Maybe ==> Maybe, defined by alpha_a = fmap (+1) (only on Int, but polymorphic wrapper)
-- Instead, a simpler example: epsilon : Maybe ==> Id, with epsilon_a = Id . fromMaybe (error "...")
-- Better: use identity natural transformation for clean tests.

tests :: TestTree
tests = testGroup "Cat.NaturalTransformation"
  [ testGroup "Identity natural transformation"
    [ testProperty "idNat component is id" prop_idNatComponent
    ]
  , testGroup "Naturality of eta : Id ==> Maybe"
    [ testProperty "naturality: cmap f . eta_a = eta_b . cmap f" prop_natJust
    ]
  , testGroup "Vertical composition"
    [ testProperty "vertComp idNat idNat = idNat" prop_vertCompIdentity
    , testProperty "(vertComp eta idNat) = eta" prop_vertCompRightId
    ]
  ]

-- idNat for (->) on Maybe
prop_idNatComponent :: Maybe Int -> Bool
prop_idNatComponent mx =
  let eta = idNat :: NatTrans (->) Maybe Maybe
  in  component eta mx == mx

-- Naturality square for etaJust: Maybe(f) . eta_a = eta_b . Id(f)
-- i.e. cmap f . (Just . runId) = (Just . runId) . cmap f
prop_natJust :: Fun Int Int -> Int -> Bool
prop_natJust (Fun _ f) x =
  let lhs = compose (cmap f) (component etaJust) (Id x)   -- Maybe side
      rhs = compose (component etaJust) (cmap f) (Id x)    -- Id side
  in  lhs == rhs

-- Vertical composition: vertComp idNat idNat = idNat
prop_vertCompIdentity :: Maybe Int -> Bool
prop_vertCompIdentity mx =
  let eta = vertComp (idNat :: NatTrans (->) Maybe Maybe)
                     (idNat :: NatTrans (->) Maybe Maybe)
  in  component eta mx == mx

-- (vertComp etaJust idNat) = etaJust
prop_vertCompRightId :: Int -> Bool
prop_vertCompRightId x =
  let composed = vertComp etaJust (idNat :: NatTrans (->) Id Id)
  in  component composed (Id x) == component etaJust (Id x)
