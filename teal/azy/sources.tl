local utils = require'azy.utils'

local record Sources

  -- Files source
  record FilesOptions
    show_hidden: boolean
    ignored_patterns: {string}
  end
  files: function({string}, FilesOptions): {AzyElement}

  -- Help tags source
  help: function(): {AzyElement}

  -- Buffers source
  buffers: function(): {AzyElement}

  -- quickfix items
  qf_items: function({vim.QfItem}): {AzyElement}
end

-- Copied from complementree
local function is_ignored(path: string, patterns: {vim.Regex}): boolean
  for _, p in ipairs(patterns) do
    if p:match_str(path) then
      return true
    end
  end
  return false
end

local function iter_files(paths: {string}, show_hidden: boolean, ignored_patterns: {vim.Regex}): function(): string|nil
  local path_stack = vim.fn.reverse(paths)

  -- Nice lua-ism: when the path is not present in here, create a new path FSIterator, otherwise
  -- return it. The nice thing is that all this is done using normalized file paths.
  local iters: {string: vim.loop.FSIterator} = setmetatable({}, {
    __index = function(tbl: {string:vim.loop.FSIterator}, key: string): vim.loop.FSIterator
      key = vim.fs.normalize(key)
      local item = rawget(tbl, key)
      if not item then
        item = vim.loop.fs_scandir(key)
        rawset(tbl, key, item)
      end
      return item
    end
  })

  return function(): string|nil
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

local function read_ignore_file(ignored_patterns: {vim.Regex}, path: string)
  local file = io.open(path)
  if file then
    for line, _ in function(): (string, string) return file:read() end do
      if not vim.startswith(line, '#') then
        table.insert(ignored_patterns, vim.regex(vim.fn.glob2regpat(line)))
      end
    end
  end
end
local function list_files(paths: {string}, config: Sources.FilesOptions): {string}
  config = config or {}

  -- Set the ignored patterns using .gitignore and ignore
  local ignored = vim.tbl_map(function(e: string): vim.Regex return vim.regex(e) end, config.ignored_patterns or {})
  local in_git = pcall(utils.git, "rev-parse", "--show-toplevel")
  read_ignore_file(ignored, ".ignore")

  local paths_set: boolean = not paths or #paths == 0

  if vim.fn.executable "fd" == 1 then
    return vim.fn.systemlist "fd"
  elseif vim.fn.executable "fdfind" == 1 then
    return vim.fn.systemlist "fdfind"
  elseif in_git and paths_set then
    return utils.git "ls-files"
  else
    local ret = {}
    if paths_set then
      paths = { "." }
    end

    for p in iter_files(paths, config.show_hidden, ignored) do
      table.insert(ret, p)
    end
    return ret
  end
end

function Sources.files(paths: {string}, config: Sources.FilesOptions): {AzyElement}
  return vim.tbl_map(function(e: string): AzyElement
    return { search_text = utils.path.shorten(e) }
  end, list_files(paths, config))
end

local function fname_format(e: string, lnum: integer, length: integer): string
  local elen = vim.fn.strdisplaywidth(e)
  local lnumlen = vim.fn.strdisplaywidth(tostring(lnum))
  length = (length or 30) - lnumlen - 1

  local pfmt: string
  local padding: string = ""

  if elen > length then
    pfmt = vim.fn.pathshorten(e, 1)
    elen = vim.fn.strdisplaywidth(pfmt)
  end

  if elen > length then
    pfmt = "..." .. pfmt:sub(#pfmt - length - 2) -- to add ...
  else
    pfmt = e
    padding = vim.fn["repeat"](" ", length - elen)
  end

  return string.format("%s:%d%s|", pfmt, lnum, padding)
end

function Sources.files_contents(paths: {string}, config: Sources.FilesOptions): {AzyElement}
  local ret = {}
  local files: {string} = list_files(paths, config)
  for i = 1,#files do
    local file = io.open(files[i])
    if file then
      local lnum: integer = 1
      for line, _ in function(): string, string return file:read() end do
        if #line > 0 then
          ret[#ret + 1] = {
            search_text = fname_format(files[i], lnum) .. line,
            extra_infos = {
              { files[i], "Comment" },
              { ":", "Comment" },
              { tostring(lnum), "Function" },
            },
            -- To use as a QfItem
            extra = {
              filename = files[i],
              lnum = lnum,
              col = 0
            }
          }
          lnum = lnum + 1
        end
      end
    end
  end

  return ret
end


-- Help tags source
function Sources.help(): {AzyElement}
  local ret = {}
  for _, hpath in ipairs(vim.api.nvim_get_runtime_file("doc/tags", true)) do
    local file = io.open(hpath)
    if file then
      for line, _ in function(): string, string return file:read() end do
        local tag, hfile = unpack(vim.split(line, "\t", { plain = true }))
        table.insert(ret, { search_text = tag, extra_infos = { { hfile, "Comment" } } })
      end
    end
  end

  return ret
end

function Sources.buffers(): {AzyElement}
  local bufs = vim.api.nvim_list_bufs()
  local ret: {AzyElement} = {}

  for _,bnr in ipairs(bufs) do
    local infos = vim.fn.getbufinfo(bnr)[1]
    if infos.listed == 1 and infos.name and #infos.name > 0 then

      local extra_infos = { {"lnum:", "Comment"}, { tostring(infos.lnum), "Function" } }

      if infos.changed == 1 then
        table.insert(extra_infos, 1, { "+,", "Comment" })
      end
      ret[#ret + 1] = { search_text = infos.name, extra_infos = extra_infos }
    end
  end

  return ret
end

function Sources.qf_items(elems: {vim.QfItem}): {AzyElement}
  return vim.tbl_map(function(e: vim.QfItem): AzyElement
    local fname: string = utils.path.shorten(e.filename or vim.api.nvim_buf_get_name(e.bufnr))
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
