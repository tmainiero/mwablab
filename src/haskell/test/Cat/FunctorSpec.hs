module Cat.FunctorSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Functor
import Cat.Examples ()  -- (->) instance

-- | A simple endofunctor on Hask for testing: the identity wrapper.
newtype Id a = Id { runId :: a }
  deriving stock (Eq, Show)

-- | The identity functor: maps every morphism to itself (wrapped).
instance CFunctor Id (->) (->) where
  cmap f (Id a) = Id (f a)

tests :: TestTree
tests = testGroup "Cat.Functor"
  [ testGroup "Id functor"
    [ testProperty "identity: cmap id = id" prop_idFunctorIdentity
    , testProperty "composition: cmap (g `compose` f) = cmap g `compose` cmap f" prop_idFunctorComp
    ]
  , testGroup "Maybe functor"
    [ testProperty "identity: cmap id = id" prop_maybeFunctorIdentity
    , testProperty "composition: cmap (g `compose` f) = cmap g `compose` cmap f" prop_maybeFunctorComp
    ]
  , testGroup "FunctorData"
    [ testProperty "identity law via data" prop_dataFunctorIdentity
    , testProperty "composition law via data" prop_dataFunctorComp
    ]
  ]

-- Id functor properties

prop_idFunctorIdentity :: Int -> Bool
prop_idFunctorIdentity x =
  cmap id (Id x) == (id :: Id Int -> Id Int) (Id x)

prop_idFunctorComp :: Fun Int Int -> Fun Int Int -> Int -> Bool
prop_idFunctorComp (Fun _ g) (Fun _ f) x =
  cmap (compose g f) (Id x) == compose (cmap g) (cmap f) (Id x)

-- Maybe functor properties

prop_maybeFunctorIdentity :: Maybe Int -> Bool
prop_maybeFunctorIdentity mx =
  cmap id mx == (id :: Maybe Int -> Maybe Int) mx

prop_maybeFunctorComp :: Fun Int Int -> Fun Int Int -> Maybe Int -> Bool
prop_maybeFunctorComp (Fun _ g) (Fun _ f) mx =
  cmap (compose g f) mx == compose (cmap g) (cmap f) mx

-- FunctorData properties (using Id)

idFunctorData :: FunctorData (->) (->) Id
idFunctorData = FunctorData (\f (Id a) -> Id (f a))

prop_dataFunctorIdentity :: Int -> Bool
prop_dataFunctorIdentity x =
  fmapData idFunctorData id (Id x) == (id :: Id Int -> Id Int) (Id x)

prop_dataFunctorComp :: Fun Int Int -> Fun Int Int -> Int -> Bool
prop_dataFunctorComp (Fun _ g) (Fun _ f) x =
  fmapData idFunctorData (compose g f) (Id x)
    == compose (fmapData idFunctorData g) (fmapData idFunctorData f) (Id x)
