port module Main exposing ( main )

import Bindings exposing (..)
import Element exposing (ElementId, ElementState, viewElement)
import Utils exposing (..)

import Html.Styled exposing (Html, div, text, h1, h2, h3)
import Html.Styled.Attributes as Attributes exposing (css)
import Tailwind.Utilities as Tw

import Css

import Browser
import Browser.Events exposing (onMouseMove, onKeyDown)
import Browser.Dom exposing (getElement)

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

type alias VolatileState = { anchorPos : AnchorPos
                           , mousePos : MousePos
                           , elements : Dict ElementId ElementState
                           , canSelectText : Int -- 0 = yes, 1+ = no
                           }

--------------------------------- message types --------------------------------

type Msg = LoadDocument (Result Http.Error PersistentState)
         | SetAnchorPos AnchorPos
         | ElementMsg (ElementId, Element.Msg)
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
                    -- , elements = Dict.map (\_ _ -> ESText ViewState) data.elements
                    , elements = Dict.map (\_ -> Element.initState) data.elements
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

        (Loaded (doc, volatiles), MouseMove p) -> 

            -- let _ = Debug.log "MouseMove:" (x, y) in

            let update_el = Element.mousemove p volatiles.anchorPos
                (dElements, vElements) = unzip <| Dict.map (\_ -> update_el) <| zip doc.elements volatiles.elements

                doc1       = { doc       | elements = dElements }
                volatiles1 = { volatiles | elements = vElements, mousePos = p }

            in (Loaded (doc1, volatiles1), loadAnchorPos)

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
                canSelectText = volatiles.canSelectText + case e_msg of
                    Element.DragStart -> 1
                    Element.DragStop -> -1
                    _ -> 0

                doc1       = { doc | elements = dElements }
                volatiles1 = { volatiles | elements = vElements, canSelectText = canSelectText }

            in (Loaded (doc1, volatiles1), cmds)




        -- fall-through (just do nothing, probably tried to act while document loading) 
        _ -> (model, Cmd.none)




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
              let textBoxesHtml = List.map (viewElement (curry ElementMsg))
                                                  (Dict.toList <| zip doc.elements vol.elements)
                  textSelection = if vol.canSelectText > 0 then [Tw.select_none] else []
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
