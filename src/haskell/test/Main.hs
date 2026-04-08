module Main where

import Test.Tasty

import qualified Cat.BifunctorSpec
import qualified Cat.BraidedMonoidalSpec
import qualified Cat.CategorySpec
import qualified Cat.Examples.MonoidalSpec
import qualified Cat.FunctorSpec
import qualified Cat.MonoidalSpec
import qualified Cat.NaturalIsomorphismSpec
import qualified Cat.NaturalTransformationSpec
import qualified Cat.OppositeSpec
import qualified Cat.ProductSpec
import qualified Cat.SymmetricMonoidalSpec

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "mwablab"
  [ Cat.BifunctorSpec.tests
  , Cat.BraidedMonoidalSpec.tests
  , Cat.CategorySpec.tests
  , Cat.Examples.MonoidalSpec.tests
  , Cat.FunctorSpec.tests
  , Cat.MonoidalSpec.tests
  , Cat.NaturalIsomorphismSpec.tests
  , Cat.NaturalTransformationSpec.tests
  , Cat.OppositeSpec.tests
  , Cat.ProductSpec.tests
  , Cat.SymmetricMonoidalSpec.tests
  ]
