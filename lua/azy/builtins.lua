local ui = require('azy.ui')
local async = require('azy.async')
local sources = require('azy.sources')
local sinks = require('azy.sinks')

local Builtins = {lsp = {}, }












local function async_ui(command, transform, sink)
   return function()
      local job = async.create(command, 10000, function(lines)
         ui.add(vim.tbl_map(transform, lines))
      end)
      ui.create({}, function(e)
         job:stop()
         sink(e)
      end)
      job:run()
   end
end

function Builtins.files(paths, opts)
   local paths_not_set = not paths or #paths == 0

   if paths_not_set then
      if vim.fn.executable("fd") == 1 then
         return async_ui({ "fd", "--type", "f" }, function(el)
            return { search_text = el }
         end, sinks.open_file)
      elseif vim.fn.executable("fdfind") == 1 then
         return async_ui({ "fdfind", "--type", "f" }, function(el)
            return { search_text = el }
         end, sinks.open_file)
      end
   end

   return function()
      ui.create(sources.files(paths, opts), sinks.open_file)
   end
end

function Builtins.files_contents(paths, opts)
   return function()
      ui.create(sources.files_contents(paths, opts), sinks.open_file)
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

function Builtins.quickfix()
   return function()
      ui.create(sources.qf_items(vim.fn.getqflist()), sinks.qf_item)
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
