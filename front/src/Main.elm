port module Main exposing (..)

import Document exposing (..)

import Browser
import Browser.Events exposing (onMouseMove, onKeyDown)
import Browser.Dom exposing (getElement)

import Css exposing (..)
import Tailwind.Utilities as Tw
import FeatherIcons

import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, id)
import Html.Styled.Events exposing (onClick, onMouseDown, onMouseUp)

import Task

import Http

import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Encode as Encode

import Dict exposing (Dict)

------------------------------------- ports ------------------------------------

port fileChange : (String -> msg) -> Sub msg

---------------------------------- model types ---------------------------------

type Model = Loading 
           | Loaded (PersistentState, VolatileState)
           | Failed Http.Error

type alias VolatileState = { anchorPos : { x : Float, y : Float }
                           , mousePos : { x : Float, y : Float } }

--------------------------------- message types --------------------------------

type SelectMsg = Deselect | Select ElementId | DragStart ElementId | DragStop ElementId

type alias MouseMoveMsg = { x : Float, y : Float }

type Msg = LoadDocument (Result Http.Error PersistentState)
         | SetAnchorPos { x : Float, y : Float }
         | SelectBox SelectMsg
         | MouseMove MouseMoveMsg
         | Posted (Result Http.Error ()) -- not used, but required by Http.post
         | FileChange

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson LoadDocument decodePersistentState }

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

        (_, LoadDocument (Ok data)) -> (
                Loaded ( data, 
                    { anchorPos = { x = 0, y = 0 }
                    , mousePos = { x = 0, y = 0 } }
                ), Cmd.batch [loadAnchorPos])

        (_, LoadDocument (Err err)) -> (Failed err, Cmd.none)

        -- reload on hearing that the file has changed
        (_, FileChange) -> (Loading, fetchData)

        (_, SetAnchorPos pos) -> 
                -- let _ = Debug.log "anchor pos" pos in 
                case model of
                    Loaded (data, volatiles) -> (Loaded (data, { volatiles | anchorPos = pos }), Cmd.none)
                    _ -> (model, Cmd.none)


        ------------------------------ mouse move ------------------------------

        (Loaded (doc, volatile), MouseMove { x, y }) ->
            -- let _ = Debug.log "MouseMove:" (x, y) in

            -- mapAccum : (k -> v -> a -> (v, a)) -> Dict k v -> a -> (Dict k v, a)

            -- if a box is selected and in drag mode, update its position
            let processBox _ (TextBox (state, data)) = case state of

                    EditState (Drag { iconMouseOffsetX, iconMouseOffsetY }) ->
                        let x1 = x - volatile.anchorPos.x - iconMouseOffsetX
                            y1 = y - volatile.anchorPos.y - iconMouseOffsetY
                        in TextBox (state, { data | x = x1, y = y1 })
                    _ -> TextBox (state, data)

                elements = Dict.map processBox doc.elements

                doc1 = { doc | elements = elements }
                volatiles1 = { volatile | mousePos = { x = x, y = y } }

            -- I'm not entirely sure what could invalidate the anchor position
            -- (definitely window resize, but possibly some other things) so
            -- I'll just reload it with each mouse move till performance
            -- becomes an issue

            in (Loaded (doc1, volatiles1), loadAnchorPos)


        ------------------------------- selection ------------------------------

        (Loaded (doc, volatile), SelectBox selectMode) ->
            let _ = Debug.log "select:" selectMode in
            let target = case selectMode of
                    Select id -> id
                    DragStart id -> id
                    DragStop id -> id
                    Deselect -> ""

                processBox key (TextBox (state, data)) cs =
                    if selectMode == Deselect then (TextBox (ViewState, data), cs)
                    else if key /= target then (TextBox (state, data), cs)
                    else case (selectMode, state) of

                        (Select _, ViewState) -> (TextBox (EditState Base, data), cs)

                        (DragStart _, EditState Base) ->
                            (TextBox (EditState (Drag { 
                                iconMouseOffsetX = volatile.mousePos.x - data.x - volatile.anchorPos.x,
                                iconMouseOffsetY = volatile.mousePos.y - data.y - volatile.anchorPos.y
                            } ), data), cs)

                        -- when we stop dragging a box, report its new state back down to the server
                        (DragStop _, EditState (Drag _)) -> (TextBox (EditState Base, data), (updateTextBox key data) :: cs)

                        _ -> (TextBox (state, data), cs)

                (elements, changes) = mapAccum processBox doc.elements []

            in (Loaded ({ doc | elements = elements }, volatile), Cmd.batch changes)


        -- fall-through (just do nothing, probably tried to act while document loading) 
        _ -> (model, Cmd.none)


------------------------------------- view -------------------------------------


