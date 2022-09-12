local fzy = require('fzy-lua-native')
local hl_ns = vim.api.nvim_create_namespace('azy')

local AzyUi = {}









function AzyUi.create(content)
   AzyUi._source_lines = content
   AzyUi._input_buf = vim.api.nvim_create_buf(false, true)
   AzyUi._output_buf = vim.api.nvim_create_buf(false, true)


   local columns = vim.o.columns
   local lines = vim.o.lines

   local display_height = 20
   local input_row = lines - (display_height + 2)

   local iwin = vim.api.nvim_open_win(AzyUi._input_buf, true, {
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

   vim.api.nvim_win_set_option(iwin, 'winblend', 0)
   local owin = vim.api.nvim_open_win(AzyUi._output_buf, false, {
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
   vim.api.nvim_win_set_option(owin, 'winblend', 0)


   vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = AzyUi._input_buf,
      callback = AzyUi._update_output_buf,
   })


   vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout", "BufLeave" }, {
      buffer = AzyUi._input_buf,
      callback = function()
         vim.api.nvim_win_close(iwin, true)
         vim.api.nvim_win_close(owin, true)
      end,
   })

   AzyUi._update_output_buf()
end

function AzyUi._update_output_buf()
   local iline = vim.api.nvim_buf_get_lines(AzyUi._input_buf, 0, -1, true)[1]

   if #iline > 0 then
      local result = fzy.filter(iline, AzyUi._source_lines, false)

      table.sort(result, function(a, b)
         return a[3] < b[3]
      end)

      local outlines = {}
      for _, r in ipairs(result) do
         table.insert(outlines, r[1])
      end

      vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, outlines)
   else
      vim.api.nvim_buf_set_lines(AzyUi._output_buf, 0, -1, true, AzyUi._source_lines)
   end
end

return AzyUi
