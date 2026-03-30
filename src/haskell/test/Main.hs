module Main where

import Test.Tasty

import qualified Cat.CategorySpec
import qualified Cat.FunctorSpec
import qualified Cat.NaturalTransformationSpec
import qualified Cat.OppositeSpec

main ∷ IO ()
main = defaultMain tests

tests ∷ TestTree
tests = testGroup "mwablab"
  [ Cat.CategorySpec.tests
  , Cat.FunctorSpec.tests
  , Cat.NaturalTransformationSpec.tests
  , Cat.OppositeSpec.tests
  ]
