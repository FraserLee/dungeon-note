module Main exposing (..)

------------------------------------ imports -----------------------------------

import Browser

import Css exposing (..)

import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)

import Http

import Json.Decode exposing (Decoder, field, int, string)


import Tailwind.Breakpoints as Breakpoints
import Tailwind.Utilities as Tw

------------------------------------- types ------------------------------------

type alias TextBox = { text : String, width : Float, height : Float, x : Float, y : Float }
type alias Document = { paragraphs : List TextBox }

type Model = Loading | Loaded Document | Failed Http.Error
type Msg = GotData (Result Http.Error (Document))

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson GotData decodeDocument }

decodeDocument : Decoder Document
decodeDocument = field "paragraphs" (Json.Decode.list decodeTextBox) |> Json.Decode.map Document

decodeTextBox : Decoder TextBox
decodeTextBox =
    Json.Decode.map5 TextBox
        (field "text" string)
        (field "width" Json.Decode.float)
        (field "height" Json.Decode.float)
        (field "x" Json.Decode.float)
        (field "y" Json.Decode.float)

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

------------------------------------- logic ------------------------------------

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        GotData (Ok data) -> (Loaded data, Cmd.none)
        GotData (Err err) -> (Failed err, Cmd.none)

------------------------------------- view -------------------------------------

view : Model -> Html Msg
view model =
    case model of
        Failed err -> text "Failed to load data." -- todo: show error
        Loading -> text "Loading..."
        Loaded d ->
              let textBoxesHtml = List.map (\t -> viewTextBox t) d.paragraphs
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
                         textBoxesHtml
                     ]

viewTextBox : TextBox -> Html Msg
viewTextBox t =
    div [ css [ Tw.absolute, Css.width (px t.width), Css.height (px t.height), left (px t.x), top (px t.y) ] ]
        [ text t.text ]



main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = \_ -> Sub.none }
