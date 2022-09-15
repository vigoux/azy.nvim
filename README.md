# `azy.nvim` fuzzy finder for `neovim` based on `fzy`

This plugin provides a simple UI to select an item from a list.
It is very much my own version of the multitude of plugins like
[telescope.nvim].

The goal of this plugin will be different than [telescope.nvim]. This
plugin focuses on speed and non-intrusivness rather that
configurability.

## Installation

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

## Usage

This plugin provides a bunch of builtin searchs.
These builtin functions return a function suitable for
`vim.keymap.set` when called, so that one can do the following:
```lua
  vim.keymap.set("n", "<Leader>e", require'azy.builtins'.files(), {})
```

The available functions are:
- `azy.builtins.files(paths)`: files under `paths`. Respects both the local `.gitignore` file and `.ignore`.
- `azy.builtins.help()`: help tags, opens the selected tag on confirm
- `azy.builtins.buffers()`: opened buffers

## Performances

I made this plugin so that I don't _feel_ any blocking when I am
typing. This means that in some cases where the number of entries to
search from is huge, you might encounter some performance problems.

If that is the case, feel free to report an issue with the list of
entries that caused the problem, and what you did when encountering
the problem, and I'll be glad to look into it.

Note though that on reasonably sized word lists, you
should not encounter any problem.

But for the record, it took (on my machine) approximately 1s to filter
a 400K entries list to `azy.nvim`.

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
