module Main exposing (..)

------------------------------------ imports -----------------------------------

import Browser
import Browser.Events exposing (onMouseMove)

import Css exposing (..)
import Tailwind.Utilities as Tw
import FeatherIcons

import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)

import Http

import Json.Decode exposing (Decoder, field, string)

import Dict exposing (Dict)

---------------------------------- model types ---------------------------------

type alias TextBox = (TextBoxState, TextBoxData)
type TextBoxState = ViewState | EditState
type alias TextBoxId = String
type alias TextBoxData = { text : String
                         , width : Float
                         , x : Float
                         , y : Float }


type alias Document = Dict String TextBox

type Model = Loading | Loaded Document | Failed Http.Error

--------------------------------- message types --------------------------------

type TBMsg = UpdateWidth Float | UpdateX Float | UpdateY Float
type alias TextBoxMsg = (TextBoxId, TBMsg)

type SelectMsg = Select TextBoxId | Deselect

type alias MouseMoveMsg = { x : Int, y : Int }

type Msg = LoadDocument (Result Http.Error Document) 
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

decodeDocument : Decoder Document
decodeDocument = Json.Decode.dict decodeTextBox

decodeTextBox : Decoder TextBox
decodeTextBox = Json.Decode.map2 Tuple.pair (Json.Decode.succeed ViewState) decodeTextBoxData

decodeTextBoxData : Decoder TextBoxData
decodeTextBoxData =
    Json.Decode.map4 TextBoxData
        (field "text" string)
        (field "width" Json.Decode.float)
        (field "x" Json.Decode.float)
        (field "y" Json.Decode.float)

------------------------------------- logic ------------------------------------

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (model, msg) of

        ----------------------------- load document ----------------------------
        (_, LoadDocument (Ok data)) -> (Loaded data, Cmd.none)
        (_, LoadDocument (Err err)) -> (Failed err, Cmd.none)


        ------------------------------- selection ------------------------------
        (Loaded doc, SelectBox Deselect) -> 
            let _ = Debug.log "deselect" () in
            (Loaded (Dict.map (\_ (_, data) -> (ViewState, data)) doc), Cmd.none)

        (Loaded doc, SelectBox (Select id)) ->
            let _ = Debug.log "select" id
                updateBox key (_, data) =  -- turn box to either selected or deselected
                    if key == id then (EditState, data)
                    else (ViewState, data)
            in (Loaded (Dict.map updateBox doc), Cmd.none)


        ------------------------------ modify data -----------------------------
        (Loaded doc, Changes msgs) ->

            let _ = Debug.log "Changes:" msgs

                updateBox data m = -- update one textbox data
                    case m of
                        UpdateWidth w -> { data | width = w }
                        UpdateX x -> { data | x = x }
                        UpdateY y -> { data | y = y }

                -- apply one message to the document
                apply (id, m) doc1 = Dict.update id (Maybe.map (\(state, data) -> (state, updateBox data m))) doc1


            -- apply all messages one by one
            in (Loaded (List.foldr apply doc msgs), Cmd.none)

        ------------------------------ mouse move ------------------------------

        (Loaded doc, MouseMove { x, y }) ->
            let _ = Debug.log "MouseMove:" (x, y)

                updateBox key (state, data) =  -- turn box to either selected or deselected
                    case state of
                        ViewState -> (state, data)
                        EditState -> (state, { data | x = toFloat x, y = toFloat y })

            in (Loaded (Dict.map updateBox doc), Cmd.none)

        -- fall-through (just do nothing, probably tried to act while document loading) 
        _ -> (model, Cmd.none)


------------------------------------- view -------------------------------------


view : Model -> Html Msg
view model =
    case model of
        Failed err -> text ("Failed to load data: " ++ (Debug.toString err))
        Loading -> text "Loading..."
        -- Loaded d -> FeatherIcons.chevronsLeft |> FeatherIcons.toHtml [] |> fromUnstyled
        Loaded d ->
              let textBoxesHtml = List.map viewTextBox (Dict.toList d)
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
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
subscriptions model =
    onMouseMove ( Json.Decode.map2 MouseMoveMsg
        (field "pageX" Json.Decode.int)
        (field "pageY" Json.Decode.int)
    ) |> Sub.map MouseMove

    -- case model of
    --     Loaded _ -> onMouseMove (Json.Decode.map2 MouseMove
    --                                 (Json.Decode.field "pageX" Json.Decode.int)
    --                                 (Json.Decode.field "pageY" Json.Decode.int))
    --     _ -> Sub.none







main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = subscriptions }











