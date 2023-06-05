module Element exposing (..)

import Utils exposing (..)
import Bindings exposing (..)

import Tailwind.Utilities as Tw

import Html.Styled exposing (Html, div, span, p, text, h1, h2, h3, h4, h5, h6
                                 , b, i, u, s, a, img, code, li, ol, ul
                                 , blockquote, br, hr)

import Html.Styled as Styled
import Html.Styled.Events as Events
import Html.Styled.Attributes as Attributes exposing (css)
-- note to self: real css z-index should be data.zIndex + 10

import Css

import Html.Attributes

----------------------------------- constants ----------------------------------

rectMinWidth : Float
rectMinWidth = 20

resizeRegionSize : Float
resizeRegionSize = 10

------------------------------------- types ------------------------------------

type alias ElementId = String

type alias MouseOffset = { offsetX : Float, offsetY : Float }

type ElementState = ESRect RectState -- | ESLine LineState
type RectState = RViewState | REditState | RDragState (DragType, MouseOffset)
type DragType = DMove | DLeft | DRight | DTop | DBot | DTopLeft | DTopRight | DBotLeft | DBotRight

dTypeLeftFree : DragType -> Bool
dTypeLeftFree dType = case dType of
    DMove -> True
    DLeft -> True
    DTopLeft -> True
    DBotLeft -> True
    _ -> False

dTypeRightFree : DragType -> Bool
dTypeRightFree dType = case dType of
    DMove -> True
    DRight -> True
    DTopRight -> True
    DBotRight -> True
    _ -> False

dTypeTopFree : DragType -> Bool
dTypeTopFree dType = case dType of
    DMove -> True
    DTop -> True
    DTopLeft -> True
    DTopRight -> True
    _ -> False

dTypeBotFree : DragType -> Bool
dTypeBotFree dType = case dType of
    DMove -> True
    DBot -> True
    DBotLeft -> True
    DBotRight -> True
    _ -> False

type Msg = Select | DragStart DragType

------------------------------------- init -------------------------------------

initState : Element -> ElementState
initState element = case element of
    TextBox _ -> ESRect RViewState
    Line _ -> ESRect RViewState
    Rect _ -> ESRect RViewState

--------------------------------- update logic ---------------------------------

-- mainly phrasing these as a series of transformers on an element, with the
-- iteration logic handled in the module with the document itself.

deselect : (Element, ElementState) -> (Element, ElementState)
deselect (data, state) = case state of
    ESRect _ -> (data, ESRect RViewState)

-- if a box is selected and in drag mode, update its position
mousemove : MousePos -> AnchorPos -> (Element, ElementState) -> (Element, ElementState)
mousemove {x, y} anchorPos (data, state) = case state of
    ESRect (RDragState (dType, { offsetX, offsetY })) ->
        let targetX = x - anchorPos.x - offsetX
            targetY = y - anchorPos.y - offsetY

            l = dTypeLeftFree dType
            r = dTypeRightFree dType
            t = dTypeTopFree dType
            b = dTypeBotFree dType

            (x0, y0, w0) = case data of
                Rect d -> (d.x, d.y, d.width)
                TextBox d -> (d.x, d.y, d.width)
                _ -> (0, 0, 0)

            h0 = case data of
                Rect d -> d.height
                TextBox _ -> 100 -- just needs to be some non-zero value
                _ -> 0

            x1 = if l then targetX else x0
            y1 = if t then targetY else y0
            x2 = if r then targetX else x0 + w0
            y2 = if b then targetY else y0 + h0

            w = max rectMinWidth <| if l && r then w0 else x2 - x1
            h = max rectMinWidth <| if t && b then h0 else y2 - y1

            -- Stop forwards-slide past end-point
            x3 = if r then x1 else min x1 (x2 - rectMinWidth)
            y3 = if b then y1 else min y1 (y2 - rectMinWidth)

        in case data of
            Rect d -> (Rect { d | x = x3, y = y3, width = w, height = h }, state)
            TextBox d -> (TextBox { d | x = x3, y = y3, width = w }, state)
            _ -> (data, state)

    _ -> (data, state)


-- a more general update function. The last return value is whether or not we
-- need to send an update back to the server

