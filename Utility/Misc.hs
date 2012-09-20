{- misc utility functions
 -
 - Copyright 2010-2011 Joey Hess <joey@kitenet.net>
 -
 - Licensed under the GNU GPL version 3 or higher.
 -}

module Utility.Misc where

import System.IO
import Control.Monad
import Foreign
import Data.Char
import Control.Applicative

{- A version of hgetContents that is not lazy. Ensures file is 
 - all read before it gets closed. -}
hGetContentsStrict :: Handle -> IO String
hGetContentsStrict = hGetContents >=> \s -> length s `seq` return s

{- A version of readFile that is not lazy. -}
readFileStrict :: FilePath -> IO String
readFileStrict = readFile >=> \s -> length s `seq` return s

{- Like break, but the character matching the condition is not included
 - in the second result list.
 -
 - separate (== ':') "foo:bar" = ("foo", "bar")
 - separate (== ':') "foobar" = ("foobar", "")
 -}
separate :: (a -> Bool) -> [a] -> ([a], [a])
separate c l = unbreak $ break c l
	where
		unbreak r@(a, b)
			| null b = r
			| otherwise = (a, tail b)

{- Breaks out the first line. -}
firstLine :: String -> String
firstLine = takeWhile (/= '\n')

{- Splits a list into segments that are delimited by items matching
 - a predicate. (The delimiters are not included in the segments.) -}
segment :: (a -> Bool) -> [a] -> [[a]]
segment p l = map reverse $ go [] [] l
	where
		go c r [] = reverse $ c:r
		go c r (i:is)
			| p i = go [] (c:r) is
			| otherwise = go (i:c) r is

{- Given two orderings, returns the second if the first is EQ and returns
 - the first otherwise.
 -
 - Example use:
 -
 - compare lname1 lname2 `thenOrd` compare fname1 fname2
 -}
thenOrd :: Ordering -> Ordering -> Ordering
thenOrd EQ x = x
thenOrd x _ = x
{-# INLINE thenOrd #-}

{- Wrapper around hGetBufSome that returns a String.
 -
 - The null string is returned on eof, otherwise returns whatever
 - data is currently available to read from the handle, or waits for
 - data to be written to it if none is currently available.
 - 
 - Note on encodings: The normal encoding of the Handle is ignored;
 - each byte is converted to a Char. Not unicode clean!
 -}
hGetSomeString :: Handle -> Int -> IO String
hGetSomeString h sz = do
	fp <- mallocForeignPtrBytes sz
	len <- withForeignPtr fp $ \buf -> hGetBufSome h buf sz
	map (chr . fromIntegral) <$> withForeignPtr fp (peekbytes len)
	where
		peekbytes :: Int -> Ptr Word8 -> IO [Word8]
		peekbytes len buf = mapM (peekElemOff buf) [0..pred len]
