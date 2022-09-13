local fzy = require('fzy-lua-native')
local hl_ns = vim.api.nvim_create_namespace('azy')

local AzyLine = {}




local AzyUi = {}























function AzyUi.create(content, callback)
   AzyUi._callback = callback or function(i) vim.notify(i.search_text) end
   AzyUi._hl_positions = {}
   AzyUi._source_lines = vim.tbl_map(function(e)
      if type(e) == "string" then
         return { content = { search_text = e }, selected = false }
      else
         return { content = e, selected = false }
      end
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
      callback = AzyUi.close,
   })


   vim.keymap.set({ "n", "i" }, "<Down>", AzyUi.next, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<Up>", AzyUi.prev, { buffer = AzyUi._input_buf })
   vim.keymap.set({ "n", "i" }, "<CR>", AzyUi.confirm, { buffer = AzyUi._input_buf })

   AzyUi._update_output_buf()
   vim.cmd.startinsert()
end

function AzyUi._pick_next(inlines)
   local found_selected = false

   for i, sline in ipairs(inlines) do
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


   AzyUi._redraw()
end

function AzyUi.confirm()
   AzyUi.close()
   local selected = vim.tbl_filter(function(e) return e.selected end, AzyUi._current_lines)[1]
   if selected then
      AzyUi._callback(selected.content)
   end
end

function AzyUi.next()
   AzyUi._pick_next(AzyUi._current_lines)
end

function AzyUi.prev()
   local tmp = {}
   for _, l in ipairs(AzyUi._current_lines) do
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
   local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]
   if #iline > 0 then
      local result = fzy.filter(iline, vim.tbl_map(function(e) return e.content.search_text
      end, AzyUi._source_lines), false)

      table.sort(result, function(a, b)
         return a[3] < b[3]
      end)

      AzyUi._current_lines = {}
      AzyUi._hl_positions = {}

      for _, r in ipairs(result) do
         local source_line = vim.tbl_filter(function(e)
            return e.content.search_text == r[1]
         end, AzyUi._source_lines)[1]
         table.insert(AzyUi._current_lines, source_line)
         table.insert(AzyUi._hl_positions, r[2])
      end

   else
      AzyUi._current_lines = AzyUi._source_lines
      AzyUi._hl_positions = {}
   end


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

   AzyUi._redraw()
end

function AzyUi._redraw()
   local lines_to_draw = {}
   vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)
   for _, line in ipairs(AzyUi._current_lines) do
      if line.selected then
         table.insert(lines_to_draw, "> " .. line.content.search_text)
      else
         table.insert(lines_to_draw, "  " .. line.content.search_text)
      end
   end

   vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)

   for i, hls in ipairs(AzyUi._hl_positions) do
      for _, hl in ipairs(hls) do

         vim.api.nvim_buf_add_highlight(AzyUi._output_buf, hl_ns, "Error", i - 1, hl + 1, hl + 2)
      end
   end
end

return AzyUi
