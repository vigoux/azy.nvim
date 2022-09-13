local record Sinks
  open_file: function(AzyElement)
end

function Sinks.open_file(elem: AzyElement)
  vim.cmd.edit(elem.search_text)
end

return Sinks
