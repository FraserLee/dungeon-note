port module Main exposing ( main )

import Bindings exposing (..)
import Element exposing (ElementId, ElementState, viewElement)
import Utils exposing (..)

import Html.Styled exposing (Html, div, text, h1, h2, h3, a, button)
import Html.Styled.Attributes as Attributes exposing (css)
import Html.Styled.Events as Events
import Tailwind.Utilities as Tw

import Css

import Browser
import Browser.Events exposing (onMouseMove, onKeyDown, onMouseUp)
import Browser.Dom exposing (getElement)
import Browser.Navigation as Navigation

import Json.Decode as Decode exposing (Decoder, field)

import Task

import Http

import Dict exposing (Dict)

------------------------------------- ports ------------------------------------

port fileChange : (String -> msg) -> Sub msg

port sseError : (String -> msg) -> Sub msg

---------------------------------- model types ---------------------------------

type Model = Loading 
           | Loaded (PersistentState, VolatileState)
           | Desync String PersistentState -- holds the last known good state
           | Failed Http.Error

type alias PersistentState = Document

type alias VolatileState = { anchorPos : AnchorPos
                           , mousePos : MousePos
                           , elements : Dict ElementId ElementState
                           , canSelectText : Bool
                           }

--------------------------------- message types --------------------------------

type Msg = LoadDocument (Result Http.Error PersistentState)
         | SetAnchorPos AnchorPos
         | ElementMsg (ElementId, Element.Msg)
         | MouseUp -- stop dragging any elements currently being dragged
         | Deselect -- deselect all elements. <esc> key + when clicking on background (todo)
         | MouseMove MousePos -- fired when the mouse moves
         | Posted (Result Http.Error ())
         | FileChange
         | SSEError String
         | Reload -- reload the page itself

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

initVolatileState : PersistentState -> VolatileState
initVolatileState data = 
    { anchorPos = { x = 0, y = 0 }
    , mousePos = { x = 0, y = 0 }
    , elements = Dict.map (\_ -> Element.initState) data.elements
    , canSelectText = True
    }


------------------------------------- logic ------------------------------------

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (model, msg) of

        -------------------- load document, update volatiles -------------------

        (_, LoadDocument (Ok data)) -> 
            ( Loaded (data, initVolatileState data)
            , Cmd.batch [loadAnchorPos] )

        (_, LoadDocument (Err err)) -> (Failed err, Cmd.none)

        -- reload data on hearing that the file has changed
        (_, FileChange) -> (Loading, fetchData)

        -- throw up a desync prompt if we get an error back on post. We don't
        -- just want to silently re-fetch data here, as this probably means the
        -- SSE stream is pointing to the wrong page (human accidentally opened
        -- multiple) and we want to properly reload.
        (_, Posted (Ok _)) -> (model, Cmd.none)
        (_, Posted (Err err)) -> case model of
            Loaded (data, volatiles) -> (Desync "stale document" data, Cmd.none)
            _ -> (model, Cmd.none)

        -- if we get an SSE Error, throw up a desync message and a reload button.
        -- Usually this one means the laptop fell asleep, or browser timed out,
        -- or maybe the server restarted.
        (_, SSEError message) -> case model of
            Loaded (data, volatiles) -> (Desync message data, Cmd.none)
            _ -> (model, Cmd.none)

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

        (Loaded (doc, volatiles), MouseMove p) -> 

            -- let _ = Debug.log "MouseMove:" (x, y) in

            let update_el = Element.mousemove p volatiles.anchorPos
                (dElements, vElements) = unzip <| Dict.map (\_ -> update_el) <| zip doc.elements volatiles.elements

                doc1       = { doc       | elements = dElements }
                volatiles1 = { volatiles | elements = vElements, mousePos = p }

            in (Loaded (doc1, volatiles1), loadAnchorPos)

        -------------------------------- reload --------------------------------

        -- todo: fire Navigation.reload when in a release build, Navigation.reloadAndSkipCache in a dev build
        (_, Reload) -> 
            -- let _ = Debug.log "Reloading" "" in
            -- (model, Navigation.reload)
            (model, Navigation.reloadAndSkipCache)

        ---------------------------- update elements ---------------------------

        (Loaded (doc, volatiles), Deselect) ->
            -- let _ = Debug.log "deselect" "" in
            let (dElements, vElements) = unzip <| Dict.map (\_ -> Element.deselect) (zip doc.elements volatiles.elements)

                doc1       = { doc       | elements = dElements }
                volatiles1 = { volatiles | elements = vElements }

            in (Loaded (doc1, volatiles1), Cmd.none)


        (Loaded (doc, volatiles), ElementMsg (target, e_msg)) ->
            -- let _ = Debug.log "ElementMsg" (target, e_msg) in

            let update_el = Element.update volatiles.mousePos volatiles.anchorPos e_msg

                res = updateWithRes target update_el <| zip doc.elements volatiles.elements

                -- we may or may not need to send a command to update the data on
                -- the "server" as a result of this.

                cmds = snd res |> Maybe.andThen (\((data, state), send_update) -> 
                                    if send_update then Just data else Nothing
                                )
                               |> Maybe.map (\data -> updateElement doc.created target data)
                               |> Maybe.withDefault Cmd.none

                (dElements, vElements) = unzip <| fst res

                -- if we're dragging something, don't allow text selection
                canSelectText = volatiles.canSelectText && case e_msg of
                        Element.DragStart _ -> False
                        _ -> True

                doc1       = { doc | elements = dElements }
                volatiles1 = { volatiles | elements = vElements, canSelectText = canSelectText }

            in (Loaded (doc1, volatiles1), cmds)

        (Loaded (doc, volatiles), MouseUp) ->
            -- let _ = Debug.log "MouseUp" "" in
            let (vElements, keys) = optionalUpdate Element.mouseUp volatiles.elements
                -- cmds = List.map (\k -> updateElement doc.created k (Dict.get k doc.elements)) keys
                cmds = List.map (\k -> Maybe.map (\data -> updateElement doc.created k data) (Dict.get k doc.elements)) keys
                        |> List.filterMap identity
                        |> Cmd.batch

                volatiles1 = { volatiles | elements = vElements, canSelectText = True }
            in (Loaded (doc, volatiles1), cmds)




        -- fall-through (just do nothing, probably tried to act while document loading or desynced)
        _ -> (model, Cmd.none)




