local fzy = require'fzy'
local config = require'azy.config'
local AUGROUP_NAME = "AzyUi"
local hl_ns = vim.api.nvim_create_namespace 'azy'

local log: function(...: any)
local time_this: function(string, function())

local HEIGHT = 20
local DEBUG = vim.fn.exists "g:azy_ui_debug" == 1
if DEBUG then
  print("AzyUi debugging enabled")
  log = function(...: any)
    print("AzyUi:", ...)
  end

  local htime = vim.loop.hrtime

  local level = 0
  time_this = function(msg: string, f: function())
    local arrow_head: string
    if level > 0 then
      arrow_head = vim.fn['repeat'](' ', 2 * level - 1)
      log(arrow_head, msg)
    else
      log(msg)
    end

    level = level + 1
    local t = htime()
    f()
    local stop_time = htime() - t
    level = level - 1

    if level > 0 then
      log(arrow_head, msg, ":", stop_time / (1000 * 1000))
    else
      log(msg, ":", stop_time / (1000 * 1000))
    end
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
end

local record AzyUi
  create: function({AzyElement|string}, function(AzyElement))

  -- @return Whether the UI is still alive
  add: function({AzyElement|string}): boolean
  next: function()
  prev: function()
  exit: function()
  confirm: function(AzyCbModifiers)

  -- Private stuff
  _close: function()
  _destroy: function()
  _source_lines: {AzyLine}
  _callback: function(AzyElement, AzyCbModifiers)

  -- Main update function, refreshs the whole buffer
  _update_output_buf: function()
  _redraw: function()

  -- Utilities to help with searching and filtering
  _prompt: string|nil
  _search_text_cache: {string:AzyLine}

  -- Scroll handling
  _selected: function(): AzyLine, integer
  _selected_index: integer

  -- UI from the nvim POV
  _input_buf: vim.BufNr
  _input_win: vim.WinNr
  _output_buf: vim.BufNr
  _output_win: vim.WinNr

  -- Main part of the thing
  _choices: fzy.Choices
end

