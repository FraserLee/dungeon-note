module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Json.Decode exposing (Decoder, field, int, string)

type alias Document = { paragraphs : List String }

type Model = Loading | Loaded Document | Failed Http.Error
type Msg = GotData (Result Http.Error (Document))

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson GotData decodeDocument }

decodeDocument : Decoder Document
decodeDocument = field "text" (Json.Decode.list string) |> Json.Decode.map Document

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        GotData (Ok data) -> (Loaded data, Cmd.none)
        GotData (Err err) -> (Failed err, Cmd.none)

view : Model -> Html Msg
view model =
    case model of
        Loading -> text "Loading..."
        Loaded d ->
            let textBoxesHtml = List.map (\t -> p [] [ text t ]) d.paragraphs
                header = h1 [] [ text "elm test." ]
            in div [] [ header, div [] textBoxesHtml ]
        Failed err -> text "Failed to load data."

main = Browser.element { init = init, update = update, view = view, subscriptions = \_ -> Sub.none }
