module Element exposing (..)

import Utils exposing (..)
import Bindings exposing (..)

import Tailwind.Utilities as Tw
import FeatherIcons

import Html.Styled exposing (Html, div, span, p, text, h1, h2, h3, h4, h5, h6
                                 , b, i, u, s, a, img, code, li, ol, ul
                                 , blockquote, br, hr)

import Html.Styled.Events as Events
import Html.Styled.Attributes as Attributes exposing (css)
-- note to self: real css z-index should be data.zIndex + 10

import Css

------------------------------------- types ------------------------------------

type alias ElementId = String

type alias MouseOffset = { offsetX : Float, offsetY : Float }

type ElementState = ESText TextBoxState | ESRect RectState

type TextBoxState = TViewState | TEditState | TDragState MouseOffset

type RectState = RViewState | REditState | RDragState (DragType, MouseOffset)
-- todo: convert into bounds based form
type DragType = DMove | DLeft -- | DRight -- | DTop | DBottom


type Msg = Select | DragStart DragType | DragStop 


------------------------------------- init -------------------------------------

initState : Element -> ElementState
initState element = case element of
    TextBox _ -> ESText TViewState
    Line _ -> ESText TViewState
    Rect _ -> ESRect RViewState

--------------------------------- update logic ---------------------------------

-- mainly phrasing these as a series of transformers on an element, with the
-- iteration logic handled in the module with the document itself.

deselect : (Element, ElementState) -> (Element, ElementState)
deselect (data, state) = case state of
    ESText _ -> (data, ESText TViewState)
    ESRect _ -> (data, ESRect RViewState)

-- if a box is selected and in drag mode, update its position
mousemove : MousePos -> AnchorPos -> (Element, ElementState) -> (Element, ElementState)
mousemove {x, y} anchorPos (data, state) = case (data, state) of

    (TextBox d, ESText (TDragState { offsetX, offsetY })) ->
        let x1 = x - anchorPos.x - offsetX
            y1 = y - anchorPos.y - offsetY
        in (TextBox { d | x = x1, y = y1 }, state)

    (Rect d, ESRect (RDragState (DMove, { offsetX, offsetY }))) ->
        let x1 = x - anchorPos.x - offsetX
            y1 = y - anchorPos.y - offsetY
        in (Rect { d | x = x1, y = y1 }, state)

    (Rect d, ESRect (RDragState (DLeft, { offsetX, offsetY }))) ->
        let x1 = x - anchorPos.x - offsetX
            y1 = y - anchorPos.y - offsetY
            w1 = d.width + d.x - x1
        in (Rect { d | x = x1, y = y1, width = w1 }, state)

    _ -> (data, state)


-- a more general update function. The last return value is whether or not we
-- need to send an update back to the server

update : MousePos -> AnchorPos -> Msg -> (Element, ElementState) -> ((Element, ElementState), Bool)
update mousePos anchorPos msg (data, state) = case (data, state) of
    (TextBox d, ESText s) -> case (msg, s) of

        (Select, TViewState) -> ((data, ESText TEditState), False)

        (DragStart _, TEditState) ->
            ((data, ESText (TDragState { 
                offsetX = mousePos.x - d.x - anchorPos.x,
                offsetY = mousePos.y - d.y - anchorPos.y
            } )), False)

        -- when we stop dragging a box, report its new state back down to the server
        (DragStop, TDragState _) -> ((data, ESText TEditState), True)

        _ -> ((data, state), False)

    (Rect d, ESRect s) ->
        let _ = Debug.log "rect" (msg, s) in

        case (msg, s) of

        (Select, RViewState) -> ((data, ESRect REditState), False)

        (DragStart dType, REditState) ->
            ((data, ESRect (RDragState (dType, {
                offsetX = mousePos.x - d.x - anchorPos.x,
                offsetY = mousePos.y - d.y - anchorPos.y
            }) )), False)

        -- when we stop dragging a box, report its new state back down to the server
        (DragStop, RDragState _) -> ((data, ESRect REditState), True)

        _ -> ((data, state), False)

    _ -> ((data, state), False)

------------------------------------- view -------------------------------------

viewElement : (ElementId -> Msg -> msg) -> (ElementId, (Element, ElementState)) -> Html msg
viewElement converter (k, (e, s)) = 
    case (s, e) of
        (ESText state, TextBox data) -> viewTextBox converter (k, (data, state))
        (ESRect state, Rect data) -> viewRect converter (k, (data, state))
        _ -> text "other object types not yet implemented"










--------------------------------- markdown view --------------------------------

