local record Config
  HL_MATCH: string
  HL_DIM: string
  HL_STANDOUT: string
end

local function hl_group(name: string, options: vim.api.SetHlOptions): string
  local hl_name = "Azy" .. name
  vim.api.nvim_set_hl(0, hl_name, options)
  return hl_name
end

-- Global highlight definitions
Config.HL_MATCH = hl_group("Match", { link = "Error", default = true })
Config.HL_DIM = hl_group("Dim", { link = "Comment", default = true })
Config.HL_STANDOUT = hl_group("Standout", { link = "Function", default = true })

return Config
