{-# LANGUAGE CPP, OverloadedStrings #-}
-- |
-- Module      : Criterion.IO
-- Copyright   : (c) 2009-2014 Bryan O'Sullivan
--
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : GHC
--
-- Input and output actions.

module Criterion.IO
    (
      header
    , hGetRecords
    , hPutRecords
    , readRecords
    , writeRecords
    ) where

import Data.Binary (Binary(..), encode)
#if MIN_VERSION_binary(0, 6, 3)
import Data.Binary.Get (runGetOrFail)
#else
import Data.Binary.Get (runGetState)
#endif
import Data.Binary.Put (putByteString, putWord16be, runPut)
import Data.ByteString.Char8 ()
import Data.Version (Version(..))
import Paths_criterion (version)
import System.IO (Handle, IOMode(..), withFile)
import qualified Data.ByteString.Lazy as L

-- | The header identifies a criterion data file. This contains
-- version information; there is no expectation of cross-version
-- compatibility.
header :: L.ByteString
header = runPut $ do
  putByteString "criterio"
  mapM_ (putWord16be . fromIntegral) (versionBranch version)

-- | Read all records from the given 'Handle'.
hGetRecords :: Binary a => Handle -> IO (Either String [a])
hGetRecords handle = do
  bs <- L.hGet handle (fromIntegral (L.length header))
  if bs == header
    then Right `fmap` readAll handle
    else return $ Left $ "unexpected header, expected criterion version: "++show (versionBranch version)

-- | Write records to the given 'Handle'.
hPutRecords :: Binary a => Handle -> [a] -> IO ()
hPutRecords handle rs = do
  L.hPut handle header
  mapM_ (L.hPut handle . encode) rs

-- | Read all records from the given file.
readRecords :: Binary a => FilePath -> IO (Either String [a])
readRecords path = withFile path ReadMode hGetRecords

-- | Write records to the given file.
writeRecords :: Binary a => FilePath -> [a] -> IO ()
writeRecords path rs = withFile path WriteMode (flip hPutRecords rs)

#if MIN_VERSION_binary(0, 6, 3)
readAll :: Binary a => Handle -> IO [a]
readAll handle = do
  let go bs
         | L.null bs = return []
         | otherwise = case runGetOrFail get bs of
                         Left (_, _, err) -> fail err
                         Right (bs', _, a) -> (a:) `fmap` go bs'
  go =<< L.hGetContents handle
#else
readAll :: Binary a => Handle -> IO [a]
readAll handle = do
  let go i bs
         | L.null bs = return []
         | otherwise =
            let (a, bs', i') = runGetState get bs i
             in (a:) `fmap` go i' bs'
  go 0 =<< L.hGetContents handle
#endif
