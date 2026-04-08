module Cat.ProductSpec (tests) where

import Prelude hiding (id, (.))

import Test.Tasty
import Test.Tasty.QuickCheck

import Cat.Category
import Cat.Product
import Cat.Examples ()

tests :: TestTree
tests = testGroup "Cat.Product"
  [ testGroup "productData (ProdHom)"
    [ testProperty "data left identity" prop_dataLeftId
    , testProperty "data right identity" prop_dataRightId
    , testProperty "data associativity" prop_dataAssoc
    ]
  ]

-- Helpers: data track (ProdHom on value-level pairs)
type ProdHomArr = ProdHom (->) (->) (Int, Int) (Int, Int)

mkProdHom :: (Int -> Int) -> (Int -> Int) -> ProdHomArr
mkProdHom f g = ProdHom (f, g)

applyProdHom :: ProdHomArr -> (Int, Int) -> (Int, Int)
applyProdHom (ProdHom (f, g)) (x, y) = (f x, g y)

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
