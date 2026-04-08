module Cat.SymmetricMonoidalSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Bifunctor
import Cat.Monoidal
import Cat.BraidedMonoidal
import Cat.SymmetricMonoidal
import Cat.Examples ()  -- (->) instance

--------------------------------------------------------------------------------
-- The symmetric cartesian monoidal category (Set, (,), ())
--------------------------------------------------------------------------------

-- | The cartesian monoidal structure on Set (represented via ->).
--
-- nLab: cartesian+monoidal+category.
setMonoidal :: MonoidalData (->) (,) ()
setMonoidal = MonoidalData
  { monCat = categoryDataFromClass
  , monTensor = BifunctorData { bimap = \f g (a, b) -> (f a, g b) }
  , monAssocFwd = \((a, b), c) -> (a, (b, c))
  , monAssocBwd = \(a, (b, c)) -> ((a, b), c)
  , monLeftUnitorFwd = \((), a) -> a
  , monLeftUnitorBwd = \a -> ((), a)
  , monRightUnitorFwd = \(a, ()) -> a
  , monRightUnitorBwd = \a -> (a, ())
  }

-- | The symmetric monoidal structure on (Set, (,), ()).
--
-- Since @swap . swap = id@, the cartesian braiding is symmetric.
--
-- nLab: cartesian+monoidal+category, symmetric+monoidal+category.
setSymmetric :: SymmetricData (->) (,) ()
setSymmetric = SymmetricData
  { symmetricBraided = BraidedData
    { braidedMonoidal = setMonoidal
    , braidingFwd = \(a, b) -> (b, a)
    , braidingBwd = \(a, b) -> (b, a)
    }
  }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

comp :: (b -> c) -> (a -> b) -> (a -> c)
comp = catCompose (monCat setMonoidal)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Cat.SymmetricMonoidal"
  [ testGroup "Symmetry condition"
    [ testProperty "sigma_{B,A} . sigma_{A,B} = id  (Int, Bool)"
        prop_symmetry_IntBool
    , testProperty "sigma_{B,A} . sigma_{A,B} = id  (Char, String)"
        prop_symmetry_CharString
    , testProperty "sigma_{B,A} . sigma_{A,B} = id  (Int, (Bool, Char))"
        prop_symmetry_nested
    ]
  ]

--------------------------------------------------------------------------------
-- Symmetry: sigma_{B,A} . sigma_{A,B} = id
--------------------------------------------------------------------------------

-- | Extract the braiding for convenience.
sigma :: BraidedData (->) (,) () -> (a, b) -> (b, a)
sigma bd = braidingFwd bd

bd :: BraidedData (->) (,) ()
bd = symmetricBraided setSymmetric

prop_symmetry_IntBool :: (Int, Bool) -> Bool
prop_symmetry_IntBool x =
  comp
    (sigma bd :: (Bool, Int) -> (Int, Bool))
    (sigma bd :: (Int, Bool) -> (Bool, Int))
    x == x

prop_symmetry_CharString :: (Char, String) -> Bool
prop_symmetry_CharString x =
  comp
    (sigma bd :: (String, Char) -> (Char, String))
    (sigma bd :: (Char, String) -> (String, Char))
    x == x

prop_symmetry_nested :: (Int, (Bool, Char)) -> Bool
prop_symmetry_nested x =
  comp
    (sigma bd :: ((Bool, Char), Int) -> (Int, (Bool, Char)))
    (sigma bd :: (Int, (Bool, Char)) -> ((Bool, Char), Int))
    x == x
