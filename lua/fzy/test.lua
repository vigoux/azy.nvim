local fzy = require'fzy'

local choices = fzy.create()
choices:add { "bar", "foo", "baz" }
choices:search "b"
vim.pretty_print(choices:result())
