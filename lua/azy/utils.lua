local Utils = {}



function Utils.git(...)
   if vim.fn.executable("git") == 0 then
      error("Could not execute git")
   end

   return vim.fn.systemlist({ "git", ... })
end

return Utils
