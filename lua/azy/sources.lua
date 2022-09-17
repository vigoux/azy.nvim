local utils = require('azy.utils')
local config = require('azy.config')

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
            local full_path = utils.path.join(path, next_path)
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
local function list_files(paths, cfg)
   cfg = cfg or {}


   local ignored = vim.tbl_map(function(e) return vim.regex(e) end, cfg.ignored_patterns or {})
   local in_git = pcall(utils.git, "rev-parse", "--show-toplevel")
   read_ignore_file(ignored, ".ignore")

   local paths_not_set = not paths or #paths == 0

   if paths_not_set then
      paths = { "." }

      if vim.fn.executable("fd") == 1 then
         return vim.fn.systemlist({ "fd", "--type", "f" })
      elseif vim.fn.executable("fdfind") == 1 then
         return vim.fn.systemlist({ "fdfind", "--type", "f" })
      elseif in_git then
         return utils.git("ls-files")
      end
   end


   local ret = {}

   for p in iter_files(paths, cfg.show_hidden, ignored) do
      table.insert(ret, p)
   end
   return ret
end

function Sources.files(paths, cfg)
   return vim.tbl_map(function(e)
      return { search_text = utils.path.shorten(e) }
   end, list_files(paths, cfg))
end

local function fname_format(e, lnum, length)
   local elen = vim.fn.strdisplaywidth(e)
   local lnumlen = vim.fn.strdisplaywidth(tostring(lnum))
   length = (length or 30) - lnumlen - 1

   local pfmt
   local padding = ""

   if elen > length then
      pfmt = vim.fn.pathshorten(e, 1)
      elen = vim.fn.strdisplaywidth(pfmt)
   end

   if elen > length then
      pfmt = "..." .. pfmt:sub(#pfmt - length - 2)
   else
      pfmt = e
      padding = vim.fn["repeat"](" ", length - elen)
   end

   return string.format("%s:%d%s|", pfmt, lnum, padding)
end

function Sources.files_contents(paths, cfg)
   local ret = {}
   local files = list_files(paths, cfg)
   for i = 1, #files do
      local file = io.open(files[i])
      if file then
         local lnum = 0
         for line, _ in function() return file:read() end do
            lnum = lnum + 1
            if #line > 0 then
               ret[#ret + 1] = {
                  search_text = fname_format(files[i], lnum) .. line,
                  extra_infos = {
                     { files[i] .. ":", config.HL_DIM },
                     { tostring(lnum), config.HL_STANDOUT },
                  },

                  extra = {
                     filename = files[i],
                     lnum = lnum,
                     col = 0,
                     valid = 1,
                  },
               }
            end
         end
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
            table.insert(ret, { search_text = tag, extra_infos = { { hfile, config.HL_DIM } } })
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

         local extra_infos = { { "lnum:", config.HL_DIM }, { tostring(infos.lnum), config.HL_STANDOUT } }

         if infos.changed == 1 then
            table.insert(extra_infos, 1, { "+,", config.HL_DIM })
         end
         ret[#ret + 1] = { search_text = utils.path.shorten(infos.name), extra_infos = extra_infos }
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
            { fname, config.HL_DIM },
            { ":", config.HL_DIM },
            { tostring(e.lnum), config.HL_STANDOUT },
            { ":", config.HL_DIM },
            { tostring(e.col), config.HL_STANDOUT },
         },
         extra = e,
      }
   end, elems)
end

return Sources
