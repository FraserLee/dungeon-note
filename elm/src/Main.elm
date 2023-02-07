port module Main exposing ( main )

import Bindings exposing (..)

import Browser
import Browser.Events exposing (onMouseMove, onKeyDown)
import Browser.Dom exposing (getElement)

import Css
import Tailwind.Utilities as Tw
import FeatherIcons

import Html.Styled exposing (Html, div, span, p, text, h1, h2, h3, h4, h5, h6
                                 , b, i, u, s, a, img, code, li, ol, ul
                                 , blockquote, br, hr)

import Html.Styled.Attributes as Attributes exposing (css)
import Html.Styled.Events as Events

import Json.Decode as Decode exposing (Decoder, field)

import Task

import Http

import Dict exposing (Dict)

------------------------------------- ports ------------------------------------

port fileChange : (String -> msg) -> Sub msg

---------------------------------- model types ---------------------------------

type Model = Loading 
           | Loaded (PersistentState, VolatileState)
           | Failed Http.Error

type alias PersistentState = Document

type alias ElementId = String

type ElementState = ESText TextBoxState
type TextBoxState = ViewState | EditState TextBoxEditState
type TextBoxEditState = Base | Drag { iconMouseOffsetX : Float, iconMouseOffsetY : Float }

type alias MousePos = { x : Float, y : Float }

type alias VolatileState = { anchorPos : { x : Float, y : Float }
                           , mousePos : MousePos
                           , elements : Dict ElementId ElementState
                           , canSelectText : Int -- 0 = yes, 1+ = no
                           }

--------------------------------- message types --------------------------------

type ElementMsg_temp = Select | DragStart | DragStop 

type Msg = LoadDocument (Result Http.Error PersistentState)
         | SetAnchorPos { x : Float, y : Float }
         | ElementMsg (ElementId, ElementMsg_temp)
         | Deselect
         | MouseMove MousePos
         | Posted (Result Http.Error ()) -- not used, but required by Http.post
         | FileChange

init : () -> (Model, Cmd Msg)
init _ = (Loading, fetchData)

------------------------------------- load -------------------------------------

fetchData : Cmd Msg
fetchData = Http.get { url = "/fetch", expect = Http.expectJson LoadDocument documentDecoder }

loadAnchorPos : Cmd Msg
loadAnchorPos = getElement "anchor-div" 
       -- map from a task returning an element to a task returning a SetAnchorPos message
       |> Task.map (\el -> SetAnchorPos { x = el.element.x, y = el.element.y })
       -- add a continuation to unpack the result into a value, converting the task to a command
       |> Task.attempt (\res -> case res of
            Ok ap -> ap
            Err er ->
                -- let _ = Debug.log "Failed to load anchor position" er in
                SetAnchorPos { x = 0, y = 0 })