update : MousePos -> AnchorPos -> Msg -> (Element, ElementState) -> ((Element, ElementState), Bool)
update mousePos anchorPos msg (data, state) = case (data, state) of

    (Rect d, ESRect s) -> case (msg, s) of
        (Select, RViewState) -> ((data, ESRect REditState), False)
        (DragStart dType, REditState) ->
            ((data, ESRect (RDragState (dType, mouseOffset dType mousePos anchorPos d.x d.y d.width d.height) )), False)

        _ -> ((data, state), False)

    (TextBox d, ESRect s) -> case (msg, s) of
        (Select, RViewState) -> ((data, ESRect REditState), False)
        (DragStart dType, REditState) ->
            ((data, ESRect (RDragState (dType, mouseOffset dType mousePos anchorPos d.x d.y d.width 0) )), False)

        _ -> ((data, state), False)

    _ -> ((data, state), False)

-- Just newState = update the element's state and send result back to server
-- Nothing = don't change state or send anything back down
mouseUp : ElementState -> Maybe ElementState
mouseUp state = case state of
    -- when we stop dragging a box, report its new state back down to the server
    ESRect s -> case s of
        RDragState _ -> ESRect REditState |> Just
        _ -> Nothing


mouseOffset : DragType -> MousePos -> AnchorPos -> Float -> Float -> Float -> Float -> MouseOffset
mouseOffset dType mousePos anchorPos x y w h =
    let l = dTypeLeftFree dType
        r = dTypeRightFree dType
        t = dTypeTopFree dType
        b = dTypeBotFree dType
    in {
        offsetX = mousePos.x - x - anchorPos.x - (if l then 0 else if r then w else w / 2),
        offsetY = mousePos.y - y - anchorPos.y - (if t then 0 else if b then h else h / 2)
    }


------------------------------------- view -------------------------------------

viewElement : (ElementId -> Msg -> msg) -> (ElementId, (Element, ElementState)) -> Html msg
viewElement converter (k, (e, s)) =
    case (s, e) of
        (ESRect state, TextBox data) -> viewTextBox converter (k, (data, state))
        (ESRect state, Rect data) -> viewRect converter (k, (data, state))
        _ -> text "other object types not yet implemented"


----------------------------- stretchy bounding box ----------------------------

viewBounding : (ElementId -> Msg -> msg) -> Html msg -> (ElementId, ({ x : Float, y : Float, width : Float, height : Maybe Float, z : Int }, RectState)) -> Html msg
viewBounding converter content (k, (data, state)) =

        let style = css <| [ Tw.absolute, Css.width (Css.px data.width)
                           , Css.left (Css.px data.x), Css.top (Css.px data.y) ]
                           ++ ( case data.height of
                               Just h -> [ Css.height (Css.px h) ]
                               Nothing -> []
                           ) ++ ( case state of

                               RViewState -> [ Css.zIndex (Css.int (data.z + 10))
                                             , Css.borderWidth (Css.px 1)
                                             , Tw.border_dashed, Css.borderColor (Css.hex "00000000") ]

                               -- increase z-index when editing, so we're able to
                               -- click on the drag handles when the element is
                               -- positioned logically under another.

                               REditState -> [ Css.zIndex (Css.int (data.z + 1000)), Tw.cursor_move
                                             , Css.borderWidth (Css.px 1)
                                             , Tw.border_dashed, Tw.border_white ]

                               RDragState _ -> [ Css.zIndex (Css.int (data.z + 1000)), Css.cursor Css.grabbing
                                               , Css.borderWidth (Css.px 1)
                                               , Tw.border_dashed, Tw.border_white ]
                           )

            events = case state of
                RViewState -> [ Events.onClick (converter k Select) ]
                _ -> [ Events.onMouseDown (converter k (DragStart DMove)) ]

            -- add 8 floating drag handles to the sides and corners
            children = case state of
                RViewState -> []
                _ -> [ (-1, 0, DLeft), (1, 0, DRight), (0, -1, DTop), (0, 1, DBot),
                       (-1, -1, DTopLeft), (1, 1, DBotRight), (1, -1, DTopRight), (-1, 1, DBotLeft) ]
                     |> List.map (\(x, y, dir) -> viewDragHandle converter k (x, y) dir)

        in div (style::events) (content::children)


