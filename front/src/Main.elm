module Main exposing (..)

------------------------------------ imports -----------------------------------

import Browser
import Browser.Events exposing (onMouseMove, onKeyDown)
import Browser.Dom exposing (..)

import Css exposing (..)
import Tailwind.Utilities as Tw
-- import FeatherIcons

import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, id)
import Html.Styled.Events exposing (onClick)

import Task

import Http

import Json.Decode as Decode exposing (Decoder, field, string)

import Dict exposing (Dict)

---------------------------------- model types ---------------------------------

type alias TextBox = (TextBoxState, TextBoxData)
type TextBoxState = ViewState | EditState
type alias TextBoxId = String
type alias TextBoxData = { text : String
                         , width : Float
                         , x : Float
                         , y : Float }

type alias AnchorPos = { x : Float, y : Float }

type alias VolatileState = { anchorPos : AnchorPos }

type alias PersistentState = { textBoxes : Dict TextBoxId TextBox }

type Model = Loading 
           | Loaded (PersistentState, VolatileState)
           | Failed Http.Error

--------------------------------- message types --------------------------------

type TBMsg = UpdateWidth Float | UpdateX Float | UpdateY Float
type alias TextBoxMsg = (TextBoxId, TBMsg)

type SelectMsg = Select TextBoxId | Deselect

type alias MouseMoveMsg = { x : Float, y : Float }

type Msg = LoadDocument (Result Http.Error PersistentState)
         | SetAnchorPos AnchorPos
         | Changes (List TextBoxMsg) 
         | SelectBox SelectMsg
         | MouseMove MouseMoveMsg

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson LoadDocument decodeDocument }

-- { "0" : { ... first paragraph data ... }, "1" : { ... second paragraph data ... } }
-- not completely sure how to parse the keys back into ints, so I'll leave it for now

decodeDocument : Decoder PersistentState
decodeDocument = Decode.dict decodeTextBox |> Decode.map PersistentState

decodeTextBox : Decoder TextBox
decodeTextBox = Decode.map2 Tuple.pair (Decode.succeed ViewState) decodeTextBoxData

decodeTextBoxData : Decoder TextBoxData
decodeTextBoxData =
    Decode.map4 TextBoxData
        (field "text" string)
        (field "width" Decode.float)
        (field "x" Decode.float)
        (field "y" Decode.float)


loadAnchorPos : Cmd Msg
loadAnchorPos = getElement "anchor-div" 
       -- map from a task returning an element to a task returning a SetAnchorPos message
       |> Task.map (\el -> SetAnchorPos { x = el.element.x, y = el.element.y })
       -- add a continuation to unpack the result into a value, converting the task to a command
       |> Task.attempt (\res -> case res of
            Ok ap -> ap
            Err er ->
                let _ = Debug.log "Failed to load anchor position" er in
                SetAnchorPos { x = 0, y = 0 })

