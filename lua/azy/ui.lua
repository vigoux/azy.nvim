local fzy = require('fzy')
local config = require('azy.config')
local AUGROUP_NAME = "AzyUi"
local hl_ns = vim.api.nvim_create_namespace('azy')

local HEIGHT = 20










local AzyUi = {}










































local function create_throwaway()
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
   return buf
end

local function create_win(check, buf, enter, options)
   if check and vim.api.nvim_win_is_valid(check) then
      vim.api.nvim_win_close(check, true)
   end
   local winconfig = vim.tbl_extend('force', {
      relative = 'editor',
      anchor = 'NW',
      col = 0,
      focusable = true,
      style = 'minimal',
      border = 'none',
   }, options)
   local win = vim.api.nvim_open_win(buf, enter, winconfig)
   vim.api.nvim_win_set_option(win, 'winblend', 0)
   vim.api.nvim_win_set_option(win, 'wrap', false)
   return win
end

function AzyUi.create(content, callback)
   config.log("Creating with", #content, "elements")
   vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
   AzyUi._callback = callback or function(i) vim.notify(i.search_text) end
   AzyUi._prompt = ""
   AzyUi._previous_bufs = vim.api.nvim_list_bufs()

   AzyUi._preview_cache = {}

   AzyUi._search_text_cache = {}
   AzyUi._source_lines = {}
   local all_lines = {}
   for i = 1, #content do
      local e = content[i]
      local toel
      if type(e) == "string" then
         toel = { content = { search_text = e } }
      else
         toel = { content = e }
      end
      if AzyUi._search_text_cache[toel.content.search_text] then
         config.log(string.format("Collision in search text cache: '%s'", toel.content.search_text))
      else
         AzyUi._search_text_cache[toel.content.search_text] = toel
         AzyUi._source_lines[#AzyUi._source_lines + 1] = toel
         all_lines[#all_lines + 1] = toel.content.search_text
      end
   end

   AzyUi._choices = fzy.create()
   AzyUi._choices:add(all_lines)


   AzyUi._input_buf = create_throwaway()
   AzyUi._output_buf = create_throwaway()


   local columns = vim.o.columns
   local lines = vim.o.lines

   local output_width
   if config.cfg.preview then
      output_width = math.ceil(columns / 2)
   else
      output_width = columns
   end

   local input_row = lines - (HEIGHT + 2)


   AzyUi._input_win = create_win(AzyUi._input_win, AzyUi._input_buf, true, {
      width = columns,
      height = 1,
      row = input_row,
      col = 0,
      focusable = true,
   })

   AzyUi._output_win = create_win(AzyUi._output_win, AzyUi._output_buf, false, {
      width = output_width,
      height = HEIGHT,
      row = input_row + 1,
      col = 0,
      focusable = false,
      noautocmd = true,
   })

   if config.cfg.preview then
      AzyUi._preview_win = create_win(AzyUi._preview_win, create_throwaway(), false, {
         width = math.floor(columns / 2),
         height = HEIGHT,
         row = input_row + 1,
         col = math.ceil(columns / 2),
         focusable = false,
         style = 'minimal',
         border = 'none',
      })
      vim.api.nvim_win_set_option(AzyUi._preview_win, 'winblend', 0)
   end


   vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._update_ui,
      group = AUGROUP_NAME,
   })


   vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout", "BufLeave" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._close,
      group = AUGROUP_NAME,
   })


   for mapping, fname in pairs(config.cfg.mappings) do
      vim.keymap.set({ "n", "i" }, mapping,
      (AzyUi)[fname], { buffer = AzyUi._input_buf })
   end
   vim.keymap.set("n", "<ESC>", AzyUi.exit, { buffer = AzyUi._input_buf })

   AzyUi._selected_index = 1
   AzyUi._redraw()
   vim.cmd.startinsert()
end

