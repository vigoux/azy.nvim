local fzy = require('fzy-lua-native')
local AUGROUP_NAME = "AzyUi"
local hl_ns = vim.api.nvim_create_namespace('azy')

local log
local time_this

local DEBUG = vim.fn.exists("g:azy_ui_debug") == 1
if DEBUG then
   print("AzyUi debugging enabled")
   log = function(...)
      print("AzyUi:", ...)
   end

   local htime = vim.loop.hrtime

   local level = 0
   time_this = function(msg, f)
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

   time_this = function(_, f)
      f()
   end
end













local function format_line(line, selected)
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

local AzyUi = {}




































function AzyUi.create(content, callback)
   log("Creating with", #content, "elements")
   vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
   AzyUi._callback = callback or function(i) vim.notify(i.search_text) end
   AzyUi._search_result_cache = {}
   AzyUi._search_text_cache = {}
   AzyUi._current_prompt = nil
   AzyUi._selected = nil
   AzyUi._source_lines = vim.tbl_map(function(e)
      local toel
      if type(e) == "string" then
         toel = { content = { search_text = e } }
      else
         toel = { content = e }
      end
      AzyUi._search_text_cache[toel.content.search_text] = toel
      return toel
   end, content)
   AzyUi._input_buf = vim.api.nvim_create_buf(false, true)
   AzyUi._output_buf = vim.api.nvim_create_buf(false, true)


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


   vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._update_output_buf,
      group = AUGROUP_NAME,
   })


   vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout", "BufLeave" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._close,
      group = AUGROUP_NAME,
   })


   vim.keymap.set({ "n", "i" }, "<Down>", AzyUi.next, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<Up>", AzyUi.prev, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<CR>", AzyUi.confirm, { buffer = AzyUi._input_buf })
   vim.keymap.set("n", "<ESC>", AzyUi.exit, { buffer = AzyUi._input_buf })

   AzyUi._running = true
   AzyUi._update_output_buf()
   vim.cmd.startinsert()
end

function AzyUi._pick_next(direction)
   for i = 1, #AzyUi._current_lines do
      local sline = AzyUi._current_lines[i]
      local next_item = AzyUi._current_lines[i + direction]
      if sline == AzyUi._selected and next_item then
         AzyUi._selected = next_item
         AzyUi._redraw_lines({ i, i + direction })
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
   log("Destroying")
   AzyUi._current_lines = {}
   AzyUi._search_result_cache = {}
   AzyUi._search_text_cache = {}
   AzyUi._source_lines = {}
end

function AzyUi._update_output_buf()
   local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

   if AzyUi._current_prompt and AzyUi._current_prompt == iline then



      return
   end

   time_this("Update", function()
      if #iline > 0 then
         local cached = AzyUi._search_result_cache[iline]
         if cached then
            AzyUi._current_lines = cached
         else
            local result
            time_this("Filter", function()
               local lines = {}
               local clines = AzyUi._current_lines
               for i = 1, #clines do
                  lines[i] = clines[i].content.search_text
               end
               result = fzy.match_many(iline, lines, false)
            end)

            time_this("Sort", function()
               table.sort(result, function(a, b)
                  if a[2] == b[2] then
                     return #a[1] < #b[1]
                  else
                     return a[2] > b[2]
                  end
               end)
            end)

            time_this("Insert", function()
               local hlpos = {}
               local clines = {}

               for i = 1, #result do
                  local r = result[i]
                  clines[i] = AzyUi._search_text_cache[r[1]]
                  hlpos[i] = r[2]
               end
               AzyUi._current_lines = clines
            end)

            AzyUi._search_result_cache[iline] = AzyUi._current_lines
         end
      else
         AzyUi._current_lines = AzyUi._source_lines
      end

      AzyUi._current_prompt = iline

      AzyUi._selected = AzyUi._current_lines[1]

      AzyUi._redraw()
   end)
end

function AzyUi._redraw()
   time_this("Redraw", function()
      local lines_to_draw = {}
      vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)

      local sel_line = 0
      local hl_offset = 0
      time_this("Build lines", function()
         for i, line in ipairs(AzyUi._current_lines) do
            local line_selected = line == AzyUi._selected
            if line_selected then
               sel_line = i
            end
            local l, off = format_line(line, line_selected)
            if hl_offset == 0 then
               hl_offset = off
            elseif hl_offset ~= off then
               error("Inconsistent highlight offset")
            end
            lines_to_draw[i] = l
         end
      end)

      time_this("Set lines", function()
         AzyUi._hl_offset = hl_offset
         vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)
      end)

      if sel_line ~= 0 then
         vim.api.nvim_win_set_cursor(AzyUi._output_win, { sel_line, 0 })
      end
   end)
end

function AzyUi._redraw_lines(lines)
   for _, i in ipairs(lines) do
      if AzyUi._current_lines[i] then
         local fmt, off = format_line(AzyUi._current_lines[i],
         AzyUi._current_lines[i] == AzyUi._selected)

         if off ~= AzyUi._hl_offset then
            error("Inconsistent highlight offset")
         end

         if AzyUi._current_lines[i] == AzyUi._selected then
            vim.api.nvim_win_set_cursor(AzyUi._output_win, { i, 0 })
         end

         vim.api.nvim_buf_set_lines(AzyUi._output_buf, i - 1, i, true, { fmt })
      end
   end
end

local set_extmark = vim.api.nvim_buf_set_extmark

local function on_line(_, _, buf, row)
   local off = AzyUi._hl_offset
   local line = AzyUi._current_lines[row + 1]
   if not line then return end

   local score = fzy.score(AzyUi._current_prompt, line.content.search_text, false)
   if DEBUG and AzyUi._current_prompt and #AzyUi._current_prompt > 0 then
      set_extmark(buf, hl_ns, row, 0, {
         ephemeral = true,
         virt_text = { { tostring(score), "Comment" } },
         virt_text_pos = "right_align",
      })
   end
   for _, hl in ipairs(fzy.positions(AzyUi._current_prompt, line.content.search_text, false)) do

      set_extmark(buf, hl_ns, row, hl - 1 + off, {
         end_col = hl + off,
         hl_group = "Error",
         ephemeral = true,
      })
   end
end

local function on_start()
   return AzyUi._running
end

local function on_win(_, win)
   return win == AzyUi._output_win
end

local function on_buf(_, buf)
   return buf == AzyUi._output_buf
end

vim.api.nvim_set_decoration_provider(hl_ns, {
   on_start = on_start,
   on_buf = on_buf,
   on_win = on_win,
   on_line = on_line,
})

return AzyUi
