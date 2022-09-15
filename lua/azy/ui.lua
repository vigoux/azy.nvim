local fzy = require('fzy')
local AUGROUP_NAME = "AzyUi"
local hl_ns = vim.api.nvim_create_namespace('azy')

local log
local time_this

local HEIGHT = 20
local DEBUG = vim.fn.exists("g:azy_ui_debug") == 1
if DEBUG then
   print("AzyUi debugging enabled")
   log = function(...)
      print("AzyUi:", ...)
   end

   local htime = vim.loop.hrtime

   local level = 0
   time_this = function(msg, f)
      local arrow_head
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

   time_this = function(_, f)
      f()
   end
end

local AzyLine = {}











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
   AzyUi._current_prompt = ""

   AzyUi._search_text_cache = {}
   local all_lines = {}
   AzyUi._source_lines = vim.tbl_map(function(e)
      local toel
      if type(e) == "string" then
         toel = { content = { search_text = e } }
      else
         toel = { content = e }
      end
      AzyUi._search_text_cache[toel.content.search_text] = toel
      all_lines[#all_lines + 1] = toel.content.search_text
      return toel
   end, content)

   AzyUi._choices = fzy.create()
   AzyUi._choices:add(all_lines)

   AzyUi._input_buf = vim.api.nvim_create_buf(false, true)
   AzyUi._output_buf = vim.api.nvim_create_buf(false, true)


   local columns = vim.o.columns
   local lines = vim.o.lines

   local input_row = lines - (HEIGHT + 2)

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
      height = HEIGHT,
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

   AzyUi._redraw()
   vim.cmd.startinsert()
end

function AzyUi.confirm()
   AzyUi._close()
   local selected = AzyUi._choices:selected()
   if selected then
      AzyUi._callback(AzyUi._search_text_cache[selected].content)
   end
   AzyUi._destroy()
end

function AzyUi.next()
   AzyUi._choices:next()
   AzyUi._redraw()
end

function AzyUi.prev()
   AzyUi._choices:prev()
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
   log("Destroying")
   AzyUi._search_text_cache = {}
   AzyUi._source_lines = {}
   AzyUi._choices = nil
end

function AzyUi._update_output_buf()
   local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

   if AzyUi._current_prompt and AzyUi._current_prompt == iline then



      return
   end

   time_this("Update", function()
      if #iline > 0 then
         time_this("Filter", function()
            AzyUi._choices:search(iline)
         end)
      end

      AzyUi._current_prompt = iline
      AzyUi._redraw()
   end)
end

local set_extmark = vim.api.nvim_buf_set_extmark
function AzyUi._redraw()
   time_this("Redraw", function()
      local start = 1
      local selected_text, current_selection = AzyUi._choices:selected()
      current_selection = current_selection or 1
      if current_selection > HEIGHT then
         start = current_selection - HEIGHT + 1
         local available = AzyUi._choices:available()
         if start + HEIGHT > available and available > 0 then
            start = available - HEIGHT + 1
         end
      end

      local function for_each_displayed_line(func)
         if AzyUi._choices:available() == 0 and #AzyUi._current_prompt > 0 then
            return
         end

         for i = start, start + HEIGHT do
            local line
            if #AzyUi._current_prompt == 0 then
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

      local lines_to_draw = {}


      local hl_offset = 0
      local selected = AzyUi._search_text_cache[selected_text] or AzyUi._source_lines[1]
      time_this("Build lines", function()
         for_each_displayed_line(function(line)
            local l, off = format_line(line, line == selected)
            if hl_offset == 0 then
               hl_offset = off
            elseif hl_offset ~= off then
               error("Inconsistent highlight offset")
            end
            lines_to_draw[#lines_to_draw + 1] = l
         end)
      end)

      time_this("Set lines", function()
         vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)
      end)

      time_this("Highlight lines", function()
         vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)
         for_each_displayed_line(function(line, row)
            local score, positions = fzy.match(AzyUi._current_prompt, line.content.search_text)
            if not score then
               error("Inconsistent state")
            end

            if DEBUG and AzyUi._current_prompt and #AzyUi._current_prompt > 0 then
               set_extmark(AzyUi._output_buf, hl_ns, row - 1, 0, {
                  virt_text = { { tostring(score), "Comment" } },
                  virt_text_pos = "right_align",
               })
            end
            for _, hl in ipairs(positions) do

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
