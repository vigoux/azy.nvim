local Sinks = {}





function Sinks.open_file(elem, options)
   if options.vsplit then
      vim.cmd.vsplit(elem.search_text)
   elseif options.split then
      vim.cmd.split(elem.search_text)
   else
      vim.cmd.edit(elem.search_text)
   end
end

function Sinks.help_tag(elem, options)
   if options.vsplit then
      vim.cmd(string.format("vertical help %s", elem.search_text))
   else
      vim.cmd.help(elem.search_text)
   end
end

function Sinks.qf_item(elem, options)
   local item = elem.extra
   if item and item.valid == 1 then
      if item.filename then
         Sinks.open_file(elem, options)
      else
         vim.api.nvim_win_set_buf(0, item.bufnr)
      end
      vim.api.nvim_win_set_cursor(0, { item.lnum, item.col })
   end
end

return Sinks
