module Cat.ProductSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Product
import Cat.Examples ()

tests :: TestTree
tests = testGroup "Cat.Product"
  [ testGroup "Prod (->) (->) instance"
    [ testProperty "left identity" prop_leftIdentity
    , testProperty "right identity" prop_rightIdentity
    , testProperty "associativity" prop_assoc
    ]
  , testGroup "productData (ProdHom)"
    [ testProperty "data left identity" prop_dataLeftId
    , testProperty "data right identity" prop_dataRightId
    , testProperty "data associativity" prop_dataAssoc
    ]
  , testGroup "projections"
    [ testProperty "pi1 extracts first component" prop_pi1
    , testProperty "pi2 extracts second component" prop_pi2
    ]
  ]

-- Helpers: typeclass track (Prod on promoted pairs)
type ProdArr = Prod (->) (->) '(Int, Int) '(Int, Int)

mkProd :: (Int -> Int) -> (Int -> Int) -> ProdArr
mkProd f g = Prod (f, g)

applyProd :: ProdArr -> (Int, Int) -> (Int, Int)
applyProd (Prod (f, g)) (x, y) = (f x, g y)

-- Helpers: data track (ProdHom on value-level pairs)
type ProdHomArr = ProdHom (->) (->) (Int, Int) (Int, Int)

mkProdHom :: (Int -> Int) -> (Int -> Int) -> ProdHomArr
mkProdHom f g = ProdHom (f, g)

applyProdHom :: ProdHomArr -> (Int, Int) -> (Int, Int)
applyProdHom (ProdHom (f, g)) (x, y) = (f x, g y)

-- Typeclass track properties

prop_leftIdentity :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_leftIdentity (Fun _ f) (Fun _ g) xy =
  applyProd (compose (id :: ProdArr) (mkProd f g)) xy
    == applyProd (mkProd f g) xy

prop_rightIdentity :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_rightIdentity (Fun _ f) (Fun _ g) xy =
  applyProd (compose (mkProd f g) (id :: ProdArr)) xy
    == applyProd (mkProd f g) xy

prop_assoc :: Fun Int Int -> Fun Int Int
           -> Fun Int Int -> Fun Int Int
           -> Fun Int Int -> Fun Int Int
           -> (Int, Int) -> Bool
prop_assoc (Fun _ h1) (Fun _ h2) (Fun _ g1) (Fun _ g2) (Fun _ f1) (Fun _ f2) xy =
  applyProd (compose (mkProd h1 h2) (compose (mkProd g1 g2) (mkProd f1 f2))) xy
    == applyProd (compose (compose (mkProd h1 h2) (mkProd g1 g2)) (mkProd f1 f2)) xy

-- Data track properties

prodData :: CategoryData (ProdHom (->) (->))
prodData = productData categoryDataFromClass categoryDataFromClass

prop_dataLeftId :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_dataLeftId (Fun _ f) (Fun _ g) xy =
  applyProdHom (catCompose prodData (catIdentity prodData) (mkProdHom f g)) xy
    == applyProdHom (mkProdHom f g) xy

prop_dataRightId :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_dataRightId (Fun _ f) (Fun _ g) xy =
  applyProdHom (catCompose prodData (mkProdHom f g) (catIdentity prodData)) xy
    == applyProdHom (mkProdHom f g) xy

prop_dataAssoc :: Fun Int Int -> Fun Int Int
               -> Fun Int Int -> Fun Int Int
               -> Fun Int Int -> Fun Int Int
               -> (Int, Int) -> Bool
prop_dataAssoc (Fun _ h1) (Fun _ h2) (Fun _ g1) (Fun _ g2) (Fun _ f1) (Fun _ f2) xy =
  applyProdHom (catCompose prodData (mkProdHom h1 h2)
    (catCompose prodData (mkProdHom g1 g2) (mkProdHom f1 f2))) xy
    == applyProdHom (catCompose prodData
         (catCompose prodData (mkProdHom h1 h2) (mkProdHom g1 g2))
         (mkProdHom f1 f2)) xy

-- Projection properties

prop_pi1 :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_pi1 (Fun _ f) (Fun _ g) (x, _y) =
  let Prod (f', _) = mkProd f g
  in f' x == f x

prop_pi2 :: Fun Int Int -> Fun Int Int -> (Int, Int) -> Bool
prop_pi2 (Fun _ f) (Fun _ g) (_x, y) =
  let Prod (_, g') = mkProd f g
  in g' y == g y
