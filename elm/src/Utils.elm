module Utils exposing (..)

import Dict exposing (Dict)

type alias MousePos = { x : Float, y : Float }
type alias AnchorPos = { x : Float, y : Float }

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

-- like Dict.update, but you can pull an extra result value out of the update function
updateWithRes : comparable -> (v -> (v, a)) -> Dict comparable v -> (Dict comparable v, Maybe (v, a))
updateWithRes key f dict = 
    case Dict.get key dict of
        Nothing -> (dict, Nothing)
        Just v -> 
            let (v1, a) = f v
            in (Dict.insert key v1 dict, Just (v1, a))

optionalUpdate : (v -> Maybe v) -> Dict comparable v -> (Dict comparable v, List comparable)
optionalUpdate f dict = 
    Dict.foldl (\k v (dict1, keys) ->
        case f v of
            Just v1 -> (Dict.insert k v1 dict1, k :: keys)
            Nothing -> (Dict.insert k v dict1, keys)
    ) (Dict.empty, []) dict

curry : ((a, b) -> c) -> a -> b -> c
curry f a b = f (a, b)

uncurry : (a -> b -> c) -> (a, b) -> c
uncurry f (a, b) = f a b

fst : (a, b) -> a
fst (a, b) = a

snd : (a, b) -> b
snd (a, b) = b
