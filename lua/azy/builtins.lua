local ui = require('azy.ui')
local sources = require('azy.sources')
local sinks = require('azy.sinks')

local Builtins = {}



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

return Builtins
