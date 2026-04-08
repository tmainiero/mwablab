module Cat.NaturalIsomorphismSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.NaturalIsomorphism
import Cat.Examples ()  -- (->) and Maybe instances

--------------------------------------------------------------------------------
-- Test infrastructure
--------------------------------------------------------------------------------

-- | Wrapper for a paired value @(a, ())@, used to test the left unitor.
newtype Paired a = Paired { getPaired :: (a, ()) }
  deriving stock (Eq, Show)

instance Arbitrary a => Arbitrary (Paired a) where
  arbitrary = (\x -> Paired (x, ())) <$> arbitrary

-- | Simple identity wrapper.
newtype Id a = Id { runId :: a }
  deriving stock (Eq, Show)
  deriving newtype (Arbitrary)

-- | A concrete natural isomorphism: Paired ~ Id (the left unitor preview).
-- Forward: Paired a -> Id a;  Backward: Id a -> Paired a.
leftUnitor :: NatIso (->) Paired Id
leftUnitor = NatIso
  { niForward  = \(Paired (x, ())) -> Id x
  , niBackward = \(Id x) -> Paired (x, ())
  }

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Cat.NaturalIsomorphism"
  [ testGroup "Identity natural isomorphism"
    [ testProperty "forward is id" prop_idForward
    , testProperty "backward is id" prop_idBackward
    , testProperty "roundtrip forward-backward" prop_idRoundtrip
    ]
  , testGroup "Left unitor isomorphism"
    [ testProperty "forward . backward = id" prop_leftUnitorFwdBwd
    , testProperty "backward . forward = id" prop_leftUnitorBwdFwd
    ]
  , testGroup "composeNatIso"
    [ testProperty "compose with id (left) preserves roundtrip"
        prop_composeIdLeft
    , testProperty "compose with id (right) preserves roundtrip"
        prop_composeIdRight
    , testProperty "compose iso with inverse is identity"
        prop_composeWithInverse
    ]
  , testGroup "invertNatIso"
    [ testProperty "invert swaps forward and backward" prop_invertSwaps
    , testProperty "double invert is identity" prop_doubleInvert
    ]
  ]

-- Identity natural isomorphism on Maybe
prop_idForward :: Maybe Int -> Bool
prop_idForward mx =
  let iso = idNatIso :: NatIso (->) Maybe Maybe
  in  niForward iso mx == mx

prop_idBackward :: Maybe Int -> Bool
prop_idBackward mx =
  let iso = idNatIso :: NatIso (->) Maybe Maybe
  in  niBackward iso mx == mx

prop_idRoundtrip :: Maybe Int -> Bool
prop_idRoundtrip mx =
  let iso = idNatIso :: NatIso (->) Maybe Maybe
  in  compose (niBackward iso) (niForward iso) mx == mx

-- Left unitor: Paired ~ Id
prop_leftUnitorFwdBwd :: Paired Int -> Bool
prop_leftUnitorFwdBwd px =
  compose (niBackward leftUnitor) (niForward leftUnitor) px == px

prop_leftUnitorBwdFwd :: Id Int -> Bool
prop_leftUnitorBwdFwd x =
  compose (niForward leftUnitor) (niBackward leftUnitor) x == x

-- composeNatIso: compose with idNatIso on the left
prop_composeIdLeft :: Paired Int -> Bool
prop_composeIdLeft px =
  let composed = composeNatIso idNatIso leftUnitor
  in  compose (niBackward composed) (niForward composed) px == px

-- composeNatIso: compose with idNatIso on the right
prop_composeIdRight :: Paired Int -> Bool
prop_composeIdRight px =
  let composed = composeNatIso leftUnitor idNatIso
  in  compose (niBackward composed) (niForward composed) px == px

-- composeNatIso: composing an iso with its inverse gives identity roundtrip
prop_composeWithInverse :: Paired Int -> Bool
prop_composeWithInverse px =
  let inv = invertNatIso leftUnitor
      composed = composeNatIso inv leftUnitor
  in  compose (niBackward composed) (niForward composed) px == px

-- invertNatIso: forward of inverse = backward of original
prop_invertSwaps :: Id Int -> Bool
prop_invertSwaps x =
  let inv = invertNatIso leftUnitor
  in  niForward inv x == niBackward leftUnitor x

-- Double invert recovers original
prop_doubleInvert :: Paired Int -> Bool
prop_doubleInvert px =
  let inv2 = invertNatIso (invertNatIso leftUnitor)
  in  niForward inv2 px == niForward leftUnitor px