------------------------------------- view -------------------------------------


view : Model -> Html Msg
view model =
    case model of
        -- Failed err -> text ("Failed to load data: " ++ (Debug.toString err))
        Failed err -> text "Failed to load data."

        Desync message doc ->
            let baseHtml = Loaded (doc, initVolatileState doc) |> view

                baseHtmlDark = div [ ]
                               [ div [ css [ Tw.absolute, Tw.inset_0, Tw.bg_black, Tw.opacity_70, Tw.z_40 ] ] []
                               , baseHtml
                               ]

                button = div [ css [ Tw.bg_gray_100, Tw.text_black, Tw.p_2, Tw.border_none, Tw.cursor_pointer ]
                             , Events.onClick Reload
                             ] [ div [ css [ Tw.font_bold ] ] [ text "reload" ] ]

                reload = div [ css [ Tw.absolute, Tw.inset_0, Tw.flex, Tw.flex_col, Tw.items_center, Tw.justify_center, Tw.z_50 ] ]
                            [ h2 [ css [ Tw.text_xl ] ] [ text message ], button ]

            in div []
                   [ reload
                   , baseHtmlDark
                   ]

        Loading -> 
            div [ css [ Tw.absolute, Tw.inset_0, Tw.flex, Tw.items_center, Tw.justify_center ] ]
                [ h2 [ css [ Tw.text_center, Tw.opacity_25 ] ] [ text "loading..." ] ]

        Loaded (doc, vol) ->
              let textBoxesHtml = List.map (viewElement (curry ElementMsg))
                                                  (Dict.toList <| zip doc.elements vol.elements)
                  textSelection = if not vol.canSelectText then [Tw.select_none] else []
              in div [ css (textSelection ++ [ Tw.top_0, Tw.w_full, Tw.h_screen ]) ]
                     [ div [ Attributes.id "anchor-div", css [ Tw.top_0, Tw.absolute, Css.left (Css.vw 50) ] ]
                         textBoxesHtml
                     ]

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

        -- fire a MouseUp event whenever the mouse is released
        mouseUpSub = onMouseUp (Decode.succeed MouseUp)

        -- subscribe to the escape key being pressed (damn this was harder than it should have been)
        escapeSub = onKeyDown (
                Decode.field "key" 
                Decode.string |> Decode.andThen 
                (\key -> if key == "Escape" then Decode.succeed Deselect else Decode.fail "wrong key")
            )

        -- subscribe to a SSE stream to hear if the file changed
        fileSub = fileChange (\_ -> FileChange)

        sseErrorSub = sseError (\s -> SSEError s)

    in Sub.batch [ mouseMoveSub, mouseUpSub, escapeSub, fileSub, sseErrorSub ]



main : Program () Model Msg
main = Browser.element { init = init, update = update, view = view >> Html.Styled.toUnstyled, subscriptions = subscriptions }
