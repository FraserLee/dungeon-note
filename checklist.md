- [x] Python <-> Locally hosted webpage
- [x] Send forwards json full of dummy textboxes
- [x] Render that on the page
- [x] Move HTML into its own file
- [x] Swap to elm for frontend
- [x] Transfer position of textboxes to frontend
- [x] Ability to modify data within frontend

- [x] Add a global css file
- [x] Re-add styling from dungeon-note-2

- [x] Click textbox to bounding mode edit
    - [x] logical backing for drag and drop
    - [x] correct positioning relative to page
    - [x] drag icon
        - [x] position, looks
        - [x] mouse-over change both mouse and own colour
        - [x] change colour while being dragged
        - [x] larger selection-div than element itself
        - [x] offset by position within drag icon
    - [x] drag and drop tri-state mode system
    - [x] don't select text when dragging

- [x] Have changes get pushed backwards to python
- [x] Only push back on dragstop, not continually 

- [x] Run python script with a file argument. Grab single large paragraph from there.
- [x] Watch file / dir, re-grab stuff when it changes (pull behaviour from old project)

- [x] Move backend to Rust.

- [x] Force a refresh when the underlying data changes (websockets, probably.
      Maybe https://socket.io/)

- [x] Genericize from "TextBox" to element sum-type
- [x] Unified Types between frontend and backend
- [x] JSON serialization and deserialization for unified types
- [x] Proper Markdown parsing
    - [x] Create sample file
        - [x] Skeleton 
        - [x] Add every markdown feature

    - [x] Parse it
        - [x] Simple multiple text boxes
        - [x] Come up with format
        - [x] Block-scale parsing
        - [x] Fix Newlines to adhere to consistent convention
        - [x] Fix Paragraph End
        - [x] Line-scale parsing
        - [x] Newline Support
        - [x] Inline Code
        - [x] swap to better model for line parsing
        - [x] Links
        - [x] Horizontal Rules
        - [x] <br> breaks
        - [x] ~~strikethrough~~
        - [x] Lists
            - [x] Unordered
            - [x] Ordered
        - [x] Blockquotes
        - [x] Web-linked Images

    - [x] Display it

- [x] Add date to document, only ever update if newer

- [x] Cargo fmt my code

- [x] Stop regenerating regex unnecessarily

- [x] Save Changes back to file when they're made
    - [x] Successfully write back to file
    - [x] Keep order stable
    - [x] Don't trigger a reload when writing

- [x] Pull arbitrary parameters in arbitrary order out of header
- [x] Assume default values for missing parameters
- [x] Default text-block if no header starts the document

- [x] Write Readme

- [x] communicate when desync happens
    - [x] when not connected to sse
    - [x] when document date is newer than local date
        - [x] provide error state from rust
        - [x] receive error state in elm
    - [x] overlay with reload button

- [ ] Split example file into one focused entirely on markdown, and a second
      more literate one which demonstrates how to structure a document.

- [ ] Further Textbox edit-mode capabilities
    - [ ] Proper left-right position / resize
    - [ ] rotation
    - [ ] deselect when clicking background

- [ ] Rectangles
    - [x] parse
    - [x] render
    - [x] drag position
    - [ ] drag edge / corner to resize
        - [x] Left circle
        - [x] Right circle
        - [x] Top and Bottom circles
        - [x] Rewrite to be less case-based
        - [x] Corner circles
        - [x] Change sides from circles to invisible rectangles
        - [x] Make corners invisible
        - [ ] Stop forwards-slide past end-point
    - [ ] convert onMouseUp to just a mouseup event listener - no location dependence
        - [ ] drag rects while still in background.
    - [ ] rotation
        - white single-pixel wheel around the point of the thing, mouseover
    - [ ] move to wrapping interface, have textboxes use a limited version
          of it with only left-right edges.


- [ ] deselect when clicking background

- [ ] Lines

- [ ] More arbitrary zooming
    - [ ] Create a sample project where I can zoom in and out and move stuff around infinitely on a canvas containing a div
    - [ ] Swap dungeon note over to this model

- [ ] Z-order on arbitrary elements with forwards / backwards buttons

- [ ] fix styling on links
- [ ] Local File Images
- [ ] Tables in markdown
- [ ] Swap last space for &nbsp; before each newline.
        - "p, h1, h2, h3, h4, h5, h6, li, dt, dd"

- [ ] Re-add menu bar
- [ ] Math (both asciimath and latex would be ideal)
    - generate html on the backend, don't have anything like MathJax
      running on the site
    - [ ] support `\def` between equations, other stateful things
    - [ ] default def linking
- [ ] Memoize markdown parsing
- [ ] Highlight CodeBlocks
- [ ] Executable CodeBlocks
    - [ ] once unboxed execution is done, rewrite example to use it so it
      displays the output and the source markdown code side by side.
- [ ] Write tests
- [ ] dynamically adjust pivot so stuff is never offscreen to the left
- [ ] glorious unified system
    - [ ] integrate index.md functionality into a file browser style thing
    - [ ] website version with in-textbox editors and cloud sync
- [ ] make youtube video about how to use this, write tutorials
- [ ] syntax highlighting for .dn files
- [ ] put on brew
- [ ] swap from strings to ropes in the rust parser
    - possibly jumprope-rs, just pick something that allows regex
    - profile before and after
- [ ] vim plugin
- [ ] add lesswrong-style transparent floating sidebar table of contents.
- [ ] find out other things that should be on this list.