viewTextBox : (ElementId -> Msg -> msg) -> (ElementId, ({ x : Float, y : Float, width : Float, data : List (TextBlock) }, TextBoxState)) -> Html msg
viewTextBox converter (k, (data, state)) =

    let dragIcon = div [ css [ Tw.text_white, Tw.cursor_move
                             , Css.width (Css.pct 86), Css.height (Css.pct 86) ] ] 
                       [ FeatherIcons.move 
                       |> FeatherIcons.withSize 100
                       |> FeatherIcons.withSizeUnit "%"
                       |> FeatherIcons.toHtml [] |> Html.Styled.fromUnstyled ]

        dragBox = div [ css <| [ Tw.flex, Tw.justify_center, Tw.items_center
                               , Css.width (Css.px 20), Css.height (Css.px 20) ]
                               ++ (case state of
                                       TDragState _ -> [ Tw.bg_red_500 ]
                                       _ -> [ Tw.bg_black, Css.hover [ Tw.bg_red_700 ] ] )
                      ] [ dragIcon ]

        -- invisible selector that's a bit bigger than the icon itself
        dragWidgetCss = [ Tw.absolute, Tw.flex, Tw.justify_center, Tw.items_center
                        , Tw.bg_transparent, Tw.cursor_move
                        , Css.top (Css.px -20), Css.left (Css.px -20)
                        , Css.width (Css.px 40), Css.height (Css.px 40)
                        , Css.zIndex (Css.int 5) ]

        dragWidget = div [ css dragWidgetCss
                         , Events.onMouseDown (converter k (DragStart DMove))
                         , Events.onMouseUp (converter k DragStop)] [ dragBox ]

    in let style = css <| [ Tw.absolute, Css.width (Css.px data.width), Css.left (Css.px data.x), Css.top (Css.px data.y), Css.zIndex (Css.int 10) ]
                 ++ case state of
                      TViewState -> [ Tw.border_2, Tw.border_dashed, Css.borderColor (Css.hex "00000000"), Tw.px_4 ]
                      _ -> [ Tw.border_2, Tw.border_dashed, Tw.border_red_400, Tw.px_4 ]

           contents = List.map viewTextBlock data.data 
                           ++ (case state of
                                    TViewState -> []
                                    _ -> [ dragWidget ])

    in div [ style, Events.onClick (converter k Select) ] contents



viewTextBlock : TextBlock -> Html msg
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


viewTextChunk : TextChunk -> Html msg
viewTextChunk chunk = case chunk of
    Link { title, url }      -> a [ Attributes.href url ] <| List.map viewTextChunk title
    Code { text }            -> code [] [ Html.Styled.text text ]
    Bold { chunks }          -> b [] <| List.map viewTextChunk chunks
    Italic { chunks }        -> i [] <| List.map viewTextChunk chunks
    Strikethrough { chunks } -> s [] <| List.map viewTextChunk chunks
    Underline { chunks }     -> u [] <| List.map viewTextChunk chunks
    Text(text)               -> span [] [ Html.Styled.text text ]
    NewLine                  -> br [] []


------------------------------------- rect -------------------------------------

viewRect : (ElementId -> Msg -> msg) -> (ElementId, ({ x : Float, y : Float, width : Float, height : Float, z : Int, color : String }, RectState)) -> Html msg
viewRect converter (k, (data, state)) =
    
        let style = css <| [ Tw.absolute, Css.width (Css.px data.width), Css.height (Css.px data.height)
                        , Css.left (Css.px data.x), Css.top (Css.px data.y)
                        , Css.backgroundColor (Css.hex data.color) ]
                        ++ case state of

                            RViewState -> [ Css.zIndex (Css.int (data.z + 10))
                                          , Tw.border_2, Tw.border_dashed, Css.borderColor (Css.hex "00000000"), Tw.px_4 ]

                            REditState -> [ Css.zIndex (Css.int (data.z + 10)), Tw.cursor_move
                                          , Tw.border_2, Tw.border_dashed, Tw.border_red_400, Tw.px_4 ]

                            -- increase z-index when dragging, so we don't try
                            -- to release when under another element and miss
                            -- the onMouseUp event.

                            RDragState _ -> [ Css.zIndex (Css.int (data.z + 1000)), Tw.cursor_move
                                            , Tw.border_2, Tw.border_dashed, Tw.border_red_400, Tw.px_4 ]

            events = case state of
                RViewState -> [ Events.onClick (converter k Select) ]
                _ -> [ Events.onMouseDown (converter k (DragStart DMove))
                     , Events.onMouseUp (converter k DragStop) ]

        in div (style::events) []
