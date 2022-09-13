# `azy.nvim` incremental picker based of `fzy`

## Installation

Using `packer.nvim`:

```lua
use { 'vigoux/azy.nvim', requires = { 'romgrk/fzy-lua-native', run = 'make' } }
```

## Usage

This plugin provides a bunch of builtin searchs.
These builtin functions return a functions suitable for
`vim.keymap.set` when called, so that one can do the following:
```lua
  vim.keymap.set("n", "<Leader>e", require'azy.builtins'.files(), {})
```

The available functions are:
- `require'azy.builtins'.files(paths)`: search for local files under `paths`. This respects both the local `.gitignore` file and `.ignore`.
