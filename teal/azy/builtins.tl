local ui = require'azy.ui'
local sources = require'azy.sources'
local sinks = require'azy.sinks'

local record Builtins
  files: function({string}, sources.FilesOptions): function()
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

return Builtins
