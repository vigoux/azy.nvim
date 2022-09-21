local record ConfigM
  record Config
    preview: boolean
    debug: boolean
  end

  cfg: Config

  HL_MATCH: string
  HL_DIM: string
  HL_STANDOUT: string

  time_this: function(string, function())
  log: function(...: any)
end

ConfigM.cfg = {
  preview = false,
  debug = false,
}

local function hl_group(name: string, options: vim.api.SetHlOptions): string
  local hl_name = "Azy" .. name
  vim.api.nvim_set_hl(0, hl_name, options)
  return hl_name
end

-- Global highlight definitions
ConfigM.HL_MATCH = hl_group("Match", { link = "Error", default = true })
ConfigM.HL_DIM = hl_group("Dim", { link = "Comment", default = true })
ConfigM.HL_STANDOUT = hl_group("Standout", { link = "Function", default = true })

local log_ignore: {string:boolean} = {
  time_this = true
}

local record GetInfos
  name: string
  source: string
  currentline: integer
end
function ConfigM.log(...: any)
  if ConfigM.cfg.debug then
    local level = 2 -- Neither getinfo, not the log function
    local infos: GetInfos
    repeat
      infos = debug.getinfo(level, 'Sln') as GetInfos
      level = level + 1
    until not log_ignore[infos.name]

    local fname = vim.fs.basename(infos.source:sub(2))
    print(string.format("%s:%d: ", fname, infos.currentline), ...)
  end
end

do
  local level = 0
  function ConfigM.time_this(msg: string, f: function())
    if ConfigM.cfg.debug then
      local arrow_head: string
      if level > 0 then
        arrow_head = vim.fn['repeat'](' ', 2 * level - 1)
        ConfigM.log(arrow_head, msg)
      else
        ConfigM.log(msg)
      end

      level = level + 1
      local t = vim.loop.hrtime()
      f()
      local stop_time = vim.loop.hrtime() - t
      level = level - 1

      if level > 0 then
        ConfigM.log(arrow_head, msg, ":", stop_time / (1000 * 1000))
      else
        ConfigM.log(msg, ":", stop_time / (1000 * 1000))
      end
    else
      f()
    end
  end
end

return ConfigM
