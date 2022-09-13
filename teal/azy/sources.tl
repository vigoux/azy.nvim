local utils = require'azy.utils'

local record Sources
  record FilesOptions
    show_hidden: boolean
    ignored_patterns: {string}
  end
  files: function({string}, FilesOptions): {AzyElement}
end

-- Copied from complementree
local os_name = string.lower(jit.os)
local is_linux = (os_name == 'linux' or os_name == 'osx' or os_name == 'bsd')
local os_sep = is_linux and '/' or '\\'

local function is_ignored(path: string, patterns: {string}): boolean
  for _, p in ipairs(patterns) do
    if string.find(path, p) then
      print("Matched", p)
      return true
    end
  end
  return false
end

local function iter_files(paths: {string}, config: Sources.FilesOptions): function(): string|nil
  local path_stack = vim.fn.reverse(paths or { '.' })
  config = config or {}
  local iter_stack = {}
  for _, p in ipairs(path_stack) do
    table.insert(iter_stack, vim.loop.fs_scandir(p))
  end

  return function(): string|nil
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
        local full_path = vim.fn.fnamemodify(path .. os_sep .. next_path, ":~:.")
        if path_type == 'directory' then
          iter = vim.loop.fs_scandir(full_path)
          path = full_path
          table.insert(path_stack, full_path)
          table.insert(iter_stack, iter)
        elseif not is_ignored(full_path, config.ignored_patterns) then
          return full_path
        else
          next_path = nil
          path_type = nil
        end
      end
    end
  end
end

local function read_ignore_file(ignored_patterns: {string}, path: string)
  local file = io.open(path)
  if file then
    for line, _ in function(): (string, string) return file:read() end do
      if not vim.startswith(line, '#') then
        table.insert(ignored_patterns, vim.fn.glob2regpat(line))
      end
    end
  end
end

function Sources.files(paths: {string}, config: Sources.FilesOptions): {AzyElement}
  local ret = {}
  config = config or {}

  -- Set the ignored patterns using .gitignore and ignore
  config.ignored_patterns = config.ignored_patterns or {}
  local ok, gitdir = pcall(utils.git, "rev-parse", "--top-level")
  if ok and #gitdir == 1 then
    read_ignore_file(config.ignored_patterns, gitdir[1] .. os_sep .. ".gitignore")
  end
  read_ignore_file(config.ignored_patterns, ".ignore")

  for p in iter_files(paths, config) do
    table.insert(ret, { search_text = p })
  end
  return ret
end

return Sources
