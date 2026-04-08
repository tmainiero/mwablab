module Cat.Examples.MonoidalSpec (tests) where

import Prelude hiding (id, (.))
import Data.Void (Void)

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category (Category(..), CategoryData(..))
import Cat.Bifunctor (BifunctorData(..))
import Cat.Monoidal (MonoidalData(..))
import Cat.BraidedMonoidal (BraidedData(..))
import Cat.Examples ()  -- (->) instance
import Cat.Examples.Monoidal

--------------------------------------------------------------------------------
-- Helpers: cartesian (Set, (,), ())
--------------------------------------------------------------------------------

compP :: (b -> c) -> (a -> b) -> (a -> c)
compP = catCompose (monCat setProductMonoidal)

bmP :: (a1 -> b1) -> (a2 -> b2) -> ((a1, a2) -> (b1, b2))
bmP = bimap (monTensor setProductMonoidal)

--------------------------------------------------------------------------------
-- Helpers: cocartesian (Set, Either, Void)
--------------------------------------------------------------------------------

compC :: (b -> c) -> (a -> b) -> (a -> c)
compC = catCompose (monCat setCoproductMonoidal)

bmC :: (a1 -> b1) -> (a2 -> b2) -> (Either a1 a2 -> Either b1 b2)
bmC = bimap (monTensor setCoproductMonoidal)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Cat.Examples.Monoidal"
  [ testGroup "Cartesian (Set, (,), ())" cartesianTests
  , testGroup "Cocartesian (Set, Either, Void)" cocartesianTests
  ]

--------------------------------------------------------------------------------
-- Cartesian monoidal: (Set, (,), ())
--------------------------------------------------------------------------------

cartesianTests :: [TestTree]
cartesianTests =
  [ testGroup "Associator roundtrip"
    [ testProperty "fwd . bwd = id" propP_assocFwdBwd
    , testProperty "bwd . fwd = id" propP_assocBwdFwd
    ]
  , testGroup "Left unitor roundtrip"
    [ testProperty "fwd . bwd = id" propP_leftUnitorFwdBwd
    , testProperty "bwd . fwd = id" propP_leftUnitorBwdFwd
    ]
  , testGroup "Right unitor roundtrip"
    [ testProperty "fwd . bwd = id" propP_rightUnitorFwdBwd
    , testProperty "bwd . fwd = id" propP_rightUnitorBwdFwd
    ]
  , testGroup "Pentagon axiom"
    [ testProperty "both paths agree at (Int, Bool, Char, String)" propP_pentagon
    ]
  , testGroup "Triangle axiom"
    [ testProperty "bimap id lambda . alpha = bimap rho id" propP_triangle
    ]
  , testGroup "Hexagon axiom 1"
    [ testProperty "both paths agree at (Int, Bool, Char)" propP_hexagon1
    ]
  , testGroup "Hexagon axiom 2"
    [ testProperty "both paths agree at (Int, Bool, Char)" propP_hexagon2
    ]
  , testGroup "Symmetry"
    [ testProperty "sigma_{B,A} . sigma_{A,B} = id at (Int, Bool)" propP_symmetry
    ]
  , testGroup "Braiding naturality"
    [ testProperty "sigma . bimap f g = bimap g f . sigma" propP_braidNaturality
    ]
  ]

-- Associator roundtrip

propP_assocFwdBwd :: (Int, (Bool, Char)) -> Bool
propP_assocFwdBwd x =
  compP (monAssocFwd setProductMonoidal) (monAssocBwd setProductMonoidal) x == x

propP_assocBwdFwd :: ((Int, Bool), Char) -> Bool
propP_assocBwdFwd x =
  compP (monAssocBwd setProductMonoidal) (monAssocFwd setProductMonoidal) x == x

-- Left unitor roundtrip

propP_leftUnitorFwdBwd :: Int -> Bool
propP_leftUnitorFwdBwd x =
  compP (monLeftUnitorFwd setProductMonoidal) (monLeftUnitorBwd setProductMonoidal) x == x

propP_leftUnitorBwdFwd :: ((), Int) -> Bool
propP_leftUnitorBwdFwd x =
  compP (monLeftUnitorBwd setProductMonoidal) (monLeftUnitorFwd setProductMonoidal) x == x

-- Right unitor roundtrip

propP_rightUnitorFwdBwd :: Int -> Bool
propP_rightUnitorFwdBwd x =
  compP (monRightUnitorFwd setProductMonoidal) (monRightUnitorBwd setProductMonoidal) x == x

propP_rightUnitorBwdFwd :: (Int, ()) -> Bool
propP_rightUnitorBwdFwd x =
  compP (monRightUnitorBwd setProductMonoidal) (monRightUnitorFwd setProductMonoidal) x == x

