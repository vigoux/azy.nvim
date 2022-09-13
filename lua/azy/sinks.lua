local Sinks = {}



function Sinks.open_file(elem)
   vim.cmd.edit(elem.search_text)
end

return Sinks
