module Cat.BraidedMonoidalSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Bifunctor
import Cat.Monoidal
import Cat.BraidedMonoidal
import Cat.Examples ()  -- (->) instance

--------------------------------------------------------------------------------
-- The braided cartesian monoidal category (Set, (,), ())
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

-- | The braided structure on (Set, (,), ()) with swap as the braiding.
--
-- The cartesian product is symmetric, so the braiding is simply @swap@:
-- \(\sigma_{A,B}(a,b) = (b,a)\). Since swap is self-inverse,
-- @braidingBwd = braidingFwd@.
--
-- nLab: cartesian+monoidal+category, braided+monoidal+category.
setBraided :: BraidedData (->) (,) ()
setBraided = BraidedData
  { braidedMonoidal = setMonoidal
  , braidingFwd = \(a, b) -> (b, a)
  , braidingBwd = \(a, b) -> (b, a)
  }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

comp :: (b -> c) -> (a -> b) -> (a -> c)
comp = catCompose (monCat setMonoidal)

bm :: (a1 -> b1) -> (a2 -> b2) -> ((a1, a2) -> (b1, b2))
bm = bimap (monTensor setMonoidal)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Cat.BraidedMonoidal"
  [ testGroup "Braiding roundtrip"
    [ testProperty "fwd . bwd = id" prop_braidFwdBwd
    , testProperty "bwd . fwd = id" prop_braidBwdFwd
    ]
  , testGroup "Braiding naturality"
    [ testProperty "sigma . bimap f g = bimap g f . sigma" prop_braidNaturality
    ]
  , testGroup "Hexagon axiom 1"
    [ testProperty "both paths agree" prop_hexagon1
    ]
  , testGroup "Hexagon axiom 2"
    [ testProperty "both paths agree" prop_hexagon2
    ]
  ]

--------------------------------------------------------------------------------
-- Braiding roundtrip
--------------------------------------------------------------------------------

prop_braidFwdBwd :: (Int, Bool) -> Bool
prop_braidFwdBwd x =
  comp (braidingFwd setBraided) (braidingBwd setBraided) x == x

prop_braidBwdFwd :: (Bool, Int) -> Bool
prop_braidBwdFwd x =
  comp (braidingBwd setBraided) (braidingFwd setBraided) x == x

--------------------------------------------------------------------------------
-- Braiding naturality
--------------------------------------------------------------------------------

-- | For concrete functions f, g, the braiding commutes with bimap:
--
-- @braidingFwd . bimap f g = bimap g f . braidingFwd@
prop_braidNaturality :: Fun Int Int -> Fun Bool Bool -> (Int, Bool) -> Bool
prop_braidNaturality (Fun _ f) (Fun _ g) x =
  let lhs = comp
              (braidingFwd setBraided :: (Int, Bool) -> (Bool, Int))
              (bm f g)
              x
      rhs = comp
              (bm g f)
              (braidingFwd setBraided :: (Int, Bool) -> (Bool, Int))
              x
  in  lhs == rhs

--------------------------------------------------------------------------------
-- Hexagon axiom 1
--------------------------------------------------------------------------------

-- | Hexagon 1 at concrete types (Int, Bool, Char).
--
-- Left-hand side:
--   alpha_{B,C,A} . sigma_{A,B*C} . alpha_{A,B,C}
--
-- Right-hand side:
--   (id_B `bimap` sigma_{A,C}) . alpha_{B,A,C} . (sigma_{A,B} `bimap` id_C)
--
-- Both have type ((Int, Bool), Char) -> (Bool, (Char, Int)).
prop_hexagon1 :: ((Int, Bool), Char) -> Bool
prop_hexagon1 x =
  let -- LHS: alpha_{A,B,C} then sigma_{A,B*C} then alpha_{B,C,A}
      step1L = monAssocFwd setMonoidal :: ((Int, Bool), Char) -> (Int, (Bool, Char))
      step2L = braidingFwd setBraided  :: (Int, (Bool, Char)) -> ((Bool, Char), Int)
      step3L = monAssocFwd setMonoidal :: ((Bool, Char), Int) -> (Bool, (Char, Int))
      lhs    = comp step3L (comp step2L step1L)

      -- RHS: (sigma_{A,B} * id_C) then alpha_{B,A,C} then (id_B * sigma_{A,C})
      step1R = bm
                 (braidingFwd setBraided :: (Int, Bool) -> (Bool, Int))
                 (id :: Char -> Char)
      step2R = monAssocFwd setMonoidal :: ((Bool, Int), Char) -> (Bool, (Int, Char))
      step3R = bm
                 (id :: Bool -> Bool)
                 (braidingFwd setBraided :: (Int, Char) -> (Char, Int))
      rhs    = comp step3R (comp step2R step1R)
  in  lhs x == rhs x

--------------------------------------------------------------------------------
-- Hexagon axiom 2
--------------------------------------------------------------------------------

-- | Hexagon 2 at concrete types (Int, Bool, Char).
--
-- Left-hand side:
--   alpha_inv_{C,A,B} . sigma_{A*B,C} . alpha_inv_{A,B,C}
--
-- Right-hand side:
--   (sigma_{A,C} `bimap` id_B) . alpha_inv_{A,C,B} . (id_A `bimap` sigma_{B,C})
--
-- Both have type (Int, (Bool, Char)) -> ((Char, Int), Bool).
prop_hexagon2 :: (Int, (Bool, Char)) -> Bool
prop_hexagon2 x =
  let -- LHS: alpha_inv_{A,B,C} then sigma_{A*B,C} then alpha_inv_{C,A,B}
      step1L = monAssocBwd setMonoidal :: (Int, (Bool, Char)) -> ((Int, Bool), Char)
      step2L = braidingFwd setBraided  :: ((Int, Bool), Char) -> (Char, (Int, Bool))
      step3L = monAssocBwd setMonoidal :: (Char, (Int, Bool)) -> ((Char, Int), Bool)
      lhs    = comp step3L (comp step2L step1L)

      -- RHS: (id_A * sigma_{B,C}) then alpha_inv_{A,C,B} then (sigma_{A,C} * id_B)
      step1R = bm
                 (id :: Int -> Int)
                 (braidingFwd setBraided :: (Bool, Char) -> (Char, Bool))
      step2R = monAssocBwd setMonoidal :: (Int, (Char, Bool)) -> ((Int, Char), Bool)
      step3R = bm
                 (braidingFwd setBraided :: (Int, Char) -> (Char, Int))
                 (id :: Bool -> Bool)
      rhs    = comp step3R (comp step2R step1R)
  in  lhs x == rhs x