-- Pentagon axiom

propP_pentagon :: (((Int, Bool), Char), String) -> Bool
propP_pentagon x =
  let -- Right path: alpha_{A*B,C,D} then alpha_{A,B,C*D}
      rightPath = compP
        (monAssocFwd setProductMonoidal :: ((Int, Bool), (Char, String)) -> (Int, (Bool, (Char, String))))
        (monAssocFwd setProductMonoidal :: (((Int, Bool), Char), String) -> ((Int, Bool), (Char, String)))
      -- Left path: (alpha_{A,B,C} * id_D), then alpha_{A,B*C,D}, then (id_A * alpha_{B,C,D})
      step1 = bmP
        (monAssocFwd setProductMonoidal :: ((Int, Bool), Char) -> (Int, (Bool, Char)))
        (id :: String -> String)
      step2 = monAssocFwd setProductMonoidal :: ((Int, (Bool, Char)), String) -> (Int, ((Bool, Char), String))
      step3 = bmP
        (id :: Int -> Int)
        (monAssocFwd setProductMonoidal :: ((Bool, Char), String) -> (Bool, (Char, String)))
      leftPath = compP step3 (compP step2 step1)
  in  leftPath x == rightPath x

-- Triangle axiom

propP_triangle :: ((Int, ()), Bool) -> Bool
propP_triangle x =
  let lhs = compP
              (bmP
                (id :: Int -> Int)
                (monLeftUnitorFwd setProductMonoidal :: ((), Bool) -> Bool))
              (monAssocFwd setProductMonoidal :: ((Int, ()), Bool) -> (Int, ((), Bool)))
              x
      rhs = bmP
              (monRightUnitorFwd setProductMonoidal :: (Int, ()) -> Int)
              (id :: Bool -> Bool)
              x
  in  lhs == rhs

-- Hexagon axiom 1

propP_hexagon1 :: ((Int, Bool), Char) -> Bool
propP_hexagon1 x =
  let bd = setProductBraided
      mon = setProductMonoidal
      -- LHS: alpha_{A,B,C} then sigma_{A,B*C} then alpha_{B,C,A}
      step1L = monAssocFwd mon :: ((Int, Bool), Char) -> (Int, (Bool, Char))
      step2L = braidingFwd bd  :: (Int, (Bool, Char)) -> ((Bool, Char), Int)
      step3L = monAssocFwd mon :: ((Bool, Char), Int) -> (Bool, (Char, Int))
      lhs    = compP step3L (compP step2L step1L)
      -- RHS: (sigma_{A,B} * id_C) then alpha_{B,A,C} then (id_B * sigma_{A,C})
      step1R = bmP
                 (braidingFwd bd :: (Int, Bool) -> (Bool, Int))
                 (id :: Char -> Char)
      step2R = monAssocFwd mon :: ((Bool, Int), Char) -> (Bool, (Int, Char))
      step3R = bmP
                 (id :: Bool -> Bool)
                 (braidingFwd bd :: (Int, Char) -> (Char, Int))
      rhs    = compP step3R (compP step2R step1R)
  in  lhs x == rhs x

-- Hexagon axiom 2

propP_hexagon2 :: (Int, (Bool, Char)) -> Bool
propP_hexagon2 x =
  let bd = setProductBraided
      mon = setProductMonoidal
      -- LHS: alpha_inv_{A,B,C} then sigma_{A*B,C} then alpha_inv_{C,A,B}
      step1L = monAssocBwd mon :: (Int, (Bool, Char)) -> ((Int, Bool), Char)
      step2L = braidingFwd bd  :: ((Int, Bool), Char) -> (Char, (Int, Bool))
      step3L = monAssocBwd mon :: (Char, (Int, Bool)) -> ((Char, Int), Bool)
      lhs    = compP step3L (compP step2L step1L)
      -- RHS: (id_A * sigma_{B,C}) then alpha_inv_{A,C,B} then (sigma_{A,C} * id_B)
      step1R = bmP
                 (id :: Int -> Int)
                 (braidingFwd bd :: (Bool, Char) -> (Char, Bool))
      step2R = monAssocBwd mon :: (Int, (Char, Bool)) -> ((Int, Char), Bool)
      step3R = bmP
                 (braidingFwd bd :: (Int, Char) -> (Char, Int))
                 (id :: Bool -> Bool)
      rhs    = compP step3R (compP step2R step1R)
  in  lhs x == rhs x

-- Symmetry

propP_symmetry :: (Int, Bool) -> Bool
propP_symmetry x =
  let bd = setProductBraided
  in  compP
        (braidingFwd bd :: (Bool, Int) -> (Int, Bool))
        (braidingFwd bd :: (Int, Bool) -> (Bool, Int))
        x == x