------------------------------------- logic ------------------------------------

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (model, msg) of

        -------------------- load document, update volatiles -------------------

        (_, LoadDocument (Ok data)) -> (
                Loaded ( data, 
                    { anchorPos = { x = 0, y = 0 }
                    , mousePos = { x = 0, y = 0 }
                    , elements = Dict.map (\_ _ -> ESText ViewState) data.elements
                    , canSelectText = 0
                    }
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

        -- I'm not entirely sure what could invalidate the anchor position
        -- (definitely window resize, but possibly some other things) so I'll
        -- just reload it with each mouse move till performance becomes an
        -- issue

        (Loaded (doc, volatiles), MouseMove p) -> (
                Loaded <| updateMouseMove p (doc, { volatiles | mousePos = p }),
                loadAnchorPos
            )

        ------------------------------- selection ------------------------------

        (Loaded (doc, volatiles), Deselect) ->
            -- let _ = Debug.log "deselect" "" in

            let processBox key (s, d) = case (s, d) of 
                    (ESText state, TextBox data) -> (ESText ViewState, d)
                    _ -> (s, d)

                (vElements, dElements) = unzip <| Dict.map processBox (zip volatiles.elements doc.elements)

            in (Loaded ({ doc | elements = dElements }
                      , { volatiles | elements = vElements }
               ), Cmd.none)

        (Loaded (doc, volatiles), ElementMsg (target, selectMode)) ->
            -- let _ = Debug.log "select:" selectMode in
            let processBox key (s, d) cs = case (s, d) of 
                    (ESText state, TextBox data) ->
                        if key /= target then ((s, d), cs)
                        else case (selectMode, state) of

                            (Select, ViewState) -> ((ESText (EditState Base), d), cs)

                            (DragStart, EditState Base) ->
                                ((ESText (EditState (Drag { 
                                    iconMouseOffsetX = volatiles.mousePos.x - data.x - volatiles.anchorPos.x,
                                    iconMouseOffsetY = volatiles.mousePos.y - data.y - volatiles.anchorPos.y
                                } )), d), cs)

                            -- when we stop dragging a box, report its new state back down to the server
                            (DragStop, EditState (Drag _)) -> ((ESText (EditState Base), d), (updateElement doc.created key d) :: cs)

                            _ -> ((s, d), cs)
                    _ -> ((s, d), cs)

                (elements, changes) = mapAccum processBox (zip volatiles.elements doc.elements) []
                (vElements, dElements) = unzip elements

                -- if we're dragging something, don't allow text selection
                canSelectText = volatiles.canSelectText + case selectMode of
                    DragStart -> 1
                    DragStop -> -1
                    _ -> 0

            in (Loaded ({ doc | elements = dElements }
                      , { volatiles | elements = vElements, canSelectText = canSelectText }
               ), Cmd.batch changes)


        -- fall-through (just do nothing, probably tried to act while document loading) 
        _ -> (model, Cmd.none)


updateMouseMove : MousePos -> (PersistentState, VolatileState) -> (PersistentState, VolatileState)
updateMouseMove {x, y} (doc, volatiles) =
            -- let _ = Debug.log "MouseMove:" (x, y) in

            -- mapAccum : (k -> v -> a -> (v, a)) -> Dict k v -> a -> (Dict k v, a)

            -- if a box is selected and in drag mode, update its position
            let processBox _ (s, d) = case (s, d) of
                    (ESText (EditState (Drag { iconMouseOffsetX, iconMouseOffsetY })), TextBox data) ->
                        let x1 = x - volatiles.anchorPos.x - iconMouseOffsetX
                            y1 = y - volatiles.anchorPos.y - iconMouseOffsetY
                        in (s, TextBox { data | x = x1, y = y1 })
                    _ -> (s, d)


                (vElements, dElements) = unzip <| Dict.map processBox <| zip volatiles.elements doc.elements

                doc1 = { doc | elements = dElements }
                volatiles1 = { volatiles | elements = vElements }

            in (doc1, volatiles1)


------------------------------------- view -------------------------------------


view : Model -> Html Msg
view model =
    case model of
        -- Failed err -> text ("Failed to load data: " ++ (Debug.toString err))
        Failed err -> text "Failed to load data."

        Loading -> 
            div [ css [ Tw.absolute, Tw.inset_0, Tw.flex, Tw.items_center, Tw.justify_center ] ]
                [ h2 [ css [ Tw.text_center, Tw.opacity_25 ] ] [ text "loading..." ] ]

        Loaded (doc, vol) ->
              let textBoxesHtml = List.map viewElement (Dict.toList <| zip doc.elements vol.elements)
                  textSelection = if vol.canSelectText > 0 then [Tw.select_none] else []
              in div [ css (textSelection ++ [ Tw.top_0, Tw.w_full, Tw.h_screen ]) ]
                     [ div [ Attributes.id "anchor-div", css [ Tw.top_0, Tw.absolute, Css.left (Css.vw 50) ] ]
                         textBoxesHtml
                     ]

viewElement : (ElementId, (Element, ElementState)) -> Html Msg
viewElement (k, (e, s)) = 
    case (s, e) of
        (ESText state, TextBox data) -> viewTextBox (k, (data, state))
        _ -> text "todo: handle other element types"

viewTextBox : (ElementId, ({ x : Float, y : Float, width : Float, data : List (TextBlock) }, TextBoxState)) -> Html Msg
viewTextBox (k, (data, state)) =

    let dragIcon = div [ css [ Tw.text_white, Tw.cursor_move
                             , Css.width (Css.pct 86), Css.height (Css.pct 86) ] ] 
                       [ FeatherIcons.move 
                       |> FeatherIcons.withSize 100
                       |> FeatherIcons.withSizeUnit "%"
                       |> FeatherIcons.toHtml [] |> Html.Styled.fromUnstyled ]

        dragBox = div [ css <| [ Tw.flex, Tw.justify_center, Tw.items_center
                               , Css.width (Css.px 20), Css.height (Css.px 20) ]
                               ++ (case state of
                                       EditState (Drag _) -> [ Tw.bg_red_500 ]
                                       _ -> [ Tw.bg_black, Css.hover [ Tw.bg_red_700 ] ] )
                      ] [ dragIcon ]

        -- invisible selector that's a bit bigger than the icon itself
        dragWidgetCss = [ Tw.absolute, Tw.flex, Tw.justify_center, Tw.items_center
                        , Tw.bg_transparent, Tw.cursor_move
                        , Css.top (Css.px -20), Css.left (Css.px -20)
                        , Css.width (Css.px 40), Css.height (Css.px 40)
                        , Css.zIndex (Css.int 10) ]

        dragWidget = div [ css dragWidgetCss
                         , Events.onMouseDown (ElementMsg (k, DragStart))
                         , Events.onMouseUp (ElementMsg (k, DragStop))] [ dragBox ]

    in let style = css <| [ Tw.absolute, Css.width (Css.px data.width), Css.left (Css.px data.x), Css.top (Css.px data.y)] 
                 ++ case state of
                      ViewState -> [ Tw.border_2, Tw.border_dashed, Css.borderColor (Css.hex "00000000"), Tw.px_4 ]
                      EditState _ -> [ Tw.border_2, Tw.border_dashed, Tw.border_red_400, Tw.px_4 ]

           contents = List.map viewTextBlock data.data 
                           ++ (case state of
                                    ViewState -> []
                                    EditState _ -> [ dragWidget ])

    in div [ style, Events.onClick (ElementMsg (k, Select)) ] contents



viewTextBlock : TextBlock -> Html Msg
viewTextBlock block = 

    let viewListItem item = case item of
            OrderedList _ -> viewTextBlock item
            UnorderedList _ -> viewTextBlock item
            _ -> li [] [viewTextBlock item]

    in case block of

        Paragraph { chunks } -> List.map viewTextChunk chunks |> p []

        Header { level, chunks } -> 
            List.map viewTextChunk chunks |> case level of
                1 -> h1 []
                2 -> h2 []
                3 -> h3 []
                4 -> h4 []
                5 -> h5 []
                6 -> h6 []
                _ -> p []

        CodeBlock { code } -> Html.Styled.pre [] [ Html.Styled.code [] [ text code ] ]

        UnorderedList { items } -> ul [] (List.map viewListItem items)

        OrderedList { items } -> ol [] (List.map viewListItem items)

        BlockQuote { inner } -> blockquote [] (List.map viewTextBlock inner)

        Image { url, alt } -> img [ Attributes.src url, Attributes.alt alt ] []

        VerticalSpace -> div [ css [ Css.height (Css.px 20) ] ] []

        HorizontalRule -> hr [] []


viewTextChunk : TextChunk -> Html Msg
viewTextChunk chunk = case chunk of
    Link { title, url }      -> a [ Attributes.href url ] <| List.map viewTextChunk title
    Code { text }            -> code [] [ Html.Styled.text text ]
    Bold { chunks }          -> b [] <| List.map viewTextChunk chunks
    Italic { chunks }        -> i [] <| List.map viewTextChunk chunks
    Strikethrough { chunks } -> s [] <| List.map viewTextChunk chunks
    Underline { chunks }     -> u [] <| List.map viewTextChunk chunks
    Text(text)               -> span [] [ Html.Styled.text text ]
    NewLine                  -> br [] []

------------------------------------ effects -----------------------------------

-- note: I'm just sending over an entire textbox at the moment, but I can probably
-- be a lot more surgical about it if need comes
updateElement : Int -> ElementId -> Element -> Cmd Msg
updateElement docCreated id data =
    -- let _ = Debug.log "Push update to server:" (id, data) in
    let url = "/update/" ++ id
        body = documentUpdateEncoder { id = id, element = data, docCreated = docCreated }
    in Http.post { body = Http.jsonBody body
                 , expect = Http.expectWhatever Posted
                 , url = url
                 }


subscriptions : Model -> Sub Msg
subscriptions _ = 
    let mouseMoveSub = onMouseMove ( Decode.map2 MousePos
            (field "pageX" Decode.float)
            (field "pageY" Decode.float)
          ) |> Sub.map MouseMove

        -- subscribe to the escape key being pressed (damn this was harder than it should have been)
        escapeSub = onKeyDown (
                Decode.field "key" 
                Decode.string |> Decode.andThen 
                (\key -> if key == "Escape" then Decode.succeed Deselect else Decode.fail "wrong key")
            )

        -- subscribe to a SSE stream to hear if the file changed
        fileSub = fileChange (\_ -> FileChange)

    in Sub.batch [ mouseMoveSub, escapeSub, fileSub ]


main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> Html.Styled.toUnstyled, subscriptions = subscriptions }

----------------------------------- util junk ----------------------------------

mapAccum : (comparable -> v -> a -> (v, a)) -> Dict comparable v -> a -> (Dict comparable v, a)
mapAccum f dict initial = Dict.foldl (\k v (dict1, acc) ->
                            let (v1, acc1) = f k v acc
                            in (Dict.insert k v1 dict1, acc1)
                        ) (Dict.empty, initial) dict

zip : Dict comparable a -> Dict comparable b -> Dict comparable (a, b)
zip dict1 dict2 = 
    Dict.foldl (\k v dict -> 
        case Dict.get k dict2 of
            Just v2 -> Dict.insert k (v, v2) dict
            Nothing -> dict
    ) Dict.empty dict1

unzip : Dict comparable (a, b) -> (Dict comparable a, Dict comparable b)
unzip dict = 
    Dict.foldl (\k (v1, v2) (dict1, dict2) -> 
        (Dict.insert k v1 dict1, Dict.insert k v2 dict2)
    ) (Dict.empty, Dict.empty) dict