function AzyUi.create(content: {AzyElement|string}, callback: function(AzyElement, AzyCbModifiers))
  log("Creating with", #content, "elements")
  vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
  AzyUi._callback = callback or function(i: AzyElement) vim.notify(i.search_text) end
  AzyUi._prompt = ""

  AzyUi._search_text_cache = {}
  local all_lines = {}
  AzyUi._source_lines = vim.tbl_map(function(e: AzyElement|string): AzyLine
    local toel: AzyLine
    if e is string then
      toel = { content = { search_text = e } }
    else
      toel = { content = e }
    end
    if AzyUi._search_text_cache[toel.content.search_text] then
      vim.notify(
        string.format("Collision in search text cache: '%s'", toel.content.search_text),
        vim.log.levels.INFO,
        {
          title = "azy.nvim"
        })
    end
    AzyUi._search_text_cache[toel.content.search_text] = toel
    all_lines[#all_lines + 1] = toel.content.search_text
    return toel
  end, content)

  AzyUi._choices = fzy.create()
  AzyUi._choices:add(all_lines)

  AzyUi._input_buf = vim.api.nvim_create_buf(false, true)
  AzyUi._output_buf = vim.api.nvim_create_buf(false, true)

  -- Now create the windows
  local columns = vim.o.columns
  local lines = vim.o.lines

  local input_row = lines - (HEIGHT + 2)

  if AzyUi._input_win and vim.api.nvim_win_is_valid(AzyUi._input_win) then
    vim.api.nvim_win_close(AzyUi._input_win, true)
  end
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

  if AzyUi._output_win and vim.api.nvim_win_is_valid(AzyUi._output_win) then
    vim.api.nvim_win_close(AzyUi._output_win, true)
  end
  AzyUi._output_win = vim.api.nvim_open_win(AzyUi._output_buf, false, {
    relative = 'editor',
    anchor = 'NW',
    width = columns,
    height = HEIGHT,
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
  vim.keymap.set({"n", "i"}, "<CR>", function() AzyUi.confirm {} end, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<C-V>", function() AzyUi.confirm { vsplit = true } end, { buffer = AzyUi._input_buf })
  vim.keymap.set({"n", "i"}, "<C-H>", function() AzyUi.confirm { split = true } end, { buffer = AzyUi._input_buf })
  vim.keymap.set("n", "<ESC>", AzyUi.exit, { buffer = AzyUi._input_buf })

  AzyUi._selected_index = 1
  AzyUi._redraw()
  vim.cmd.startinsert()
end

function AzyUi.add(lines: {AzyElement|string}): boolean
  -- as this can be called asynchronously, check that the ui is valid
  if not AzyUi._choices then return false end
  time_this("Update incremental", function()
    log(string.format("Will add %d elements to %d", #lines, #AzyUi._source_lines))
    local all_lines = {}

    for i = 1,#lines do
      local line = lines[i]
      local toel: AzyLine
      if line is string then
        toel = { content = { search_text = line } }
      else
        toel = { content = line }
      end

      if AzyUi._search_text_cache[toel.content.search_text] then
        error(string.format("Collision in search text cache: '%s'", toel.content.search_text))
      else
        AzyUi._search_text_cache[toel.content.search_text] = toel
      end

      all_lines[#all_lines + 1] = toel.content.search_text
      AzyUi._source_lines[#AzyUi._source_lines + 1] = toel
    end

    time_this("Filter incremental", function()
      AzyUi._choices:add_incremental(all_lines)
    end)

    -- Nice thing: no need to update the cursor as:
    --  if the prompt is empty the lines will be _appended to the search_
    --  if not fzy handles the cursor navigation for us

    AzyUi._redraw()
  end)
  return true
end

function AzyUi.confirm(options: AzyCbModifiers)
  AzyUi._close()
  local selected = AzyUi._selected()
  if selected then
    if DEBUG then
      AzyUi._callback(selected.content, options or {})
    else
      pcall(AzyUi._callback, selected.content, options or {})
    end
  end
  AzyUi._destroy()
end

function AzyUi._selected(): AzyLine, integer
  if #AzyUi._prompt == 0 then
    return AzyUi._source_lines[AzyUi._selected_index], AzyUi._selected_index
  else
    local text, index = AzyUi._choices:selected()
    return AzyUi._search_text_cache[text], index
  end
end

-- We change the selected index even if it is not used, as it is probably faster that branching
function AzyUi.next()
  AzyUi._choices:next()
  AzyUi._selected_index = (AzyUi._selected_index % #AzyUi._source_lines) + 1
  AzyUi._redraw()
end

function AzyUi.prev()
  AzyUi._choices:prev()
  AzyUi._selected_index = ((AzyUi._selected_index - 2) % #AzyUi._source_lines) + 1
  AzyUi._redraw()
end

function AzyUi._close()
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
  AzyUi._search_text_cache = {}
  AzyUi._source_lines = {}
  AzyUi._choices = nil
end

function AzyUi._update_output_buf()
  local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

  if AzyUi._prompt == iline then
    -- For some reason we called this function twice in a row
    -- This may happen if something increments the changed_tick without actually changing the
    -- buffer content
    return
  end

  time_this(string.format("Update for %d elements", #AzyUi._source_lines), function()
    if #iline > 0 then
      time_this("Filter", function()
        AzyUi._choices:search(iline)
      end)
    end

    AzyUi._selected_index = 1
    AzyUi._prompt = iline
    AzyUi._redraw()
  end)
end

local set_extmark = vim.api.nvim_buf_set_extmark
function AzyUi._redraw()
  time_this("Redraw", function()
    local start: integer = 1
    local selected, current_selection = AzyUi._selected()
    current_selection = current_selection or 1
    if current_selection > HEIGHT then
      start = current_selection - HEIGHT + 1
      local available: integer
      if #AzyUi._prompt == 0 then
        available = #AzyUi._source_lines
      else
        available = AzyUi._choices:available()
      end
      if start + HEIGHT > available and available > 0 then
        start = available - HEIGHT + 1
      end
    end

    local function for_each_displayed_line(func: function(AzyLine, integer))
      for i = start,start+HEIGHT do
        local line: AzyLine
        if #AzyUi._prompt == 0 then
          line = AzyUi._source_lines[i]
        else
          line = AzyUi._search_text_cache[AzyUi._choices:get(i)]
        end

        if line then
          func(line, i - start + 1)
        else
          break
        end
      end
    end

    local lines_to_draw: {string} = {}

    -- Setting the cursor to the appropriate line has to be done later, after the lines are updated
    local hl_offset: integer = 2
    time_this("Build lines", function()
      for_each_displayed_line(function(line: AzyLine)
        local preff: string
        if line == selected then
          preff = "> "
        else
          preff = "  "
        end
        lines_to_draw[#lines_to_draw + 1] = preff .. line.content.search_text
      end)
    end)

    time_this("Set lines", function()
      vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)
    end)

    time_this("Highlight lines", function()
      vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)
      for_each_displayed_line(function(line: AzyLine, row: integer)
        local score, positions = fzy.match(AzyUi._prompt, line.content.search_text)
        if not score then
          error "Inconsistent state"
        end

        if DEBUG and AzyUi._prompt and #AzyUi._prompt > 0 then
          set_extmark(AzyUi._output_buf, hl_ns, row - 1, 0, {
            virt_text = { { tostring(score), config.HL_DIM } },
          })
        end

        if line.content.extra_infos then
          local virt_text = { unpack(line.content.extra_infos) }

          if line == selected then
            virt_text[#virt_text + 1] = { " <", "Normal" }
          else
            virt_text[#virt_text + 1] = { "  ", "Normal" }
          end

          set_extmark(AzyUi._output_buf, hl_ns, row - 1, 0, {
            virt_text = virt_text,
            virt_text_pos = "right_align"
          })
        end
        for _,hl in ipairs(positions) do
          -- The highlight is offset by two characters
          set_extmark(AzyUi._output_buf, hl_ns, row - 1, hl - 1 + hl_offset, {
            end_col = hl + hl_offset,
            hl_group = "Error",
          })
        end
      end)
    end)
  end)
end

return AzyUi
