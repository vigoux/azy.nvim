local config = require('azy.config')

local AzyInit = {}



function AzyInit.setup(user_config)
   config.preview = user_config.preview
end

return AzyInit
