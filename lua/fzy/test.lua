local fzy = require'fzy'

local choices = fzy.create()
choices:add { "babar", "baz" }
choices:search "ab"
vim.pretty_print(choices:elements())
print(choices:selected())
choices:add_incremental { "abar" }
vim.pretty_print(choices:elements())
print(choices:selected())
print(choices:next())
print(choices:next())

choices:search "a"
vim.pretty_print(choices:elements())
print(choices:selected())
print(choices:next())
print(choices:next())
print(choices:next())
