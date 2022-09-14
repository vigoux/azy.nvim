local fzy = require'fzy-lua-native'
local AUGROUP_NAME = "AzyUi"
local hl_ns = vim.api.nvim_create_namespace 'azy'

local log: function(...: any)
local time_this: function(string, function())

if vim.fn.exists "g:azy_ui_debug" == 1 then
  print("AzyUi debugging enabled")
  log = function(...: any)
    print("AzyUi:", ...)
  end

  local htime = vim.loop.hrtime

  local level = 0
  time_this = function(msg: string, f: function())
    level = level + 1
    local arrow_head = vim.fn['repeat']('-', level)
    log(arrow_head .. ">", msg, "start")

    local t = htime()
    f()
    local stop_time = htime() - t

    log("<" .. arrow_head, msg, "stop:", stop_time / (1000 * 1000))
    level = level - 1
  end
else
  log = function()
  end

  time_this = function(_:string, f: function())
    f()
  end
end

local record AzyLine
  content: AzyElement

  -- Cached private stuff
  _selected_fmt: string
  _raw_fmt: string
end

--- Formats the @p line and return the offset for highlighing
---
---@return string Formatted line
---@return integer Offset for highlighting
local function format_line(line: AzyLine, selected: boolean): string, integer
  if selected then
    if not line._selected_fmt then
      line._selected_fmt = "> " .. line.content.search_text
    end
    return line._selected_fmt, 2
  else
    if not line._raw_fmt then
      line._raw_fmt = "  " .. line.content.search_text
    end
    return line._raw_fmt, 2
  end
end

local record AzyUi
  create: function({AzyElement|string}, function(AzyElement))
  next: function()
  prev: function()
  exit: function()
  confirm: function()

  -- Private stuff
  _close: function()
  _destroy: function()
  _source_lines: {AzyLine}
  _callback: function(AzyElement)

  -- Main update function, refreshs the whole buffer
  _update_output_buf: function()
  _redraw: function()

  -- Useful to handle cursor navigation and redrawing
  _selected: AzyLine
  _redraw_lines: function({integer})
  _pick_next: function({AzyLine}): integer
  _cursor_set: boolean

  _current_prompt: string|nil
  _current_lines: {AzyLine}
  _hl_positions: {{integer}}
  _hl_offset: integer

  _search_result_cache: {string: {{AzyLine},{{integer}}}}
  _search_text_cache: {string:AzyLine}

  _input_buf: vim.api.BufNr
  _input_win: vim.api.WinNr
  _output_buf: vim.api.BufNr
  _output_win: vim.api.WinNr

  _running: boolean
end

function AzyUi.create(content: {AzyElement|string}, callback: function(AzyElement))
  log("Creating with", #content, "elements")
  vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
  AzyUi._callback = callback or function(i: AzyElement) vim.notify(i.search_text) end
  AzyUi._hl_positions = {}
  AzyUi._search_result_cache = {}
  AzyUi._search_text_cache = {}
  AzyUi._current_prompt = nil
  AzyUi._selected = nil
  AzyUi._source_lines = vim.tbl_map(function(e: AzyElement|string): AzyLine
    local toel: AzyLine
    if e is string then
      toel = { content = { search_text = e } }
    else
      toel = { content = e }
    end
    AzyUi._search_text_cache[toel.content.search_text] = toel
    return toel
  end, content)
  AzyUi._input_buf = vim.api.nvim_create_buf(false, true)
  AzyUi._output_buf = vim.api.nvim_create_buf(false, true)

  -- Now create the windows
  local columns = vim.o.columns
  local lines = vim.o.lines

  local display_height = 20
  local input_row = lines - (display_height + 2)

  AzyUi._input_win = vim.api.nvim_open_win(AzyUi._input_buf, true, {
    relative = 'editor',
    anchor = 'NW',
    width = columns,
    height = 1,
    row = input_row,
    col = 0,
    focusable = true,
    style = 'minimal',
    border = 'none',
  })

  vim.api.nvim_win_set_option(AzyUi._input_win, 'winblend', 0)
  AzyUi._output_win = vim.api.nvim_open_win(AzyUi._output_buf, false, {
    relative = 'editor',
    anchor = 'NW',
    width = columns,
    height = display_height,
    row = input_row + 1,
    col = 0,
    focusable = false,
    style = 'minimal',
    border = 'none',
    noautocmd = true,
  })
  vim.api.nvim_win_set_option(AzyUi._output_win, 'winblend', 0)

  -- Text changed autocommands
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    buffer = AzyUi._input_buf,
    callback = AzyUi._update_output_buf,
    group = AUGROUP_NAME
  })

  -- Exit autocommands
  vim.api.nvim_create_autocmd({"BufUnload", "BufDelete", "BufWipeout", "BufLeave"}, {
    buffer = AzyUi._input_buf,
    callback = AzyUi._close,
    group = AUGROUP_NAME
  })

  -- Mappings
  vim.keymap.set({"n", "i"}, "<Down>", AzyUi.next, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<Up>", AzyUi.prev, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<CR>", AzyUi.confirm, { buffer = AzyUi._input_buf })
  vim.keymap.set("n", "<ESC>", AzyUi.exit, { buffer = AzyUi._input_buf })

  AzyUi._running = true
  AzyUi._update_output_buf()
  vim.cmd.startinsert()
end

function AzyUi._pick_next(direction: integer): integer
  for i,sline in ipairs(AzyUi._current_lines) do
    local next_item = AzyUi._current_lines[i + direction]
    if sline == AzyUi._selected and next_item then
      AzyUi._selected = next_item
      AzyUi._redraw_lines { i, i + direction }
      return
    end
  end
