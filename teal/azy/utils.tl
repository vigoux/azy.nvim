local record Utils
  git: function(...: string): {string}
  path_join: function(...: string): string
end

local os_name: string = string.lower(jit.os)
local is_linux: boolean = (os_name == 'linux' or os_name == 'osx' or os_name == 'bsd')
local os_sep: string = is_linux and '/' or '\\'

function Utils.path_join(...: string): string
  return table.concat({...}, os_sep)
end


function Utils.git(...: string): {string}
  if vim.fn.executable("git") == 0 then
    error "Could not execute git"
  end

  return vim.fn.systemlist { "git", ... }
end

return Utils
