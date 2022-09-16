local record Sinks
  open_file: function(AzyElement)
  help_tag: function(AzyElement)
  qf_item: function(AzyElement)
end

function Sinks.open_file(elem: AzyElement)
  vim.cmd.edit(elem.search_text)
end

function Sinks.help_tag(elem: AzyElement)
  vim.cmd.help(elem.search_text)
end

function Sinks.qf_item(elem: AzyElement)
  local item = elem.extra as vim.QfItem
  if item then
    vim.cmd.edit(item.filename)
    vim.api.nvim_win_set_cursor(0 as vim.WinNr, {item.lnum, item.col})
  end
end

return Sinks
