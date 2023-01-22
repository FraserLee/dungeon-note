# Todo: write readme

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
- [ ] Proper Markdown parsing
    - [x] Create sample file
        - [x] Skeleton 
        - [ ] Add every markdown feature
    - [ ] Parse it
        - [x] Simple multiple text boxes
        - [x] Come up with format
        - [x] Block-scale parsing
        - [ ] Fix Newlines to adhere to consistent convention
        - [ ] Fix Paragraph End
        - [ ] Line-scale parsing
    - [x] Display it

- [ ] Cargo fmt

- [ ] Polish Readme

- [ ] Save Changes back to file when they're made

- [ ] Further Textbox edit capabilities
    - [ ] horizontal resize
    - [ ] rotation
        - while single-pixel wheel around the point of the thing, mouseover
    - [ ] deselect when clicking background

- [ ] Rectangles

- [ ] Swap last space for &nbsp; before each newline.
        - "p, h1, h2, h3, h4, h5, h6, li, dt, dd"
- [ ] <br> breaks
- [ ] ~~strikethrough~~
- [ ] don't select text when dragging
- [ ] Re-add menu bar
- [ ] Lines
- [ ] Math (both asciimath and latex would be ideal)
    - generate html on the backend, don't have anything like MathJax
      running on the site
- [ ] Images
- [ ] Memoize markdown parsing
- [ ] Highlight CodeBlocks
- [ ] Execute CodeBlocks
- [ ] Z-order on arbitrary elements with forwards / backwards buttons
- [ ] Write tests
- [ ] dynamically adjust pivot so stuff is never offscreen to the left
- [ ] glorious unified system
    - [ ] integrate index.md functionality into a file browser style thing
    - [ ] website version with in-textbox editors and cloud sync
- [ ] make youtube video about how to use this, write tutorials
- [ ] syntax highlighting for .dn files
- [ ] find out other things that should be on this list.
