local fzy = require'fzy-lua-native'
local hl_ns = vim.api.nvim_create_namespace 'azy'

local log: function(...: any)

if vim.fn.exists "g:azy_ui_debug" == 1 then
  print("AzyUi debugging enabled")
  log = function(...: any)
    print("AzyUi:", ...)
  end
else
  log = function()
  end
end

local record AzyLine
  content: AzyElement
  selected: boolean
end

local record AzyUi
  create: function({AzyElement|string}, function(AzyElement))
  next: function()
  prev: function()
  close: function()
  confirm: function()

  -- Private stuff
  _source_lines: {AzyLine}
  _callback: function(AzyElement)

  -- Useful to handle cursor navigation and redrawing
  _update_output_buf: function()
  _redraw: function()
  _pick_next: function({AzyLine})

  _current_lines: {AzyLine}
  _hl_positions: {{integer}}

  _search_result_cache: {string: {{AzyLine},{{integer}}}}
  _search_text_cache: {string:AzyLine}

  _input_buf: vim.api.BufNr
  _input_win: vim.api.WinNr
  _output_buf: vim.api.BufNr
  _output_win: vim.api.WinNr
end

function AzyUi.create(content: {AzyElement|string}, callback: function(AzyElement))
  AzyUi._callback = callback or function(i: AzyElement) vim.notify(i.search_text) end
  AzyUi._hl_positions = {}
  AzyUi._search_result_cache = {}
  AzyUi._search_text_cache = {}
  AzyUi._source_lines = vim.tbl_map(function(e: AzyElement|string): AzyLine
    local toel: AzyLine
    if e is string then
      toel = { content = { search_text = e }, selected = false }
    else
      toel = { content = e, selected = false }
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
    callback = AzyUi._update_output_buf
  })

  -- Exit autocommands
  vim.api.nvim_create_autocmd({"BufUnload", "BufDelete", "BufWipeout", "BufLeave"}, {
    buffer = AzyUi._input_buf,
    callback = AzyUi.close
  })

  -- Mappings
  vim.keymap.set({"n", "i"}, "<Down>", AzyUi.next, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<Up>", AzyUi.prev, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<CR>", AzyUi.confirm, { buffer = AzyUi._input_buf })
  vim.keymap.set("n", "<ESC>", AzyUi.close, { buffer = AzyUi._input_buf })

  AzyUi._update_output_buf()
  vim.cmd.startinsert()
end

function AzyUi._pick_next(inlines: {AzyLine})
  local found_selected: boolean = false

  for i,sline in ipairs(inlines) do
    if found_selected then
      sline.selected = true
      AzyUi._update_output_buf()
      return
    end
    if sline.selected and i < #inlines then
      found_selected = true
      sline.selected = false
    end
  end

  -- We only get here when we are on the last line, no need to redraw
  AzyUi._redraw()
end

function AzyUi.confirm()
  AzyUi.close()
  local selected = vim.tbl_filter(function(e: AzyLine): boolean return e.selected end, AzyUi._current_lines)[1]
  if selected then
    AzyUi._callback(selected.content)
  end
end

function AzyUi.next()
  AzyUi._pick_next(AzyUi._current_lines)
end

function AzyUi.prev()
  local tmp: {AzyLine} = {}
  for _,l in ipairs(AzyUi._current_lines) do
    table.insert(tmp, 1, l)
  end
  AzyUi._pick_next(tmp)
end

function AzyUi.close()
  vim.cmd.stopinsert()
  if vim.api.nvim_win_is_valid(AzyUi._input_win) then
    vim.api.nvim_win_close(AzyUi._input_win, true)
  end
  if vim.api.nvim_win_is_valid(AzyUi._output_win) then
    vim.api.nvim_win_close(AzyUi._output_win, true)
  end
end

function AzyUi._update_output_buf()
  -- For total time
  log "Redraw start"
  local start_time = vim.loop.hrtime()

  -- For incremental time
  local t: integer
  local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]
  if #iline > 0 then
    local cached = AzyUi._search_result_cache[iline]
    if cached then
      AzyUi._current_lines = cached[1]
      AzyUi._hl_positions = cached[2]
    else
      t = vim.loop.hrtime()
      local result = fzy.filter(iline, vim.tbl_map(function(e: AzyLine): string
        return e.content.search_text
      end, AzyUi._current_lines), false)
      log("Filter time", (vim.loop.hrtime() - t) / (1000 * 1000))

      t = vim.loop.hrtime()
      table.sort(result, function(a: {string, {integer}, integer}, b: {string, {integer}, integer}): boolean
        if a[3] == b[3] then
          return #a[1] > #b[1]
        else
          return a[3] > b[3]
        end
      end)
      log("Sort time", (vim.loop.hrtime() - t) / (1000 * 1000))

      AzyUi._current_lines = {}
      AzyUi._hl_positions = {}
      -- For each filtered line, find the corresponding source line
      t = vim.loop.hrtime()
      for _, r in ipairs(result) do
        local source_line: AzyLine = AzyUi._search_text_cache[r[1]]
        table.insert(AzyUi._current_lines, source_line)
        table.insert(AzyUi._hl_positions, r[2])
      end
      log("Create time", (vim.loop.hrtime() - t) / (1000 * 1000))

      AzyUi._search_result_cache[iline] = {AzyUi._current_lines, AzyUi._hl_positions}
    end
  else
    AzyUi._current_lines = AzyUi._source_lines
    AzyUi._hl_positions = {}
  end

  t = vim.loop.hrtime()
  -- Check if there is an element currently selected
  local selected_index: integer = 0
  for i, sline in ipairs(AzyUi._current_lines) do
    if sline.selected and selected_index == 0 then
      selected_index = i
    end
  end
  log("Correct selection", (vim.loop.hrtime() - t) / (1000 * 1000))

  -- If nothing is selected, select the first line
  if selected_index == 0 and #AzyUi._current_lines > 0 then
    for _, sline in ipairs(AzyUi._source_lines) do
      sline.selected = false
    end
    AzyUi._current_lines[1].selected = true
  end

  t = vim.loop.hrtime()
  AzyUi._redraw()
  log("Redraw time", (vim.loop.hrtime() - t) / (1000 * 1000))
  log("Total time", (vim.loop.hrtime() - start_time) / (1000 * 1000))
end

function AzyUi._redraw()
  local lines_to_draw: {string} = {}
  vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)
  for _, line in ipairs(AzyUi._current_lines) do
    if line.selected then
      table.insert(lines_to_draw, "> " .. line.content.search_text)
    else
      table.insert(lines_to_draw, "  " .. line.content.search_text)
    end
  end

  vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)

  for i,hls in ipairs(AzyUi._hl_positions) do
    for _,hl in ipairs(hls) do
      -- The highlight is offset by two characters
      vim.api.nvim_buf_add_highlight(AzyUi._output_buf, hl_ns, "Error", i - 1, hl + 1, hl + 2)
    end
  end
end

return AzyUi
