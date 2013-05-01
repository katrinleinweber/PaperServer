{-# LANGUAGE DoAndIfThenElse #-}
-- Handler.View

module Handler.View where

import Import
import qualified Data.List as L

import qualified Data.Text as T
import Data.Text.Lazy.IO as TLIO

import Data.Maybe
import Control.Applicative ((<$>))
import Control.Lens

import Data.Time.Clock
import qualified Text.Blaze.Html5 as H
import Text.Blaze.Renderer.Text (renderHtml)
import Text.Blaze.Internal (preEscapedText)
import Text.Blaze.Html (preEscapedToHtml)

import Yesod.Auth

import Model.PaperReader as PR
import Model.Epub
import Handler.Utils
import Handler.Widget
import Handler.Paper
import Model.PaperP
import Handler.Render

import Text.Hamlet
import System.Directory

import qualified Parser.Paper as P 

--
-- Handlers for sending / showing the paper. 
--

getPaperRa :: PaperId -> Handler RepHtml
getPaperRa paperId = renderPaper paperId FormatA

getPaperRb :: PaperId -> Handler RepHtml
getPaperRb paperId = renderPaper paperId FormatB

getPaperTabletRa :: PaperId -> Handler RepHtml
getPaperTabletRa paperId = renderPaper paperId FormatATablet

getPaperTabletRb :: PaperId -> Handler RepHtml
getPaperTabletRb paperId = renderPaper paperId FormatBTablet

getMobilePaperRa :: PaperId -> Handler RepHtml
getMobilePaperRa paperId = renderPaper paperId FormatAMobile

getMobilePaperRb :: PaperId -> Handler RepHtml
getMobilePaperRb paperId = renderPaper paperId FormatBMobile

getDoiPaperR :: String -> String -> Handler RepHtml
getDoiPaperR pub doc = do
  email <- requireAuthId
  let doi = T.pack (pub ++ "/" ++ doc)
  res <- runDB $ selectListUser email [PaperDoi ==. doi] []
  let pp = case res of
                ((Entity id p):_) -> Just (p,id)
                _ -> Nothing
  let (orig,paperId) = fromJust pp
  getPaperRb paperId

getRawHtmlR :: PaperId -> Handler RepHtml
getRawHtmlR paperId = do
  email <- requireAuthId
  paper <- runDB $ get404 paperId
  if Just email == paperUserEmail paper then do
    let html = paperOriginalHtml paper
    return $ RepHtml $ toContent html
  else
    notFound

getEpubPaperR :: PaperId -> Handler ()
getEpubPaperR pid = do
  email <- requireAuthId
  paper <- runDB $ get404 pid
  if Just email == paperUserEmail paper then do
    let pp = paperToPaperP paper
    path <- epubFromPaper pid pp
    sendFile "application/epub+zip" path
  else
    notFound

-- history data is a separate table from paper.
doUpdateVisitHistory :: PaperId -> Paper -> Handler ()
doUpdateVisitHistory pid p = do
  time <- liftIO $ getCurrentTime
  case paperUserEmail p of
    Just email -> do
      let history = History pid HAView time (User email Nothing Nothing)
      _ <- runDB $ insert history
      return ()
    Nothing -> return ()

