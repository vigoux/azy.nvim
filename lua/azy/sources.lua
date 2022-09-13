local Sources = {FilesOptions = {}, }







local os_name = string.lower(jit.os)
local is_linux = (os_name == 'linux' or os_name == 'osx' or os_name == 'bsd')
local os_sep = is_linux and '/' or '\\'

local function iter_files(paths, config)
   local path_stack = vim.fn.reverse(paths or { '.' })
   config = config or {}
   local iter_stack = {}
   for _, p in ipairs(path_stack) do
      table.insert(iter_stack, vim.loop.fs_scandir(p))
   end

   return function()
      local iter = iter_stack[#iter_stack]
      local path = path_stack[#path_stack]
      while true do
         local next_path, path_type = vim.loop.fs_scandir_next(iter)

         if not next_path then
            table.remove(iter_stack)
            table.remove(path_stack)
            if #iter_stack == 0 then
               return nil
            end
            iter = iter_stack[#iter_stack]
            path = path_stack[#path_stack]
         elseif (vim.startswith(next_path, '.') and not config.show_hidden) then
            next_path = nil
            path_type = nil
         else
            local full_path = path .. os_sep .. next_path
            if path_type == 'directory' then
               iter = vim.loop.fs_scandir(full_path)
               path = full_path
               table.insert(path_stack, full_path)
               table.insert(iter_stack, iter)
            else
               return full_path
            end
         end
      end
   end
end

function Sources.files(paths, config)
   local ret = {}
   for p in iter_files(paths, config) do
      table.insert(ret, { search_text = p })
   end
   return ret
end

return Sources
