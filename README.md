# `azy.nvim` incremental picker based of `fzy`

This plugin provides a simple UI to selecte an item from a list.
It is very much my own version of the multitude of plugins like
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

## Installation

Using `packer.nvim`:

```lua
use { 'vigoux/azy.nvim', requires = { 'vigoux/fzy-lua-native', run = 'make' } }
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

Note though that on reasonably sized word lists (10K-ish entries), you
should not encounter any problem.
