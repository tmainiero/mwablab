module Cat.BifunctorSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Bifunctor
import Cat.Examples ()  -- (->) instance

tests :: TestTree
tests = testGroup "Cat.Bifunctor"
  [ testGroup "pair bifunctor (,)"
    [ testProperty "identity: bimap id id = id" prop_pairIdentity
    , testProperty "composition: bimap (f2.f1) (g2.g1) = bimap f2 g2 . bimap f1 g1"
        prop_pairComposition
    , testProperty "firstData f (x,y) = (f x, y)" prop_pairFirst
    , testProperty "secondData g (x,y) = (x, g y)" prop_pairSecond
    ]
  , testGroup "either bifunctor Either"
    [ testProperty "identity: bimap id id = id (Left)" prop_eitherIdentityLeft
    , testProperty "identity: bimap id id = id (Right)" prop_eitherIdentityRight
    , testProperty "composition (Left)" prop_eitherCompLeft
    , testProperty "composition (Right)" prop_eitherCompRight
    , testProperty "firstData on Left" prop_eitherFirstLeft
    , testProperty "secondData on Right" prop_eitherSecondRight
    ]
  ]

--------------------------------------------------------------------------------
-- Pair bifunctor: (,) as a bifunctor Set x Set -> Set
--------------------------------------------------------------------------------

-- | The cartesian product bifunctor on Set (represented via ->).
--
-- bimap f g (a, b) = (f a, g b)
--
-- nLab: bifunctor.
pairBifunctor :: BifunctorData (->) (->) (->) (,)
pairBifunctor = BifunctorData { bimap = \f g (a, b) -> (f a, g b) }

prop_pairIdentity :: (Int, Int) -> Bool
prop_pairIdentity xy =
  bimap pairBifunctor id id xy == (id :: (Int, Int) -> (Int, Int)) xy

prop_pairComposition :: Fun Int Int -> Fun Int Int
                     -> Fun Int Int -> Fun Int Int
                     -> (Int, Int) -> Bool
prop_pairComposition (Fun _ f2) (Fun _ f1) (Fun _ g2) (Fun _ g1) xy =
  bimap pairBifunctor (compose f2 f1) (compose g2 g1) xy
    == compose (bimap pairBifunctor f2 g2) (bimap pairBifunctor f1 g1) xy

prop_pairFirst :: Fun Int Int -> (Int, Int) -> Bool
prop_pairFirst (Fun _ f) (x, y) =
  firstData pairBifunctor f (x, y) == (f x, y)

prop_pairSecond :: Fun Int Int -> (Int, Int) -> Bool
prop_pairSecond (Fun _ g) (x, y) =
  secondData pairBifunctor g (x, y) == (x, g y)

--------------------------------------------------------------------------------
-- Either bifunctor: Either as a bifunctor Set x Set -> Set
--------------------------------------------------------------------------------

-- | The coproduct bifunctor on Set.
--
-- bimap f g (Left a)  = Left (f a)
-- bimap f g (Right b) = Right (g b)
--
-- nLab: bifunctor.
eitherBifunctor :: BifunctorData (->) (->) (->) Either
eitherBifunctor = BifunctorData
  { bimap = \f g e -> case e of
      Left a  -> Left (f a)
      Right b -> Right (g b)
  }

prop_eitherIdentityLeft :: Int -> Bool
prop_eitherIdentityLeft x =
  bimap eitherBifunctor id id (Left x :: Either Int Int) == Left x

prop_eitherIdentityRight :: Int -> Bool
prop_eitherIdentityRight y =
  bimap eitherBifunctor id id (Right y :: Either Int Int) == Right y

prop_eitherCompLeft :: Fun Int Int -> Fun Int Int
                    -> Fun Int Int -> Fun Int Int
                    -> Int -> Bool
prop_eitherCompLeft (Fun _ f2) (Fun _ f1) (Fun _ g2) (Fun _ g1) x =
  let v = Left x :: Either Int Int
  in bimap eitherBifunctor (compose f2 f1) (compose g2 g1) v
       == compose (bimap eitherBifunctor f2 g2) (bimap eitherBifunctor f1 g1) v

prop_eitherCompRight :: Fun Int Int -> Fun Int Int
                     -> Fun Int Int -> Fun Int Int
                     -> Int -> Bool
prop_eitherCompRight (Fun _ f2) (Fun _ f1) (Fun _ g2) (Fun _ g1) y =
  let v = Right y :: Either Int Int
  in bimap eitherBifunctor (compose f2 f1) (compose g2 g1) v
       == compose (bimap eitherBifunctor f2 g2) (bimap eitherBifunctor f1 g1) v

prop_eitherFirstLeft :: Fun Int Int -> Int -> Bool
prop_eitherFirstLeft (Fun _ f) x =
  firstData eitherBifunctor f (Left x :: Either Int Int) == Left (f x)

prop_eitherSecondRight :: Fun Int Int -> Int -> Bool
prop_eitherSecondRight (Fun _ g) y =
  secondData eitherBifunctor g (Right y :: Either Int Int) == Right (g y)
