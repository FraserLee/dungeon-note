module Main exposing (..)

-- <!DOCTYPE html>
-- <html>
-- <head>
--     <title>Counter</title>
--     <script>
--         function increment() {
--             // Send a request to the server to increment the counter
--             fetch('/increment', {method: 'POST'})
--             .then(response => response.json())
--             .then(data => {
--                 // Update the counter on the webpage
--                 document.getElementById('counter').innerHTML = data.counter;
--             });
--         }
--     </script>
-- </head>
-- <body>
--     <h1>Counter</h1>
--     <p id="counter">0</p>
--     <button onclick="increment()">Increment</button>
-- </body>
-- </html>

import Html exposing (text)
main = text "Hello"