end

function AzyUi.confirm()
  AzyUi._close()
  if AzyUi._selected then
    AzyUi._callback(AzyUi._selected.content)
  end
  AzyUi._destroy()
end

function AzyUi.next()
  AzyUi._pick_next(1)
end

function AzyUi.prev()
  AzyUi._pick_next(-1)
end

function AzyUi._close()
  AzyUi._running = false
  vim.cmd.stopinsert()
  if vim.api.nvim_win_is_valid(AzyUi._input_win) then
    vim.api.nvim_win_close(AzyUi._input_win, true)
  end
  if vim.api.nvim_win_is_valid(AzyUi._output_win) then
    vim.api.nvim_win_close(AzyUi._output_win, true)
  end
end

function AzyUi.exit()
  AzyUi._close()
  AzyUi._destroy()
end

function AzyUi._destroy()
  log "Destroying"
  AzyUi._current_lines = {}
  AzyUi._hl_positions = {}
  AzyUi._search_result_cache = {}
  AzyUi._search_text_cache = {}
  AzyUi._source_lines = {}
end

function AzyUi._update_output_buf()
  local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

  if AzyUi._current_prompt and AzyUi._current_prompt == iline then
    -- For some reason we called this function twice in a row
    -- This may happen if something increments the changed_tick without actually changing the
    -- buffer content
    return
  end

  time_this("Update", function()
    if #iline > 0 then
      local cached = AzyUi._search_result_cache[iline]
      if cached then
        AzyUi._current_lines = cached[1]
        AzyUi._hl_positions = cached[2]
      else
        local result: {{string, {integer}, integer}}
        time_this("Filter", function()
          result = fzy.filter(iline, vim.tbl_map(function(e: AzyLine): string
            return e.content.search_text
          end, AzyUi._current_lines), false)
        end)

        time_this("Sort", function()
          table.sort(result, function(a: {string, {integer}, integer}, b: {string, {integer}, integer}): boolean
            if a[3] == b[3] then
              return #a[1] > #b[1]
            else
              return a[3] > b[3]
            end
          end)
        end)

        time_this("Insert", function()
          AzyUi._current_lines = {}
          AzyUi._hl_positions = {}
          -- For each filtered line, find the corresponding source line
          for _, r in ipairs(result) do
            local source_line: AzyLine = AzyUi._search_text_cache[r[1]]
            table.insert(AzyUi._current_lines, source_line)
            table.insert(AzyUi._hl_positions, r[2])
          end
        end)

        AzyUi._search_result_cache[iline] = {AzyUi._current_lines, AzyUi._hl_positions}
      end
    else
      AzyUi._current_lines = AzyUi._source_lines
      AzyUi._hl_positions = {}
    end

    AzyUi._current_prompt = iline

    time_this("Cursor correction", function()
      if vim.tbl_contains(AzyUi._current_lines, AzyUi._selected) then
        return
      end

      if #AzyUi._current_lines > 0 then
        AzyUi._selected = AzyUi._current_lines[1]
      end
    end)

    AzyUi._redraw()
  end)
end

function AzyUi._redraw()
  time_this("Redraw", function()
    local lines_to_draw: {string} = {}
    vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)

    local sel_line: integer = 0
    local hl_offset: integer = 0
    time_this("Build lines", function()
      for i, line in ipairs(AzyUi._current_lines) do
        local line_selected: boolean = line == AzyUi._selected
        if line_selected then
          sel_line = i
        end
        local l, off = format_line(line, line_selected)
        if hl_offset == 0 then
          hl_offset = off
        elseif hl_offset ~= off then
          error "Inconsistent highlight offset"
        end
        table.insert(lines_to_draw, l)
      end
    end)

    time_this("Set lines", function()
      AzyUi._hl_offset = hl_offset
      vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)
    end)

    if sel_line ~= 0 then
      vim.api.nvim_win_set_cursor(AzyUi._output_win, {sel_line, 0})
    end
  end)
end

function AzyUi._redraw_lines(lines: {integer})
  for _, i in ipairs(lines) do
    if AzyUi._current_lines[i] then
      local fmt, off = format_line(AzyUi._current_lines[i],
        AzyUi._current_lines[i] == AzyUi._selected)

      if off ~= AzyUi._hl_offset then
        error "Inconsistent highlight offset"
      end

      if AzyUi._current_lines[i] == AzyUi._selected then
        vim.api.nvim_win_set_cursor(AzyUi._output_win, {i, 0})
      end

      vim.api.nvim_buf_set_lines(AzyUi._output_buf, i - 1, i, true, { fmt })
    end
  end
end

local set_extmark = vim.api.nvim_buf_set_extmark

local function on_line(_: string, _: vim.api.WinNr, buf: vim.api.BufNr, row: integer): boolean
  local off = AzyUi._hl_offset
  for _,hl in ipairs(AzyUi._hl_positions[row + 1] or {}) do
    -- The highlight is offset by two characters
    set_extmark(buf, hl_ns, row, hl - 1 + off, {
      end_col = hl + off,
      hl_group = "Error",
      ephemeral = true
    })
  end
end

local function on_start(): boolean
  return AzyUi._running
end

local function on_win(_: string, win: vim.api.WinNr): boolean
  return win == AzyUi._output_win
end

local function on_buf(_: string, buf: vim.api.BufNr): boolean
  return buf == AzyUi._output_buf
end

vim.api.nvim_set_decoration_provider(hl_ns, {
  on_start = on_start,
  on_buf = on_buf,
  on_win = on_win,
  on_line = on_line
})

return AzyUi
