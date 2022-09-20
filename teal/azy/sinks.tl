local record Sinks
  open_file: function(AzyElement)
  help_tag: function(AzyElement)
  qf_item: function(AzyElement)
end

local function open(fname: string, options: AzyCbModifiers)
  if options.vsplit then
    vim.cmd.vsplit(fname)
  elseif options.split then
    vim.cmd.split(fname)
  else
    vim.cmd.edit(fname)
  end
end

function Sinks.open_file(elem: AzyElement, options: AzyCbModifiers)
  open(elem.search_text, options)
end

function Sinks.help_tag(elem: AzyElement, options: AzyCbModifiers)
  if options.preview then return end

  if options.vsplit then
    vim.cmd(string.format("vertical help %s", elem.search_text))
  else
    vim.cmd.help(elem.search_text)
  end
end

function Sinks.qf_item(elem: AzyElement, options: AzyCbModifiers)
  local item = elem.extra as vim.QfItem
  local preview_param = options.preview
  if item and (item.filename ~= nil or item.bufnr ~= nil) then
    if preview_param and not preview_param is boolean then
      vim.api.nvim_win_set_buf(0 as vim.WinNr, preview_param as vim.BufNr)
    elseif item.filename then
      open(item.filename, options)
    else
      vim.api.nvim_win_set_buf(0 as vim.WinNr, item.bufnr)
    end
    vim.api.nvim_win_set_cursor(0 as vim.WinNr, {item.lnum, item.col})
  else
    error("Got an invalid item " .. vim.inspect(item))
  end
end

return Sinks
