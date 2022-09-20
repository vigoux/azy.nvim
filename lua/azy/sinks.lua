local Sinks = {}





local function open(fname, options)
   if options.vsplit then
      vim.cmd.vsplit(fname)
   elseif options.split then
      vim.cmd.split(fname)
   else
      vim.cmd.edit(fname)
   end
end

function Sinks.open_file(elem, options)
   open(elem.search_text, options)
end

function Sinks.help_tag(elem, options)
   if options.preview then return end

   if options.vsplit then
      vim.cmd(string.format("vertical help %s", elem.search_text))
   else
      vim.cmd.help(elem.search_text)
   end
end

function Sinks.qf_item(elem, options)
   local item = elem.extra
   local preview_param = options.preview
   if item and (item.filename ~= nil or item.bufnr ~= nil) then
      if preview_param and not (type(preview_param) == "boolean") then
         vim.api.nvim_win_set_buf(0, preview_param)
      elseif item.filename then
         open(item.filename, options)
      else
         vim.api.nvim_win_set_buf(0, item.bufnr)
      end
      vim.api.nvim_win_set_cursor(0, { item.lnum, item.col })
   else
      error("Got an invalid item " .. vim.inspect(item))
   end
end

return Sinks