viewDragHandle : (ElementId -> Msg -> msg) -> ElementId -> (Float, Float) -> DragType -> Html msg
viewDragHandle converter k (x, y) dir =

    let cursor = case dir of
            DMove     -> Css.cursor Css.move
            DLeft     -> Css.cursor Css.ewResize
            DRight    -> Css.cursor Css.ewResize
            DTop      -> Css.cursor Css.nsResize
            DBot      -> Css.cursor Css.nsResize
            DTopLeft  -> Css.cursor Css.nwseResize
            DBotRight -> Css.cursor Css.nwseResize
            DTopRight -> Css.cursor Css.neswResize
            DBotLeft  -> Css.cursor Css.neswResize

        h = if dir == DLeft || dir == DRight then Tw.h_full else (Css.height <| Css.px resizeRegionSize)
        w = if dir == DTop || dir == DBot then Tw.w_full else (Css.width <| Css.px resizeRegionSize)

        t = if dir == DBot || dir == DBotLeft || dir == DBotRight then Css.bottom (Css.px (-resizeRegionSize / 2)) else Css.top (Css.px (-resizeRegionSize / 2))
        l = if dir == DLeft || dir == DTopLeft || dir == DBotLeft then Css.left (Css.px (-resizeRegionSize / 2)) else Css.right (Css.px (-resizeRegionSize / 2))

        style = css <| [ Tw.absolute
                       , h, w
                       , t, l
                       , cursor, Css.zIndex (Css.int 5) ]

        events = [ Events.onMouseDown (converter k (DragStart dir)) ]

    in div (style::events) []

------------------------------------- rect -------------------------------------

viewRect : (ElementId -> Msg -> msg) -> (ElementId, ({ x : Float, y : Float, width : Float, height : Float, z : Int, color : String }, RectState)) -> Html msg
viewRect converter (k, (data, state)) =
    let content = div [css <| [Css.backgroundColor (Css.hex data.color), Tw.w_full, Tw.h_full]] []
    in viewBounding converter content (k, ({
            x      = data.x,
            y      = data.y,
            z      = data.z,
            width  = data.width,
            height = Just data.height
    } , state))

--------------------------------- markdown view --------------------------------

viewTextBox : (ElementId -> Msg -> msg) -> (ElementId, ({ x : Float, y : Float, width : Float, data : List (TextBlock) }, RectState)) -> Html msg
viewTextBox converter (k, (data, state)) =
    let padding = 18 in
    let content = div [css <| [ Css.width (Css.px data.width)
                              , Tw.h_full
                              , Css.paddingLeft (Css.px padding)
                              , Css.paddingRight (Css.px padding)
                          ]] <| List.map viewTextBlock data.data

    in viewBounding converter content (k, ({
            x      = data.x,
            y      = data.y,
            z      = 0,
            width  = data.width + 2 * padding,
            height = Nothing
    } , state))


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

        CodeBlock { text } -> Styled.pre [] [ Styled.code [] [ innerHtml text ] ]

        MathBlock { text } -> Styled.div [ css [ Tw.text_center ] ] [ innerHtml text ]

        UnorderedList { items } -> ul [] (List.map viewListItem items)

        OrderedList { items } -> ol [] (List.map viewListItem items)

        BlockQuote { inner } -> blockquote [] (List.map viewTextBlock inner)

        Image { url, alt } -> img [ Attributes.src url, Attributes.alt alt ] []

        VerticalSpace -> div [ css [ Css.height (Css.px 20) ] ] []

        HorizontalRule -> hr [] []



viewTextChunk : TextChunk -> Html msg
viewTextChunk chunk = case chunk of
    Link { title, url }      -> a [ Attributes.href url ] <| List.map viewTextChunk title
    Code { text }            -> code [] [ Styled.text text ]
    Math { text }            -> innerHtml text
    Bold { chunks }          -> b [] <| List.map viewTextChunk chunks
    Italic { chunks }        -> i [] <| List.map viewTextChunk chunks
    Strikethrough { chunks } -> s [] <| List.map viewTextChunk chunks
    Underline { chunks }     -> u [] <| List.map viewTextChunk chunks
    Text(text)               -> span [] [ Styled.text text ]
    NewLine                  -> br [] []


-- render raw html from a string
innerHtml : String -> Styled.Html msg
innerHtml content = Styled.node "inner-html" [ Attributes.attribute "content" content ] []
