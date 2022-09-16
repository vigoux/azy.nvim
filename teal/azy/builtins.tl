local ui = require'azy.ui'
local sources = require'azy.sources'
local sinks = require'azy.sinks'

local record Builtins
  files: function({string}, sources.FilesOptions): function()
  files_contents: function({string}, sources.FilesOptions): function()
  help: function(): function()
  buffers: function(): function()
  quickfix: function(): function()

  record lsp
    references: function(): function()
    workspace_symbols: function(): function()
  end
end

function Builtins.files(paths: {string}, opts: sources.FilesOptions): function()
  return function()
    ui.create(sources.files(paths, opts), sinks.open_file)
  end
end

function Builtins.files_contents(paths: {string}, opts: sources.FilesOptions): function()
  return function()
    ui.create(sources.files_contents(paths, opts), sinks.open_file)
  end
end

function Builtins.help(): function()
  return function()
    ui.create(sources.help(), sinks.help_tag)
  end
end

function Builtins.buffers(): function()
  return function()
    ui.create(sources.buffers(), sinks.open_file)
  end
end

function Builtins.quickfix(): function()
  return function()
    ui.create(sources.qf_items(vim.fn.getqflist()), sinks.qf_item)
  end
end

local function lsp_on_list<T>(f: function(T, vim.lsp.LspOnListOptions), param: T): function()
  return function()
    f(param, {
      on_list = function(items: vim.lsp.LspOnListOptions.Arg)
        ui.create(sources.qf_items(items.items), sinks.qf_item)
      end
    })
  end
end

function Builtins.lsp.references(): function()
  return lsp_on_list(vim.lsp.buf.references, { includeDeclaration = true })
end

function Builtins.lsp.workspace_symbols(): function()
  return lsp_on_list(vim.lsp.buf.workspace_symbol, "")
end

return Builtins
