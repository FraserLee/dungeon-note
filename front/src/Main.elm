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

type alias TextBoxId = Int

type TextBoxState = ViewState | EditState

type TBMsg = UpdateWidth Float | UpdateHeight Float | UpdateX Float | UpdateY Float
type alias TextBoxMsg = (TextBoxId, TBMsg)

type alias TextBoxData = { text : String
                         , width : Float
                         , height : Float
                         , x : Float
                         , y : Float }

type alias TextBox = { data : TextBoxData
                     , state : TextBoxState
                     , id : TextBoxId }

type alias Document = { paragraphs : List TextBox }

type Model = Loading | Loaded Document | Failed Http.Error

type Msg = LoadDocument (Result Http.Error Document) | Changes (List TextBoxMsg)

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson LoadDocument decodeDocument }

decodeDocument : Decoder Document
decodeDocument = field "paragraphs" (Json.Decode.list decodeTextBox) |> Json.Decode.map Document

decodeTextBox : Decoder TextBox
-- each textbox has fields for text, width, height, x, y, and id. State should
-- default to ViewState, and the first 4 fields should be inside the inner "data"
-- field.
decodeTextBox = Json.Decode.map4 TextBox (field "data" decodeTextBoxData) ViewState (field "id" Json.Decode.int)

decodeTextBoxData : Decoder TextBoxData
decodeTextBoxData = Json.Decode.map5 TextBoxData 
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
        LoadDocument (Ok data) -> (Loaded data, Cmd.none)
        LoadDocument (Err err) -> (Failed err, Cmd.none)
        Changes msgs -> case model of
            Loaded doc -> (Loaded { doc | paragraphs = updateTextBoxes doc.paragraphs msgs }, Cmd.none)
            _ -> (model, Cmd.none)

--
-- updateTextBox : TextBox -> TextBoxMsg -> TextBox
-- updateTextBox { data, state, id } (msgId, msg) =
--     if id /= msgId then
--         { data = data, state = state, id = id }
--     else case msg of UpdateWidth w -> { data = { data | width = w }, state = state, id = id }
--                      UpdateHeight h -> { data = { data | height = h }, state = state, id = id }
--                      UpdateX x -> { data = { data | x = x }, state = state, id = id }
--                      UpdateY y -> { data = { data | y = y }, state = state, id = id }

updateTextBoxes : List TextBox -> List TextBoxMsg -> List TextBox
-- updateTextBoxes textBoxes msgs = List.map (updateTextBoxes2 msgs) textBoxes
updateTextBoxes textBoxes msgs = textBoxes

-- updateTextBoxes2 : List TextBoxMsg -> TextBox -> TextBox
-- updateTextBoxes2 msgs textBox = List.foldl updateTextBox textBox msgs

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