-- Braiding naturality

propP_braidNaturality :: Fun Int Int -> Fun Bool Bool -> (Int, Bool) -> Bool
propP_braidNaturality (Fun _ f) (Fun _ g) x =
  let bd = setProductBraided
      lhs = compP
              (braidingFwd bd :: (Int, Bool) -> (Bool, Int))
              (bmP f g)
              x
      rhs = compP
              (bmP g f)
              (braidingFwd bd :: (Int, Bool) -> (Bool, Int))
              x
  in  lhs == rhs

--------------------------------------------------------------------------------
-- Cocartesian monoidal: (Set, Either, Void)
--------------------------------------------------------------------------------

cocartesianTests :: [TestTree]
cocartesianTests =
  [ testGroup "Associator roundtrip"
    [ testProperty "fwd . bwd = id" propC_assocFwdBwd
    , testProperty "bwd . fwd = id" propC_assocBwdFwd
    ]
  , testGroup "Left unitor roundtrip"
    [ testProperty "fwd . bwd = id (on image)" propC_leftUnitorRoundtrip
    ]
  , testGroup "Right unitor roundtrip"
    [ testProperty "fwd . bwd = id (on image)" propC_rightUnitorRoundtrip
    ]
  , testGroup "Pentagon axiom"
    [ testProperty "both paths agree" propC_pentagon
    ]
  , testGroup "Triangle axiom"
    [ testProperty "both paths agree on inhabited inputs" propC_triangle
    ]
  , testGroup "Hexagon axiom 1"
    [ testProperty "both paths agree at (Int, Bool, Char)" propC_hexagon1
    ]
  , testGroup "Hexagon axiom 2"
    [ testProperty "both paths agree at (Int, Bool, Char)" propC_hexagon2
    ]
  , testGroup "Symmetry"
    [ testProperty "sigma_{B,A} . sigma_{A,B} = id at (Int, Bool)" propC_symmetry
    ]
  , testGroup "Braiding naturality"
    [ testProperty "sigma . bimap f g = bimap g f . sigma" propC_braidNaturality
    ]
  ]

-- Associator roundtrip

propC_assocFwdBwd :: Either Int (Either Bool Char) -> Bool
propC_assocFwdBwd x =
  compC (monAssocFwd setCoproductMonoidal) (monAssocBwd setCoproductMonoidal) x == x

propC_assocBwdFwd :: Either (Either Int Bool) Char -> Bool
propC_assocBwdFwd x =
  compC (monAssocBwd setCoproductMonoidal) (monAssocFwd setCoproductMonoidal) x == x

-- Left unitor roundtrip
-- For Either Void a, the only inhabited values are Right a.
-- We test: leftUnitorFwd . leftUnitorBwd = id on a values.

propC_leftUnitorRoundtrip :: Int -> Bool
propC_leftUnitorRoundtrip x =
  let mon = setCoproductMonoidal
  in  monLeftUnitorFwd mon (monLeftUnitorBwd mon x :: Either Void Int) == x

-- Right unitor roundtrip
-- For Either a Void, the only inhabited values are Left a.
-- We test: rightUnitorFwd . rightUnitorBwd = id on a values.

propC_rightUnitorRoundtrip :: Int -> Bool
propC_rightUnitorRoundtrip x =
  let mon = setCoproductMonoidal
  in  monRightUnitorFwd mon (monRightUnitorBwd mon x :: Either Int Void) == x

-- Pentagon axiom

propC_pentagon :: Either (Either (Either Int Bool) Char) String -> Bool
propC_pentagon x =
  let mon = setCoproductMonoidal
      -- Right path: alpha_{A*B,C,D} then alpha_{A,B,C*D}
      rightPath = compC
        (monAssocFwd mon :: Either (Either Int Bool) (Either Char String)
                         -> Either Int (Either Bool (Either Char String)))
        (monAssocFwd mon :: Either (Either (Either Int Bool) Char) String
                         -> Either (Either Int Bool) (Either Char String))
      -- Left path: (alpha_{A,B,C} * id_D), then alpha_{A,B*C,D}, then (id_A * alpha_{B,C,D})
      step1 = bmC
        (monAssocFwd mon :: Either (Either Int Bool) Char -> Either Int (Either Bool Char))
        (id :: String -> String)
      step2 = monAssocFwd mon :: Either (Either Int (Either Bool Char)) String
                              -> Either Int (Either (Either Bool Char) String)
      step3 = bmC
        (id :: Int -> Int)
        (monAssocFwd mon :: Either (Either Bool Char) String -> Either Bool (Either Char String))
      leftPath = compC step3 (compC step2 step1)
  in  leftPath x == rightPath x

