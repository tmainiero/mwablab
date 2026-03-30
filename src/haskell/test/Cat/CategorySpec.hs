module Cat.CategorySpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Examples ()

tests :: TestTree
tests = testGroup "Cat.Category"
  [ testGroup "(->) instance"
    [ testProperty "left identity: id `compose` f = f" prop_leftIdentity
    , testProperty "right identity: f `compose` id = f" prop_rightIdentity
    , testProperty "associativity: h `compose` (g `compose` f) = (h `compose` g) `compose` f" prop_assoc
    , testProperty "diagrammatic: f >>> g = compose g f" prop_diagrammatic
    ]
  , testGroup "CategoryData"
    [ testProperty "reified left identity" prop_dataLeftId
    , testProperty "reified right identity" prop_dataRightId
    , testProperty "reified associativity" prop_dataAssoc
    ]
  ]

-- Properties for (->)

prop_leftIdentity :: Fun Int Int -> Int -> Bool
prop_leftIdentity (Fun _ f) x =
  compose id f x == f x

prop_rightIdentity :: Fun Int Int -> Int -> Bool
prop_rightIdentity (Fun _ f) x =
  compose f id x == f x

prop_assoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Bool
prop_assoc (Fun _ h) (Fun _ g) (Fun _ f) x =
  compose h (compose g f) x == compose (compose h g) f x

prop_diagrammatic :: Fun Int Int -> Fun Int Int -> Int -> Bool
prop_diagrammatic (Fun _ f) (Fun _ g) x =
  (f >>> g) x == compose g f x

-- Properties for CategoryData (reified (->))

catData :: CategoryData (->)
catData = categoryDataFromClass

prop_dataLeftId :: Fun Int Int -> Int -> Bool
prop_dataLeftId (Fun _ f) x =
  catCompose catData (catIdentity catData) f x == f x

prop_dataRightId :: Fun Int Int -> Int -> Bool
prop_dataRightId (Fun _ f) x =
  catCompose catData f (catIdentity catData) x == f x

prop_dataAssoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Bool
prop_dataAssoc (Fun _ h) (Fun _ g) (Fun _ f) x =
  catCompose catData h (catCompose catData g f) x
    == catCompose catData (catCompose catData h g) f x
