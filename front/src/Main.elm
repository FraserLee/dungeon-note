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

type alias Document = { paragraphs : List String }

type Model = Loading | Loaded Document | Failed Http.Error
type Msg = GotData (Result Http.Error (Document))

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson GotData decodeDocument }

decodeDocument : Decoder Document
decodeDocument = field "text" (Json.Decode.list string) |> Json.Decode.map Document

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
              let textBoxesHtml = List.map (\t -> p [] [ text t ]) d.paragraphs
                  header = h1 [] [ text "elm test." ]
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
                         [ header, div [] textBoxesHtml ]
                     ]



main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = \_ -> Sub.none }
