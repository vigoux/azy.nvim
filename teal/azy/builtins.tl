local ui = require'azy.ui'
local sources = require'azy.sources'
local sinks = require'azy.sinks'

local record Builtins
  files: function({string}, sources.FilesOptions): function()
  help: function(): function()
  buffers: function(): function()

  record lsp
    references: function(): function()
  end
end

function Builtins.files(paths: {string}, opts: sources.FilesOptions): function()
  return function()
    ui.create(sources.files(paths, opts), sinks.open_file)
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

function Builtins.lsp.references(): function()
  return function()
    vim.lsp.buf.references({ includeDeclaration = true }, {
      on_list = function(items: vim.lsp.LspOnListOptions.Arg)
        vim.pretty_print(items)
        ui.create(sources.qf_items(items.items), sinks.qf_item)
      end
    })
  end
end

return Builtins
