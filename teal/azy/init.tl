local config = require'azy.config'

local record AzyInit
  setup: function(config.Config)
end

function AzyInit.setup(user_config: config.Config)
  config.cfg = vim.tbl_deep_extend("force", config.cfg, user_config)
end

return AzyInit
