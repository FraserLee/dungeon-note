# DungeonNote

Take notes in an extended superset of markdown, with the ability to draw
diagrams and edit the layout and design of the page in real time. 

Everything is stored in plain text, locally. No syncing, no cloud, use your own
preferred text editor. 

Optimized for zero friction, and a note taking experience as expressive as
paper.

## Warning

I'll delete this warning when things are somewhat more stable, but for the
moment this isn't anywhere close to done. 

## Installation

I'm planning on publishing this to some sort of package manager. For now,
you'll need to build it yourself. Sorry. Just message me or create an issue if
you can't get it working.

### Requirements
1. You probably already have `python3` and `git` installed. If not, then do that.
2. If you don't already have it, install [`rust`](https://www.rust-lang.org/tools/install)
3. Install [`elm`](https://elm-lang.org/)

---

```bash
# Clone the repo
git clone https://github.com/FraserLee/dungeon-note
cd dungeon-note

# Then add a line into your shell config to make the `dungeon` command available
echo "alias dungeon='$PWD/dungeon.py'" >> ~/.zshrc
```

## Usage

```bash
dungeon note.dn
```

You can (and should) edit this file in some text editor simultaneously.

Check out `examples/` to see how the syntax works.

