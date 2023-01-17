-- The only job of this file is to take a pretty complex json representing
-- a document, and turn it into elm data.

module Document exposing (..)

import Json.Decode as Decode
import Dict exposing (Dict)

type alias PersistentState = { elements : Dict ElementId Element }
type alias ElementId = String
type Element = TextBox (TextBoxState, TextBoxData)
            -- | Line (LineState, LineData)
            -- | ...

type TextBoxEditState = Base | Drag { iconMouseOffsetX : Float, iconMouseOffsetY : Float }
type TextBoxState = ViewState | EditState TextBoxEditState
type alias TextBoxData = { x : Float, y : Float, width : Float, textBoxElements : List TextBoxElement }
type TextBoxElement = Text String
                    | Heading (Int, String)


decodePersistentState : Decode.Decoder PersistentState
decodePersistentState = Decode.map PersistentState ( Decode.dict decodeElement )

decodeElement : Decode.Decoder Element
decodeElement =
    Decode.oneOf [ Decode.map TextBox decodeTextBox ]

decodeTextBox : Decode.Decoder (TextBoxState, TextBoxData)
decodeTextBox =
    Decode.map2 Tuple.pair (Decode.succeed ViewState) decodeTextBoxData

decodeTextBoxData : Decode.Decoder TextBoxData
decodeTextBoxData =
    Decode.map4 TextBoxData
        (Decode.field "x" Decode.float)
        (Decode.field "y" Decode.float)
        (Decode.field "width" Decode.float)
        (Decode.field "textBoxElements" (Decode.list decodeTextBoxElement))

decodeTextBoxElement : Decode.Decoder TextBoxElement
decodeTextBoxElement =
    Decode.oneOf [ Decode.map Text (Decode.field "text" Decode.string)
                 , Decode.map Heading (Decode.field "heading" (Decode.map2 Tuple.pair (Decode.field "level" Decode.int) (Decode.field "text" Decode.string)))
                 ]
