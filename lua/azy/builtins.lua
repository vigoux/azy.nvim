local ui = require('azy.ui')
local sources = require('azy.sources')
local sinks = require('azy.sinks')

local Builtins = {lsp = {}, }










function Builtins.files(paths, opts)
   return function()
      ui.create(sources.files(paths, opts), sinks.open_file)
   end
end

function Builtins.help()
   return function()
      ui.create(sources.help(), sinks.help_tag)
   end
end

function Builtins.buffers()
   return function()
      ui.create(sources.buffers(), sinks.open_file)
   end
end

local function lsp_on_list(f, param)
   return function()
      f(param, {
         on_list = function(items)
            ui.create(sources.qf_items(items.items), sinks.qf_item)
         end,
      })
   end
end

function Builtins.lsp.references()
   return lsp_on_list(vim.lsp.buf.references, { includeDeclaration = true })
end

function Builtins.lsp.workspace_symbols()
   return lsp_on_list(vim.lsp.buf.workspace_symbol, "")
end

return Builtins