view : Model -> Html Msg
view model =
    case model of
        Failed err -> text ("Failed to load data: " ++ (Debug.toString err))

        Loading -> 
            div [ css [ Tw.absolute, Tw.inset_0, Tw.flex, Tw.items_center, Tw.justify_center ] ]
                [ h2 [ css [ Tw.text_center, Tw.opacity_25 ] ] [ text "loading..." ] ]

        Loaded (doc, _) ->
              let textBoxesHtml = List.map viewElement (Dict.toList doc.elements)
              in div [ css [ Tw.top_0, Tw.w_full, Tw.h_screen ] ]
                     [ div [ id "anchor-div", css [ Tw.top_0, Tw.absolute, left (vw 50) ] ]
                         textBoxesHtml
                     ]

viewElement : (ElementId, Element) -> Html Msg
viewElement (k, TextBox e) = viewTextBox (k, e)

viewTextBox : (ElementId, (TextBoxState, TextBoxData)) -> Html Msg
viewTextBox (k, (state, data)) =

    let dragIcon = div [ css [ Tw.text_white, Tw.cursor_move
                             , Css.width (pct 86), Css.height (pct 86) ] ] 
                       [ FeatherIcons.move 
                       |> FeatherIcons.withSize 100
                       |> FeatherIcons.withSizeUnit "%"
                       |> FeatherIcons.toHtml [] |> fromUnstyled ]

        dragBox = div [ css <| [ Tw.flex, Tw.justify_center, Tw.items_center
                               , Css.width (px 20), Css.height (px 20) ]
                               ++ (case state of
                                       EditState (Drag _) -> [ Tw.bg_red_500 ]
                                       _ -> [ Tw.bg_black, hover [ Tw.bg_red_700 ] ] )
                      ] [ dragIcon ]

        -- invisible selector that's a bit bigger than the icon itself
        dragWidget = div [ css [ Tw.absolute, Tw.flex, Tw.justify_center, Tw.items_center
                               , Tw.bg_transparent, Tw.cursor_move
                               , Css.top (px -20), Css.left (px -20)
                               , Css.width (px 40), Css.height (px 40)
                               , Css.zIndex (int 10) ] 
                         , onMouseDown (SelectBox (DragStart k))
                         , onMouseUp (SelectBox (DragStop k))] [ dragBox ]

    in let style = css <| [ Tw.absolute, Css.width (px data.width), Css.left (px data.x), Css.top (px data.y)] 
                 ++ case state of
                      ViewState -> [ Tw.border_2, Tw.border_dashed, Css.borderColor (hex "00000000"), Tw.p_4 ]
                      EditState _ -> [ Tw.border_2, Tw.border_dashed, Tw.border_red_400, Tw.p_4 ]

           contents = (viewTBElements data.textBoxElements) 
                       ++ (case state of ViewState -> []
                                         EditState _ -> [ dragWidget ])

    in div [ style, onClick (SelectBox (Select k)) ] contents

viewTBElements : List TextBoxElement -> List (Html Msg)
viewTBElements elements = 
    List.map (\e ->
        case e of
            Text s -> p [] [ text s ]
            Heading (level, s) -> case level of
                1 -> h1 [] [ text s ]
                2 -> h2 [] [ text s ]
                3 -> h3 [] [ text s ]
                4 -> h4 [] [ text s ]
                5 -> h5 [] [ text s ]
                6 -> h6 [] [ text s ]
                _ -> p [] [ text s ]
        ) elements




------------------------------------ effects -----------------------------------

-- note: I'm just sending over an entire textbox at the moment, but I can probably
-- be a lot more surgical about it if need comes
updateTextBox : ElementId -> TextBoxData -> Cmd Msg
updateTextBox id data = 
    let _ = Debug.log "Push update to server:" (id, data) in
    let url = "/update/" ++ id
        body = encodeTextBox data in
    Http.post { body = Http.jsonBody body
              , expect = Http.expectWhatever Posted
              , url = url
              }

encodeTextBox : TextBoxData -> Encode.Value
encodeTextBox { text, width, x, y } =
    Encode.object
        [ ("text", Encode.string text)
        , ("width", Encode.float width)
        , ("x", Encode.float x)
        , ("y", Encode.float y)
        ]



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

        -- subscribe to a SSE stream to hear if the file changed
        file = fileChange (\_ -> FileChange)

    in Sub.batch [ mouseMove, escape, file ]


main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> toUnstyled, subscriptions = subscriptions }

----------------------------------- util junk ----------------------------------

mapAccum : (comparable -> v -> a -> (v, a)) -> Dict comparable v -> a -> (Dict comparable v, a)
mapAccum f dict initial = Dict.foldl (\k v (dict1, acc) ->
                            let (v1, acc1) = f k v acc
                            in (Dict.insert k v1 dict1, acc1)
                        ) (Dict.empty, initial) dict

