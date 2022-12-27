module Main exposing (..)

------------------------------------ imports -----------------------------------

import Browser

import Css exposing (..)
import Tailwind.Utilities as Tw

import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick)

import Http

import Json.Decode exposing (Decoder, field, string)

import Dict exposing (Dict)

---------------------------------- model types ---------------------------------

type alias TextBoxId = String

type TextBoxState = ViewState | EditState

type alias TextBoxData = { text : String
                         , width : Float
                         , height : Float
                         , x : Float
                         , y : Float }

type alias TextBox = (TextBoxState, TextBoxData)



type alias Document = Dict String TextBox

type Model = Loading | Loaded Document | Failed Http.Error

--------------------------------- message types --------------------------------

type TBMsg = UpdateWidth Float | UpdateHeight Float | UpdateX Float | UpdateY Float
type alias TextBoxMsg = (TextBoxId, TBMsg)

type SelectMsg = Select TextBoxId | Deselect

type Msg = LoadDocument (Result Http.Error Document) | Changes (List TextBoxMsg) | SelectBox SelectMsg

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson LoadDocument decodeDocument }

-- { "0" : { ... first paragraph data ... }, "1" : { ... second paragraph data ... } }
-- not completely sure how to parse the keys back into ints, so I'll leave it for now

decodeDocument : Decoder Document
decodeDocument = Json.Decode.dict decodeTextBox

decodeTextBox : Decoder TextBox
decodeTextBox = Json.Decode.map2 Tuple.pair (Json.Decode.succeed ViewState) decodeTextBoxData

decodeTextBoxData : Decoder TextBoxData
decodeTextBoxData =
    Json.Decode.map5 TextBoxData
        (field "text" string)
        (field "width" Json.Decode.float)
        (field "height" Json.Decode.float)
        (field "x" Json.Decode.float)
        (field "y" Json.Decode.float)



------------------------------------- logic ------------------------------------

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (model, msg) of
        (_, LoadDocument (Ok data)) -> (Loaded data, Cmd.none)
        (_, LoadDocument (Err err)) -> (Failed err, Cmd.none)

        (Loaded doc, Changes msgs) -> (Loaded (applyChanges doc msgs), Cmd.none)

        (Loaded doc, SelectBox Deselect) -> 
            (Loaded (Dict.map (\_ (_, data) -> (ViewState, data)) doc), Cmd.none)

        (Loaded doc, SelectBox (Select id)) ->
            let updateBox key (_, data) = 
                    if key == id then (EditState, data)
                    else (ViewState, data)
            in (Loaded (Dict.map updateBox doc), Cmd.none)


        (_, _) -> (model, Cmd.none)


updateTextBox : TextBoxData -> TBMsg -> TextBoxData
updateTextBox data msg =
    case msg of
        UpdateWidth w -> { data | width = w }
        UpdateHeight h -> { data | height = h }
        UpdateX x -> { data | x = x }
        UpdateY y -> { data | y = y }

applyChanges : Document -> List TextBoxMsg -> Document
applyChanges doc msgs =
    List.foldl
        (\(id, msg) doc1 -> Dict.update id (Maybe.map (\(state, data) -> (state, updateTextBox data msg))) doc1)
        doc
        msgs




------------------------------------- view -------------------------------------

view : Model -> Html Msg
view model =
    case model of
        Failed err -> text "Failed to load data." -- todo: show error
        Loading -> text "Loading..."
        Loaded d ->
              let textBoxesHtml = List.map viewTextBox (Dict.toList d)
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
                         textBoxesHtml
                     ]

viewTextBox : (TextBoxId, TextBox) -> Html Msg
viewTextBox (k, (state, data)) =
    let colour = case state of
            ViewState -> Tw.bg_gray_200
            EditState -> Tw.bg_gray_300
        width = Css.width (px data.width)
        height = Css.height (px data.height)
        x = Css.left (px data.x)
        y = Css.top (px data.y)
        style = css [ Tw.absolute, width, height, x, y, colour ]
    -- in div [ style, onClick (Changes [ ( k, UpdateWidth (data.width + 10)) ]) ] [ text data.text ]
    in div [ style, onClick (SelectBox (Select k)) ] [ text data.text ]


main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = \_ -> Sub.none }
