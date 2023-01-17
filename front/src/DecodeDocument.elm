-- The only job of this file is to take a pretty complex json representing
-- a document, and turn it into elm data.
module DecodeDocument exposing (..)

import Json.Decode as Decode
import Dict exposing (Dict)

type alias PersistentState = { elements : Dict ElementId Element }
type alias ElementId = String
type Element = TextBox { x : Float, y : Float, textBoxElements : List TextBoxElement }
             | Line { x0 : Float, y0 : Float, x1 : Float, y1 : Float, colour : String }

type TextBoxElement = Text String
                    | Heading (Int, String)
                    | Codeblock (String, String)

decodePersistentState : Decode.Decoder PersistentState
decodePersistentState = Decode.map PersistentState ( Decode.dict decodeElement )

decodeElement : Decode.Decoder Element
decodeElement =
    Decode.oneOf
        [ Decode.map TextBox decodeTextBox
        , Decode.map Line decodeLine
        ]

decodeTextBox : Decode.Decoder { x : Float, y : Float, textBoxElements : List TextBoxElement }
decodeTextBox =
    Decode.map3
        (\x y textBoxElements -> { x = x, y = y, textBoxElements = textBoxElements })
        (Decode.field "x" Decode.float)
        (Decode.field "y" Decode.float)
        (Decode.field "textBoxElements" (Decode.list decodeTextBoxElement))

decodeTextBoxElement : Decode.Decoder TextBoxElement
decodeTextBoxElement =
    Decode.oneOf
        [ Decode.map Text (Decode.field "text" Decode.string)
        , Decode.map Heading (Decode.field "heading" decodeHeading)
        , Decode.map Codeblock (Decode.field "codeblock" decodeCodeblock)
        ]

decodeHeading : Decode.Decoder (Int, String)
decodeHeading =
    Decode.map2
        (\level text -> (level, text))
        (Decode.field "level" Decode.int)
        (Decode.field "text" Decode.string)

decodeCodeblock : Decode.Decoder (String, String)
decodeCodeblock =
    Decode.map2
        (\language code -> (language, code))
        (Decode.field "language" Decode.string)
        (Decode.field "code" Decode.string)

decodeLine : Decode.Decoder { x0 : Float, y0 : Float, x1 : Float, y1 : Float, colour : String }
decodeLine =
    Decode.map5
        (\x0 y0 x1 y1 colour -> { x0 = x0, y0 = y0, x1 = x1, y1 = y1, colour = colour })
        (Decode.field "x0" Decode.float)
        (Decode.field "y0" Decode.float)
        (Decode.field "x1" Decode.float)
        (Decode.field "y1" Decode.float)
        (Decode.field "colour" Decode.string)

-- This is the only function that is actually used in the app. It takes a json
-- string, and tries to decode it into a document.

decodeDocumentFromString : String -> Result Decode.Error PersistentState
decodeDocumentFromString = Decode.decodeString decodePersistentState
