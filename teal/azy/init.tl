local config = require'azy.config'

local record AzyInit
  setup: function()
end

function AzyInit.setup(user_config: config)
  config.preview = user_config.preview
end

return AzyInit
