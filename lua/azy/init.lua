local config = require('azy.config')

local AzyInit = {}



function AzyInit.setup(user_config)
   config.cfg = vim.tbl_deep_extend("force", config.cfg, user_config)
end

return AzyInit
