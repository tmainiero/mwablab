module Cat.MonoidalSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Bifunctor
import Cat.Monoidal
import Cat.Examples ()  -- (->) instance

--------------------------------------------------------------------------------
-- The cartesian monoidal category (Set, (,), ())
--------------------------------------------------------------------------------

-- | The cartesian monoidal structure on Set (represented via ->).
--
-- * Tensor product: @(,)@ (cartesian product)
-- * Unit: @()@ (terminal object)
-- * Associator: @((a,b),c) <-> (a,(b,c))@
-- * Left unitor: @((),a) <-> a@
-- * Right unitor: @(a,()) <-> a@
--
-- This is the standard example of a monoidal category.
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

--------------------------------------------------------------------------------
-- Helper: extract compose and bimap for readability
--------------------------------------------------------------------------------

comp :: (b -> c) -> (a -> b) -> (a -> c)
comp = catCompose (monCat setMonoidal)

bm :: (a1 -> b1) -> (a2 -> b2) -> ((a1, a2) -> (b1, b2))
bm = bimap (monTensor setMonoidal)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Cat.Monoidal"
  [ testGroup "Associator roundtrip"
    [ testProperty "fwd . bwd = id" prop_assocFwdBwd
    , testProperty "bwd . fwd = id" prop_assocBwdFwd
    ]
  , testGroup "Left unitor roundtrip"
    [ testProperty "fwd . bwd = id" prop_leftUnitorFwdBwd
    , testProperty "bwd . fwd = id" prop_leftUnitorBwdFwd
    ]
  , testGroup "Right unitor roundtrip"
    [ testProperty "fwd . bwd = id" prop_rightUnitorFwdBwd
    , testProperty "bwd . fwd = id" prop_rightUnitorBwdFwd
    ]
  , testGroup "Associator naturality"
    [ testProperty "assocFwd . bimap (bimap f g) h = bimap f (bimap g h) . assocFwd"
        prop_assocNaturality
    ]
  , testGroup "Pentagon axiom"
    [ testProperty "both paths around the pentagon agree" prop_pentagon
    ]
  , testGroup "Triangle axiom"
    [ testProperty "bimap id lambda . alpha = bimap rho id" prop_triangle
    ]
  ]

--------------------------------------------------------------------------------
-- Associator roundtrip
--------------------------------------------------------------------------------

prop_assocFwdBwd :: (Int, (Bool, Char)) -> Bool
prop_assocFwdBwd x =
  comp (monAssocFwd setMonoidal) (monAssocBwd setMonoidal) x == x

prop_assocBwdFwd :: ((Int, Bool), Char) -> Bool
prop_assocBwdFwd x =
  comp (monAssocBwd setMonoidal) (monAssocFwd setMonoidal) x == x

--------------------------------------------------------------------------------
-- Left unitor roundtrip
--------------------------------------------------------------------------------

prop_leftUnitorFwdBwd :: Int -> Bool
prop_leftUnitorFwdBwd x =
  comp (monLeftUnitorFwd setMonoidal) (monLeftUnitorBwd setMonoidal) x == x

prop_leftUnitorBwdFwd :: ((), Int) -> Bool
prop_leftUnitorBwdFwd x =
  comp (monLeftUnitorBwd setMonoidal) (monLeftUnitorFwd setMonoidal) x == x

--------------------------------------------------------------------------------
-- Right unitor roundtrip
--------------------------------------------------------------------------------

prop_rightUnitorFwdBwd :: Int -> Bool
prop_rightUnitorFwdBwd x =
  comp (monRightUnitorFwd setMonoidal) (monRightUnitorBwd setMonoidal) x == x

prop_rightUnitorBwdFwd :: (Int, ()) -> Bool
prop_rightUnitorBwdFwd x =
  comp (monRightUnitorBwd setMonoidal) (monRightUnitorFwd setMonoidal) x == x

--------------------------------------------------------------------------------
-- Associator naturality
--------------------------------------------------------------------------------

-- | For concrete functions f, g, h, the associator commutes with bimap:
--
-- @monAssocFwd . bimap (bimap f g) h = bimap f (bimap g h) . monAssocFwd@
prop_assocNaturality :: Fun Int Int -> Fun Bool Bool -> Fun Char Char
                     -> ((Int, Bool), Char) -> Bool
prop_assocNaturality (Fun _ f) (Fun _ g) (Fun _ h) x =
  let lhs = comp (monAssocFwd setMonoidal) (bm (bm f g) h) x
      rhs = comp (bm f (bm g h)) (monAssocFwd setMonoidal) x
  in  lhs == rhs

--------------------------------------------------------------------------------
-- Pentagon axiom
--------------------------------------------------------------------------------

-- | The pentagon axiom at concrete types (Int, Bool, Char, String).
--
-- Left path:
--   (id * alpha_{B,C,D}) . alpha_{A, B*C, D} . (alpha_{A,B,C} * id_D)
--
-- Right path:
--   alpha_{A,B,C*D} . alpha_{A*B,C,D}
--
-- Both must agree at every value of type (((Int, Bool), Char), String).
prop_pentagon :: (((Int, Bool), Char), String) -> Bool
prop_pentagon x =
  let -- Right path: alpha_{A*B,C,D} then alpha_{A,B,C*D}
      rightPath = comp
        (monAssocFwd setMonoidal :: ((Int, Bool), (Char, String)) -> (Int, (Bool, (Char, String))))
        (monAssocFwd setMonoidal :: (((Int, Bool), Char), String) -> ((Int, Bool), (Char, String)))
      -- Left path: (alpha_{A,B,C} * id_D), then alpha_{A,B*C,D}, then (id_A * alpha_{B,C,D})
      step1 = bm
        (monAssocFwd setMonoidal :: ((Int, Bool), Char) -> (Int, (Bool, Char)))
        (id :: String -> String)
      step2 = monAssocFwd setMonoidal :: ((Int, (Bool, Char)), String) -> (Int, ((Bool, Char), String))
      step3 = bm
        (id :: Int -> Int)
        (monAssocFwd setMonoidal :: ((Bool, Char), String) -> (Bool, (Char, String)))
      leftPath = comp step3 (comp step2 step1)
  in  leftPath x == rightPath x

--------------------------------------------------------------------------------
-- Triangle axiom
--------------------------------------------------------------------------------

-- | The triangle axiom at concrete types (Int, Bool).
--
-- @(id_A `bimap` lambda_B) . alpha_{A,I,B} = rho_A `bimap` id_B@
--
-- Both sides have type @(Int, (), Bool) -> (Int, Bool)@ (up to reassociation
-- via alpha: @((Int, ()), Bool) -> (Int, Bool)@).
prop_triangle :: ((Int, ()), Bool) -> Bool
prop_triangle x =
  let lhs = comp
              (bm
                (id :: Int -> Int)
                (monLeftUnitorFwd setMonoidal :: ((), Bool) -> Bool))
              (monAssocFwd setMonoidal :: ((Int, ()), Bool) -> (Int, ((), Bool)))
              x
      rhs = bm
              (monRightUnitorFwd setMonoidal :: (Int, ()) -> Int)
              (id :: Bool -> Bool)
              x
  in  lhs == rhs