------------------------------------- logic ------------------------------------


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (model, msg) of

        -------------------- load document, update volatiles -------------------

        (_, LoadDocument (Ok data)) -> (Loaded (data, { anchorPos = { x = 0, y = 0 } }), Cmd.batch [loadAnchorPos])
        (_, LoadDocument (Err err)) -> (Failed err, Cmd.none)

        (_, SetAnchorPos pos) -> 
                -- let _ = Debug.log "anchor pos" pos in 
                case model of
                    Loaded (data, _) -> (Loaded (data, { anchorPos = pos }), Cmd.none)
                    _ -> (model, Cmd.none)


        ------------------------------- selection ------------------------------
        (Loaded (doc, volatile), SelectBox Deselect) ->
            let _ = Debug.log "deselect" () in
            let textBoxes = Dict.map (\_ (_, data) -> (ViewState, data)) doc.textBoxes
            in (Loaded ({ doc | textBoxes = textBoxes }, volatile), Cmd.none)


        (Loaded (doc, volatile), SelectBox (Select id)) ->
            let _ = Debug.log "select" id in
            let updateBox key (_, data) =  -- turn box to either selected or deselected
                    if key == id then (EditState, data)
                    else (ViewState, data)
                textBoxes = Dict.map updateBox doc.textBoxes
            in (Loaded ({ doc | textBoxes = textBoxes }, volatile), Cmd.none)


        ------------------------------ modify data -----------------------------
        (Loaded (doc, volatile), Changes cs) ->
            let _ = Debug.log "Changes:" cs in
            let updateBox data m = -- update one textbox data
                    case m of
                        UpdateWidth w -> { data | width = w }
                        UpdateX x -> { data | x = x }
                        UpdateY y -> { data | y = y }

                -- apply one message to the document
                apply (id, m) tb = Dict.update id (Maybe.map (\(state, data) -> (state, updateBox data m))) tb

                -- apply all messages one by one
                textBoxes = List.foldl apply doc.textBoxes cs

            in (Loaded ({ doc | textBoxes = textBoxes }, volatile), Cmd.none)

        ------------------------------ mouse move ------------------------------

        (Loaded (doc, volatile), MouseMove { x, y }) ->
            -- let _ = Debug.log "MouseMove:" (x, y) in
            let updateBox _ (state, data) =  -- turn box to either selected or deselected
                    case state of
                        ViewState -> (state, data)
                        EditState -> 
                            -- let (x1, y1) = pageToCoords (x, y) in
                            let (x1, y1) = (x - volatile.anchorPos.x, y - volatile.anchorPos.y) in
                            (state, { data | x = x1, y = y1 })

                textBoxes = Dict.map updateBox doc.textBoxes

            -- I'm not entirely sure what could invalidate the anchor position
            -- (definitely window resize, but possibly some other things) so
            -- I'll just reload it with each mouse move till performance
            -- becomes an issue

            in (Loaded ({ doc | textBoxes = textBoxes }, volatile), loadAnchorPos)

        -- fall-through (just do nothing, probably tried to act while document loading) 
        _ -> (model, Cmd.none)


------------------------------------- view -------------------------------------


view : Model -> Html Msg
view model =
    case model of
        Failed err -> text ("Failed to load data: " ++ (Debug.toString err))
        Loading -> text "Loading..."
        -- Loaded d -> FeatherIcons.chevronsLeft |> FeatherIcons.toHtml [] |> fromUnstyled
        Loaded (doc, _) ->
              let textBoxesHtml = List.map viewTextBox (Dict.toList doc.textBoxes)
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ id "anchor-div", css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
                         textBoxesHtml
                     ]

viewTextBox : (TextBoxId, TextBox) -> Html Msg
viewTextBox (k, (state, data)) =
    let colour = case state of
            ViewState -> Tw.bg_opacity_0
            EditState -> Tw.bg_red_400
        width = Css.width (px data.width)
        x = Css.left (px data.x)
        y = Css.top (px data.y)
        style = css [ Tw.absolute, width, x, y, colour ]
    -- in div [ style, onClick (Changes [ ( k, UpdateWidth (data.width + 10)) ]) ] [ text data.text ]
    in div [ style, onClick (SelectBox (Select k)) ] [ text data.text ]


--------------------------------- subscriptions --------------------------------

subscriptions : Model -> Sub Msg
subscriptions _ = 
    let mouseMove = onMouseMove ( Decode.map2 MouseMoveMsg
            (field "pageX" Decode.float)
            (field "pageY" Decode.float)
          ) |> Sub.map MouseMove

        -- subscribe to the escape key being pressed (damn this was harder than it should have been)
        escape = Sub.map SelectBox <| onKeyDown (
                Decode.field "key" 
                Decode.string |> Decode.andThen 
                (\key -> if key == "Escape" then Decode.succeed Deselect else Decode.fail "wrong key")
            )

    in Sub.batch [ mouseMove, escape ]



main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = subscriptions }




