local record Utils
  git: function(...: string): {string}

  record path
    join: function(...: string): string
    shorten: function(string): string
  end
end

function Utils.git(...: string): {string}
  if vim.fn.executable("git") == 0 then
    error "Could not execute git"
  end

  local is_git = #(vim.fn.systemlist { "git", "rev-parse", "HEAD" }) == 1
  if not is_git then
    error "Not in a git directory"
  end

  return vim.fn.systemlist { "git", ... }
end

local os_name: string = string.lower(jit.os)
local is_linux: boolean = (os_name == 'linux' or os_name == 'osx' or os_name == 'bsd')
local os_sep: string = is_linux and '/' or '\\'

function Utils.path.join(...: string): string
  return table.concat({...}, os_sep)
end

function Utils.path.shorten(p: string): string
  return vim.fn.fnamemodify(p, ":~:.")
end

return Utils
