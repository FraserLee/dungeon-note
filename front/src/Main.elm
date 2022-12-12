module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Json.Decode exposing (Decoder, map4, field, int, string)

type Model = Loading | Loaded (List String)
type Msg = GotData (Result Http.Error (List String))

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson GotData decodeData }

-- get from JSON "text" field - a list of strings
decodeData : Decoder (List String)
decodeData = field "text" (Json.Decode.list string)

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        GotData (Ok data) -> (Loaded data, Cmd.none)
        GotData (Err _) -> (Loaded ["some error"], Cmd.none)

view : Model -> Html Msg
view model =
    case model of
        Loading -> text "Loading..."
        Loaded textBoxes ->
            let textBoxesHtml = List.map (\t -> p [] [ text t ]) textBoxes
                header = h1 [] [ text "elm test." ]
            in div [] [ header, div [] textBoxesHtml ]

main = Browser.element { init = init, update = update, view = view, subscriptions = \_ -> Sub.none }
