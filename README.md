# __THIS PLUGING IS NOW HOSTED ON [sr.ht](https://sr.ht/~vigoux/azy.nvim/). Development will continue there__

__WARNING: This plugin is meant to be used with neovim 0.8__

# `azy.nvim` fuzzy finder for `neovim` based on `fzy`

This plugin provides a simple UI to select an item from a list.

It has the following features:
- Fast fuzzy matching: powered by [fzy], the search runs on multiple
  threads and allows for very fast search
- Both asynchronous and synchronous UIs: asynchronous UIs allow to
  incrementally add results to match against
- Lua / C mix: this plugin is very much an lua interface to [fzy], so
  the performance-critical parts are as fast as they could be.

You can join us of [the matrix
room](https://matrix.to/#/#azy.nvim:matrix.org) to ask any question
or suggestion !

## Installation

_WARNING: this plugin will clash with
[nvim-fzy](https://github.com/mfussenegger/nvim-fzy) and [guihua](https://github.com/ray-x/guihua.lua) so you need to
only have one of these installed at a time_

As this plugin requires the compilation of a small C library, you will
have to have the following system dependencies:
- A `C` compiler in your path, to compile the library
- `pkg-config`, to search for the dependencies
- `luajit` and it's headers (`libluajit-5.1-dev` on Ubuntu), to
  link against it
- `libpthread` and it's headers (intalled by default on Ubuntu),
  that's a dependency to build `fzy`.

Using `packer.nvim`:

```lua
use { 'vigoux/azy.nvim', run = 'make lib' }
```

## Setup

You can configure `azy` as any other plugin using the `azy.setup`
function. Note though that this is not required for this plugin to
work, as it only configures the features of `azy`:
```lua
require'azy'.setup {
  preview = false, -- Whether to preview selected items on the fly (this is an unstable feature, feedback appreciated)
  debug = false, -- Enable debug output and timings in the UI
  mappings = { -- Configure the mappings
    ["<Up>"] = "prev", -- Select the previous item
    ["<Down>"] = "next", -- Select the next item
    ["<CR>"] = "confirm", -- Confirm the selection, open the selected item
    ["<C-V>"] = "confirm_vsplit", -- Same as confirm but in a vertical split
    ["<C-H>"] = "confirm_split", -- Same as confirm but in a horizontal split

    -- Normal mode mapping are not configurable:
    -- <ESC>: exits without confirm
  },
}
```

## Usage

This plugin provides a bunch of builtin searchs.
These builtin functions return a function suitable for
`vim.keymap.set` when called, so that one can do the following:
```lua
  vim.keymap.set("n", "<Leader>e", require'azy.builtins'.files(), {})
```

Examples of how to use the functions below can be found
[here](https://github.com/vigoux/azy.nvim/wiki/Examples). This is
editable by everyone so feel free to add your lines there.

## Builtins

- `azy.builtins.files(paths)`: files under `paths`. Respects both the local `.gitignore` file and `.ignore`.
- `azy.builtins.files_contents(paths)`: contents of the files under `paths`
- `azy.builtins.help()`: help tags, opens the selected tag on confirm
- `azy.builtins.buffers()`: opened buffers
- `azy.builtins.quickfix()`: items in the quickfix list

### LSP-related

- `azy.builtins.lsp.references()`: references to the symbol under the cursor
- `azy.builtins.lsp.document_symbol()`: symbols in the current buffer
- `azy.builtins.lsp.workspace_symbols()`: symbols defined in the current workspace

## Customizing

This plugin provides some highlight groups to customize its look:
- `AzyMatch`: to highlight positions in the string that match the
  query
- `AzyDim`: for extra informations (dimmed)
- `AzyStandout`: for extra informations (standout)

## Performances

I made this plugin so that I don't _feel_ any blocking when I am
typing. This means that in some cases where the number of entries to
search from is huge, you might encounter some performance problems.

If that is the case, feel free to report an issue with the list of
entries that caused the problem, and what you did when encountering
the problem, and I'll be glad to look into it.

Note though that on reasonably sized word lists, you
should not encounter any problem.

Furthermore, using an asynchronous UI, as the results are
incrementally sorted, one should not _feel_ any blocking point.
For the record, using the asychronous UI, search in a directory with
more than 300K does not lead to any blocking (any update takes less
that 10ms).

## Acknowledgement

This project can be considered my own version ov [telescope.nvim].

The goal of this plugin will be different than [telescope.nvim]. This
plugin focuses on speed and non-intrusivness rather that
configurability.


[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[fzy]: https://github.com/jhawthorn/fzy