-- Triangle axiom
-- (id_A `bimap` lambda_B) . alpha_{A,I,B} = rho_A `bimap` id_B
-- where I = Void, tensor = Either.
-- Input type: Either (Either A Void) B.
-- Inhabited inputs: Left (Left a) or Right b (never Left (Right void)).
-- We test both inhabited branches via an Either Int Bool input, mapping
-- Left n -> Left (Left n) and Right b -> Right b.

propC_triangle :: Either Int Bool -> Bool
propC_triangle x =
  let mon = setCoproductMonoidal
      -- Embed into Either (Either Int Void) Bool
      input :: Either (Either Int Void) Bool
      input = case x of
        Left n  -> Left (Left n)
        Right b -> Right b
      lhs = compC
              (bmC
                (id :: Int -> Int)
                (monLeftUnitorFwd mon :: Either Void Bool -> Bool))
              (monAssocFwd mon :: Either (Either Int Void) Bool
                              -> Either Int (Either Void Bool))
              input
      rhs = bmC
              (monRightUnitorFwd mon :: Either Int Void -> Int)
              (id :: Bool -> Bool)
              input
  in  lhs == rhs

-- Hexagon axiom 1

propC_hexagon1 :: Either (Either Int Bool) Char -> Bool
propC_hexagon1 x =
  let bd  = setCoproductBraided
      mon = setCoproductMonoidal
      -- LHS: alpha_{A,B,C} then sigma_{A,B*C} then alpha_{B,C,A}
      step1L = monAssocFwd mon :: Either (Either Int Bool) Char -> Either Int (Either Bool Char)
      step2L = braidingFwd bd  :: Either Int (Either Bool Char) -> Either (Either Bool Char) Int
      step3L = monAssocFwd mon :: Either (Either Bool Char) Int -> Either Bool (Either Char Int)
      lhs    = compC step3L (compC step2L step1L)
      -- RHS: (sigma_{A,B} * id_C) then alpha_{B,A,C} then (id_B * sigma_{A,C})
      step1R = bmC
                 (braidingFwd bd :: Either Int Bool -> Either Bool Int)
                 (id :: Char -> Char)
      step2R = monAssocFwd mon :: Either (Either Bool Int) Char -> Either Bool (Either Int Char)
      step3R = bmC
                 (id :: Bool -> Bool)
                 (braidingFwd bd :: Either Int Char -> Either Char Int)
      rhs    = compC step3R (compC step2R step1R)
  in  lhs x == rhs x

-- Hexagon axiom 2

propC_hexagon2 :: Either Int (Either Bool Char) -> Bool
propC_hexagon2 x =
  let bd  = setCoproductBraided
      mon = setCoproductMonoidal
      -- LHS: alpha_inv_{A,B,C} then sigma_{A*B,C} then alpha_inv_{C,A,B}
      step1L = monAssocBwd mon :: Either Int (Either Bool Char) -> Either (Either Int Bool) Char
      step2L = braidingFwd bd  :: Either (Either Int Bool) Char -> Either Char (Either Int Bool)
      step3L = monAssocBwd mon :: Either Char (Either Int Bool) -> Either (Either Char Int) Bool
      lhs    = compC step3L (compC step2L step1L)
      -- RHS: (id_A * sigma_{B,C}) then alpha_inv_{A,C,B} then (sigma_{A,C} * id_B)
      step1R = bmC
                 (id :: Int -> Int)
                 (braidingFwd bd :: Either Bool Char -> Either Char Bool)
      step2R = monAssocBwd mon :: Either Int (Either Char Bool) -> Either (Either Int Char) Bool
      step3R = bmC
                 (braidingFwd bd :: Either Int Char -> Either Char Int)
                 (id :: Bool -> Bool)
      rhs    = compC step3R (compC step2R step1R)
  in  lhs x == rhs x

-- Symmetry

propC_symmetry :: Either Int Bool -> Bool
propC_symmetry x =
  let bd = setCoproductBraided
  in  compC
        (braidingFwd bd :: Either Bool Int -> Either Int Bool)
        (braidingFwd bd :: Either Int Bool -> Either Bool Int)
        x == x

-- Braiding naturality

propC_braidNaturality :: Fun Int Int -> Fun Bool Bool -> Either Int Bool -> Bool
propC_braidNaturality (Fun _ f) (Fun _ g) x =
  let bd = setCoproductBraided
      lhs = compC
              (braidingFwd bd :: Either Int Bool -> Either Bool Int)
              (bmC f g)
              x
      rhs = compC
              (bmC g f)
              (braidingFwd bd :: Either Int Bool -> Either Bool Int)
              x
  in  lhs == rhs
