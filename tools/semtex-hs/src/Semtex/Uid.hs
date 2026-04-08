-- | Base-35 UID generation and assignment for semtex v2.
--
-- UIDs are sequential base-35 tags using digits 0-9 and letters A-Z
-- minus O (to avoid confusion with zero). Like Stacks Project tags.
-- They are monotonic, never reused, and stored in the registry sidecar.
module Semtex.Uid
  ( -- * Base-35 alphabet
    base35Alphabet
    -- * Tag operations
  , initialUid
  , nextUid
  , uidToText
  , textToUid
    -- * Assignment
  , assignUids
    -- * TeX comment format
  , uidComment
  , parseUidComment
  ) where

import Data.Char  (isAlphaNum)
import Data.Maybe (mapMaybe)
import Data.Text  (Text)

import qualified Data.Text as T

import Semtex.Types (Atom(..), Uid(..))

-- ---------------------------------------------------------------------------
-- Base-35 alphabet: 0-9, A-Z minus O
-- ---------------------------------------------------------------------------

-- | The base-35 alphabet: 0123456789ABCDEFGHIJKLMNPQRSTUVWXYZ
-- (letters A-Z with O removed to avoid confusion with 0).
base35Alphabet :: [Char]
base35Alphabet =
  ['0'..'9'] ++ ['A'..'N'] ++ ['P'..'Z']

-- | Number of symbols in our base.
base :: Int
base = length base35Alphabet  -- 35

-- | Convert a character to its base-35 digit value.
-- Returns Nothing for invalid characters.
charToDigit :: Char -> Maybe Int
charToDigit c = lookup c (zip base35Alphabet [0..])

-- | Convert a digit value (0-34) to its base-35 character.
digitToChar :: Int -> Char
digitToChar n = base35Alphabet !! n

-- ---------------------------------------------------------------------------
-- Tag operations
-- ---------------------------------------------------------------------------

-- | The initial UID: "0000".
initialUid :: Uid
initialUid = Uid "0000"

-- | Compute the next UID in sequence.
-- Increments the base-35 number, extending width if needed.
--
-- >>> nextUid (Uid "0000")
-- Uid "0001"
-- >>> nextUid (Uid "000Z")
-- Uid "0010"
-- >>> nextUid (Uid "ZZZZ")
-- Uid "10000"
nextUid :: Uid -> Uid
nextUid (Uid t) =
  let digits = mapMaybe charToDigit (T.unpack t)
      incremented = incrementDigits digits
  in  Uid (T.pack (map digitToChar incremented))

-- | Increment a list of base-35 digits (most significant first).
incrementDigits :: [Int] -> [Int]
incrementDigits [] = [1]
incrementDigits ds =
  let (front, lastD) = (init ds, last ds)
      nextD = lastD + 1
  in  if nextD >= base
        then incrementDigits front ++ [0]
        else front ++ [nextD]

-- | Convert a UID to its text representation.
uidToText :: Uid -> Text
uidToText = unUid

-- | Parse a text string as a UID. Validates that all characters are
-- in the base-35 alphabet.
textToUid :: Text -> Maybe Uid
textToUid t
  | T.null t = Nothing
  | T.all isValidChar t = Just (Uid (T.toUpper t))
  | otherwise = Nothing
  where
    isValidChar c = isAlphaNum c && c /= 'O' && c /= 'o'

-- ---------------------------------------------------------------------------
-- Assignment
-- ---------------------------------------------------------------------------

-- | Assign UIDs to atoms that don't have one yet.
-- Returns the updated next UID and the atoms with UIDs filled in.
assignUids :: Uid -> [Atom] -> (Uid, [Atom])
assignUids startUid atoms = go startUid [] atoms
  where
    go uid acc [] = (uid, reverse acc)
    go uid acc (a : as) =
      case atomUid a of
        Just _  -> go uid (a : acc) as
        Nothing ->
          let a' = a { atomUid = Just uid }
          in  go (nextUid uid) (a' : acc) as

-- ---------------------------------------------------------------------------
-- TeX comment format
-- ---------------------------------------------------------------------------

-- | Generate a TeX comment line for a UID: @% semtex-uid: 0014@
uidComment :: Uid -> Text
uidComment uid = "% semtex-uid: " <> unUid uid

-- | Parse a TeX comment line for a UID.
-- Returns the UID if the line matches @% semtex-uid: XXXX@.
parseUidComment :: Text -> Maybe Uid
parseUidComment line =
  let stripped = T.strip line
  in  case T.stripPrefix "% semtex-uid:" stripped of
        Just rest -> textToUid (T.strip rest)
        Nothing   -> Nothing
