local Utils = {path = {}, }








function Utils.git(...)
   if vim.fn.executable("git") == 0 then
      error("Could not execute git")
   end

   return vim.fn.systemlist({ "git", ... })
end

local os_name = string.lower(jit.os)
local is_linux = (os_name == 'linux' or os_name == 'osx' or os_name == 'bsd')
local os_sep = is_linux and '/' or '\\'

function Utils.path.join(...)
   return table.concat({ ... }, os_sep)
end

function Utils.path.shorten(p)
   return vim.fn.fnamemodify(p, ":~:.")
end

return Utils