function AzyUi.add(lines)

   if not AzyUi._choices then return false end
   config.time_this("Update incremental", function()
      config.log(string.format("Will add %d elements to %d", #lines, #AzyUi._source_lines))
      local all_lines = {}

      for i = 1, #lines do
         local line = lines[i]
         local toel
         if type(line) == "string" then
            toel = { content = { search_text = line } }
         else
            toel = { content = line }
         end

         if AzyUi._search_text_cache[toel.content.search_text] then
            config.log(string.format("Collision in search text cache: '%s'", toel.content.search_text))
         else
            AzyUi._search_text_cache[toel.content.search_text] = toel
            all_lines[#all_lines + 1] = toel.content.search_text
            AzyUi._source_lines[#AzyUi._source_lines + 1] = toel
         end
      end

      config.time_this("Filter incremental", function()
         AzyUi._choices:add_incremental(all_lines)
      end)





      AzyUi._redraw()
   end)
   return true
end

function AzyUi.confirm(options)
   AzyUi._close()
   local selected = AzyUi._selected()
   if selected then
      if config.cfg.debug then
         AzyUi._callback(selected.content, options or {})
      else
         pcall(AzyUi._callback, selected.content, options or {})
      end
   end
   AzyUi._destroy()
end

function AzyUi.confirm_vsplit()
   AzyUi.confirm({ vsplit = true })
end

function AzyUi.confirm_split()
   AzyUi.confirm({ split = true })
end

function AzyUi._selected()
   if #AzyUi._prompt == 0 then
      return AzyUi._source_lines[AzyUi._selected_index], AzyUi._selected_index
   else
      local text, index = AzyUi._choices:selected()
      return AzyUi._search_text_cache[text], index
   end
end


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

   if config.cfg.preview then
      for _, entry in pairs(AzyUi._preview_cache) do
         if vim.api.nvim_buf_is_valid(entry.bufnr) and not vim.tbl_contains(AzyUi._previous_bufs, entry.bufnr) then
            vim.api.nvim_buf_delete(entry.bufnr, { force = true })
         end
      end

      if vim.api.nvim_win_is_valid(AzyUi._preview_win) then
         vim.api.nvim_win_close(AzyUi._preview_win, true)
      end
   end
end

function AzyUi.exit()
   AzyUi._close()
   AzyUi._destroy()
end

function AzyUi._destroy()
   config.log("Destroying")
   AzyUi._search_text_cache = {}
   AzyUi._source_lines = {}
   AzyUi._choices = nil
end

function AzyUi._update_ui()
   local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

   if AzyUi._prompt == iline then



      return
   end

   config.time_this(string.format("Update for %d elements", #AzyUi._source_lines), function()
      if #iline > 0 then
         config.time_this("Filter", function()
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
   config.time_this("Redraw", function()


      local start = 1
      local selected, current_selection = AzyUi._selected()
      current_selection = current_selection or 1
      if current_selection > HEIGHT then
         start = current_selection - HEIGHT + 1
         local available
         if #AzyUi._prompt == 0 then
            available = #AzyUi._source_lines
         else
            available = AzyUi._choices:available()
         end
         if start + HEIGHT > available and available > 0 then
            start = available - HEIGHT + 1
         end
      end

      local function for_each_displayed_line(func)
         for i = start, start + HEIGHT do
            local line
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

      local lines_to_draw = {}


      local hl_offset = 2
      config.time_this("Build lines", function()
         for_each_displayed_line(function(line)
            local preff
            if line == selected then
               preff = "> "
            else
               preff = "  "
            end
            lines_to_draw[#lines_to_draw + 1] = preff .. line.content.search_text
         end)
      end)

      config.time_this("Set lines", function()
         vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, lines_to_draw)
      end)

      config.time_this("Highlight lines", function()
         vim.api.nvim_buf_clear_namespace(AzyUi._output_buf, hl_ns, 0, -1)
         for_each_displayed_line(function(line, row)
            local score, positions = fzy.match(AzyUi._prompt, line.content.search_text)
            if not score then
               error("Inconsistent state")
            end

            if config.cfg.debug and AzyUi._prompt and #AzyUi._prompt > 0 then
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
                  virt_text_pos = "right_align",
               })
            end
            for _, hl in ipairs(positions) do

               set_extmark(AzyUi._output_buf, hl_ns, row - 1, hl - 1 + hl_offset, {
                  end_col = hl + hl_offset,
                  hl_group = config.HL_MATCH,
               })
            end
         end)
      end)

      if config.cfg.preview then
         config.time_this("Update preview", function()
            if not selected then
               config.log("Nothing selected")
               vim.api.nvim_win_set_buf(AzyUi._preview_win, create_throwaway())
            else
               local cache_entry = AzyUi._preview_cache[selected]
               if cache_entry then
                  vim.api.nvim_win_set_buf(AzyUi._preview_win, cache_entry.bufnr)
                  vim.api.nvim_win_set_cursor(AzyUi._preview_win, cache_entry.cursor)
               else
                  vim.api.nvim_win_call(AzyUi._preview_win, function()
                     AzyUi._callback(selected.content, { preview = true })
                  end)
                  AzyUi._preview_cache[selected] = {
                     bufnr = vim.api.nvim_win_get_buf(AzyUi._preview_win),
                     cursor = vim.api.nvim_win_get_cursor(AzyUi._preview_win),
                  }
               end
            end

            vim.api.nvim_win_set_option(AzyUi._preview_win, 'cursorline', true)
            vim.api.nvim_win_set_option(AzyUi._preview_win, 'cursorlineopt', 'line')
         end)
      end
   end)
end

return AzyUi
