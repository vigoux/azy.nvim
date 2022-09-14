local fzy = require('fzy-lua-native')
local hl_ns = vim.api.nvim_create_namespace('azy')

local add_highlight = vim.api.nvim_buf_add_highlight

local log
local time_this

if vim.fn.exists("g:azy_ui_debug") == 1 then
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

local AzyLine = {}












local function format_line(line)
   if line.selected then
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
   AzyUi._callback = callback or function(i) vim.notify(i.search_text) end
   AzyUi._hl_positions = {}
   AzyUi._search_result_cache = {}
   AzyUi._search_text_cache = {}
   AzyUi._source_lines = vim.tbl_map(function(e)
      local toel
      if type(e) == "string" then
         toel = { content = { search_text = e }, selected = false }
      else
         toel = { content = e, selected = false }
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
   })


   vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout", "BufLeave" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._close,
   })


   vim.keymap.set({ "n", "i" }, "<Down>", AzyUi.next, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<Up>", AzyUi.prev, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<CR>", AzyUi.confirm, { buffer = AzyUi._input_buf })
   vim.keymap.set("n", "<ESC>", AzyUi.exit, { buffer = AzyUi._input_buf })

   AzyUi._update_output_buf()
   vim.cmd.startinsert()
end

function AzyUi._pick_next(direction)
   for i, sline in ipairs(AzyUi._current_lines) do
      if sline.selected then
         local next_item = AzyUi._current_lines[i + direction]
         if next_item then
            sline.selected = false
            next_item.selected = true
            AzyUi._redraw_lines({ i, i + direction })
            return
         end
      end
   end
end

function AzyUi.confirm()
   AzyUi._close()
   local selected = vim.tbl_filter(function(e) return e.selected end, AzyUi._current_lines)[1]
   if selected then
      AzyUi._callback(selected.content)
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
   AzyUi._hl_positions = {}
   AzyUi._search_result_cache = {}
   AzyUi._search_text_cache = {}
   AzyUi._source_lines = {}
end

function AzyUi._update_output_buf()

   time_this("Update", function()

      local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]
      if #iline > 0 then
         local cached = AzyUi._search_result_cache[iline]
         if cached then
            AzyUi._current_lines = cached[1]
            AzyUi._hl_positions = cached[2]
         else
            local result
            time_this("Filter", function()
               result = fzy.filter(iline, vim.tbl_map(function(e)
                  return e.content.search_text
               end, AzyUi._current_lines), false)
            end)

            time_this("Sort", function()
               table.sort(result, function(a, b)
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

               for _, r in ipairs(result) do
                  local source_line = AzyUi._search_text_cache[r[1]]
                  table.insert(AzyUi._current_lines, source_line)
                  table.insert(AzyUi._hl_positions, r[2])
               end
            end)

            AzyUi._search_result_cache[iline] = { AzyUi._current_lines, AzyUi._hl_positions }
         end
      else
         AzyUi._current_lines = AzyUi._source_lines
         AzyUi._hl_positions = {}
      end

      time_this("Cursor correction", function()

         local selected_index = 0
         for i, sline in ipairs(AzyUi._current_lines) do
            if sline.selected and selected_index == 0 then
               selected_index = i
            end
         end


         if selected_index == 0 and #AzyUi._current_lines > 0 then
            for _, sline in ipairs(AzyUi._source_lines) do
               sline.selected = false
            end
            AzyUi._current_lines[1].selected = true
         end
      end)

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
            if line.selected then
               sel_line = i
            end
            local l, off = format_line(line)
            if hl_offset == 0 then
               hl_offset = off
            elseif hl_offset ~= off then
               error("Inconsistent highlight offset")
            end
            table.insert(lines_to_draw, l)
         end
      end)



      vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)

      if sel_line ~= 0 then
         vim.api.nvim_win_set_cursor(AzyUi._output_win, { sel_line, 0 })
      end

      time_this("Highlight", function()
         for i, hls in ipairs(AzyUi._hl_positions) do
            for _, hl in ipairs(hls) do

               add_highlight(AzyUi._output_buf, hl_ns, "Error", i - 1, hl - 1 + hl_offset, hl + hl_offset)
            end
         end
      end)
   end)
end

function AzyUi._redraw_lines(lines)
   for _, i in ipairs(lines) do
      if AzyUi._current_lines[i] then
         local fmt, off = format_line(AzyUi._current_lines[i])

         if AzyUi._current_lines[i].selected then
            vim.api.nvim_win_set_cursor(AzyUi._output_win, { i, 0 })
         end

         vim.api.nvim_buf_set_lines(AzyUi._output_buf, i - 1, i, true, { fmt })
         for _, hl in ipairs(AzyUi._hl_positions[i] or {}) do

            add_highlight(AzyUi._output_buf, hl_ns, "Error", i - 1, hl - 1 + off, hl + off)
         end
      end
   end
end

return AzyUi
