local Config = {}





local function hl_group(name, options)
   local hl_name = "Azy" .. name
   vim.api.nvim_set_hl(0, hl_name, options)
   return hl_name
end


Config.HL_MATCH = hl_group("Match", { link = "Error", default = true })
Config.HL_DIM = hl_group("Dim", { link = "Comment", default = true })
Config.HL_STANDOUT = hl_group("Standout", { link = "Function", default = true })

return Config
