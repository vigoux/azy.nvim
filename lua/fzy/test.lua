local fzy = require'fzy'

local choices = fzy.create()
choices:add { "bar", "foo", "baz" }
vim.pretty_print(choices:search "bb")
vim.pretty_print(choices:selected())
