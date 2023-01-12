Current plan - quickly scaffold this idea out using python, swap to something
more sustainable once the skeleton is in place.

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

- [x] Run python script with a file argument. Grab single large paragraph from there.
- [x] Watch file / dir, re-grab stuff when it changes (pull behaviour from old project)

- [x] Move backend to Rust.

- [x] Force a refresh when the underlying data changes (websockets, probably.
      Maybe https://socket.io/)

- [x] Have changes get pushed backwards to rust
- [ ] Only push back on dragstop, not continually 

- [ ] Proper Markdown parsing

- [ ] Save Changes back to file when they're made

- [ ] Further Textbox edit capabilities
    - [ ] horizontal resize
    - [ ] rotation
        - while single-pixel wheel around the point of the thing, mouseover
    - [ ] deselect when clicking background


- [ ] Re-add menu bar
- [ ] Genericize from "TextBox" to element sum-type
- [ ] Lines
- [ ] Math
- [ ] Write tests
- [ ] don't select text when dragging
- [ ] dynamically adjust pivot so stuff is never offscreen to the left
- [ ] glorious unified system
- [ ] find out other things that should be on this list.
