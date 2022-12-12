module Main exposing (..)

import Browser
import Html exposing (..)
import Http
import Json.Decode exposing (Decoder, map4, field, int, string)

type Model = Loading | Loaded (List String)
type Msg = None

init = Loading

update : Msg -> Model -> Model
update _ model = model

view : Model -> Html Msg
view model =
    case model of
        Loading -> text "Loading..."
        Loaded textBoxes ->
            let textBoxesHtml = List.map (\t -> p [] [ text t ]) textBoxes
                header = h1 [] [ text "elm test." ]
            in div [] [ header, div [] textBoxesHtml ]

main = Browser.sandbox { init = init, update = update, view = view }
