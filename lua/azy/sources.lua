local utils = require('azy.utils')

local Sources = {FilesOptions = {}, }



















local function is_ignored(path, patterns)
   for _, p in ipairs(patterns) do
      if p:match_str(path) then
         return true
      end
   end
   return false
end

local function iter_files(paths, show_hidden, ignored_patterns)
   local path_stack = vim.fn.reverse(paths)



   local iters = setmetatable({}, {
      __index = function(tbl, key)
         key = vim.fs.normalize(key)
         local item = rawget(tbl, key)
         if not item then
            item = vim.loop.fs_scandir(key)
            rawset(tbl, key, item)
         end
         return item
      end,
   })

   return function()
      while true do
         local path = path_stack[#path_stack]
         local next_path, path_type = vim.loop.fs_scandir_next(iters[path])

         if not next_path then
            table.remove(path_stack)
            iters[path] = nil
            if #path_stack == 0 then
               return nil
            end
         elseif not (vim.startswith(next_path, '.') and not show_hidden) then
            local full_path = utils.path.shorten(utils.path.join(path, next_path))
            if path_type == 'directory' then
               table.insert(path_stack, full_path)
            elseif not is_ignored(full_path, ignored_patterns) then
               return full_path
            end
         end
      end
   end
end

local function read_ignore_file(ignored_patterns, path)
   local file = io.open(path)
   if file then
      for line, _ in function() return file:read() end do
         if not vim.startswith(line, '#') then
            table.insert(ignored_patterns, vim.regex(vim.fn.glob2regpat(line)))
         end
      end
   end
end

function Sources.files(paths, config)
   local ret = {}
   config = config or {}


   local ignored = vim.tbl_map(function(e) return vim.regex(e) end, config.ignored_patterns or {})
   local in_git = pcall(utils.git, "rev-parse", "--show-toplevel")
   read_ignore_file(ignored, ".ignore")

   local paths_set = not paths or #paths == 0

   if in_git and paths_set then
      return utils.git("ls-files")
   else
      if paths_set then
         paths = { "." }
      end

      for p in iter_files(paths, config.show_hidden, ignored) do
         table.insert(ret, { search_text = p })
      end
   end
   return ret
end


function Sources.help()
   local ret = {}
   for _, hpath in ipairs(vim.api.nvim_get_runtime_file("doc/tags", true)) do
      local file = io.open(hpath)
      if file then
         for line, _ in function() return file:read() end do
            local tag, hfile = unpack(vim.split(line, "\t", { plain = true }))
            table.insert(ret, { search_text = tag, extra_infos = { { hfile, "Comment" } } })
         end
      end
   end

   return ret
end

function Sources.buffers()
   local bufs = vim.api.nvim_list_bufs()
   local ret = {}

   for _, bnr in ipairs(bufs) do
      local infos = vim.fn.getbufinfo(bnr)[1]
      if infos.listed == 1 and infos.name and #infos.name > 0 then

         local extra_infos = { { "lnum:", "Comment" }, { tostring(infos.lnum), "Function" } }

         if infos.changed == 1 then
            table.insert(extra_infos, 1, { "+,", "Comment" })
         end
         ret[#ret + 1] = { search_text = infos.name, extra_infos = extra_infos }
      end
   end

   return ret
end

function Sources.qf_items(elems)
   return vim.tbl_map(function(e)
      local fname = utils.path.shorten(e.filename or vim.api.nvim_buf_get_name(e.bufnr))
      return {
         search_text = e.text,
         extra_infos = {
            { fname, "Comment" },
            { ":", "Comment" },
            { tostring(e.lnum), "Function" },
            { ":", "Comment" },
            { tostring(e.col), "Function" },
         },
         extra = e,
      }
   end, elems)
end

return Sources
