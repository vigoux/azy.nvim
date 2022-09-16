local Sinks = {}





function Sinks.open_file(elem)
   vim.cmd.edit(elem.search_text)
end

function Sinks.help_tag(elem)
   vim.cmd.help(elem.search_text)
end

function Sinks.qf_item(elem)
   local item = elem.extra
   if item then
      vim.cmd.edit(item.filename)
      vim.api.nvim_win_set_cursor(0, { item.lnum, item.col })
   end
end

return Sinks
