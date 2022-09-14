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

function Sources.files(paths: {string}, config: Sources.FilesOptions): {AzyElement}
  local ret = {}
  config = config or {}

  -- Set the ignored patterns using .gitignore and ignore
  local ignored = vim.tbl_map(function(e: string): vim.Regex return vim.regex(e) end, config.ignored_patterns or {})
  local ok, gitdir = pcall(utils.git, "rev-parse", "--show-toplevel")
  if ok and #gitdir == 1 then
    read_ignore_file(ignored, utils.path.join(gitdir[1], ".gitignore"))
  end
  read_ignore_file(ignored, ".ignore")

  if not paths or #paths == 0 then
    paths = { "." }
  end

  for p in iter_files(paths, config.show_hidden, ignored) do
    table.insert(ret, { search_text = p })
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
        local tag = vim.split(line, "\t", { plain = true })[1]
        table.insert(ret, { search_text = tag })
      end
    end
  end

  return ret
end

function Sources.buffers(): {AzyElement}
  local bufs = vim.api.nvim_list_bufs()
  local ret: {AzyElement} = {}

  for _,bnr in ipairs(bufs) do
    if vim.fn.buflisted(bnr) == 1 then
      local bname = vim.api.nvim_buf_get_name(bnr)
      if bname and #bname > 0 then
        table.insert(ret, { search_text = bname })
      end
    end
  end

  return ret
end

return Sources
