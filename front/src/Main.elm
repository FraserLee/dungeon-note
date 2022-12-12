module Main exposing (..)

import Browser
import Html exposing (..)

type alias Model = { textBoxes : List String }
init = { textBoxes = ["foo", "bar"] }
type Msg = None

update : Msg -> Model -> Model
update msg model = model

view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "elm test." ],
          div []
            (List.map
                (\t -> p [] [ text t ])
                model.textBoxes
            )
        ]

main = Browser.sandbox { init = init, update = update, view = view }

