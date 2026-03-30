module Cat.OppositeSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Opposite
import Cat.Examples ()  -- (->) instance

tests :: TestTree
tests = testGroup "Cat.Opposite"
  [ testGroup "Op (->) instance"
    [ testProperty "left identity: id `compose` f = f" prop_opLeftId
    , testProperty "right identity: f `compose` id = f" prop_opRightId
    , testProperty "associativity" prop_opAssoc
    , testProperty "Op reverses direction" prop_opReverse
    ]
  , testGroup "Double opposite"
    [ testProperty "Op (Op f) round-trips" prop_doubleOp
    ]
  , testGroup "oppositeData"
    [ testProperty "data track left identity" prop_dataOpLeftId
    , testProperty "data track associativity" prop_dataOpAssoc
    ]
  ]

-- Op (->) properties

prop_opLeftId :: Fun Int Int -> Int -> Bool
prop_opLeftId (Fun _ f) x =
  getOp (compose id (Op f)) x == f x

prop_opRightId :: Fun Int Int -> Int -> Bool
prop_opRightId (Fun _ f) x =
  getOp (compose (Op f) id) x == f x

prop_opAssoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Bool
prop_opAssoc (Fun _ h) (Fun _ g) (Fun _ f) x =
  getOp (compose (Op h) (compose (Op g) (Op f))) x
    == getOp (compose (compose (Op h) (Op g)) (Op f)) x

-- Op reverses: composing Op f and Op g gives Op (compose f g), not Op (compose g f)
prop_opReverse :: Fun Int Int -> Fun Int Int -> Int -> Bool
prop_opReverse (Fun _ f) (Fun _ g) x =
  getOp (compose (Op f) (Op g)) x == compose g f x

-- Double opposite: Op (Op cat) ~= cat
prop_doubleOp :: Fun Int Int -> Int -> Bool
prop_doubleOp (Fun _ f) x =
  let wrapped   = Op (Op f) :: Op (Op (->)) Int Int
      unwrapped = getOp (getOp wrapped)
  in  unwrapped x == f x

-- oppositeData properties

opData :: CategoryData (Op (->))
opData = oppositeData (categoryDataFromClass :: CategoryData (->))

prop_dataOpLeftId :: Fun Int Int -> Int -> Bool
prop_dataOpLeftId (Fun _ f) x =
  getOp (catCompose opData (catIdentity opData) (Op f)) x == f x

prop_dataOpAssoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Bool
prop_dataOpAssoc (Fun _ h) (Fun _ g) (Fun _ f) x =
  getOp (catCompose opData (Op h) (catCompose opData (Op g) (Op f))) x
    == getOp (catCompose opData (catCompose opData (Op h) (Op g)) (Op f)) x
