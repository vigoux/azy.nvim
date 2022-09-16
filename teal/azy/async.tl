local record Async
  _job: vim.fn.Job
  _bufsize: integer
  _on_lines: function({string})
  _buffer: {string}
  _command: {string}

  _on_data: function(Async, {string})
  stop: function(Async)
  run: function(Async)

  create: function({string}, integer, function({string})): Async
end

function Async.create(command: {string}, bsize: integer, on_lines: function({string})): Async
  local self = setmetatable({
    _bufsize = bsize,
    _on_lines = on_lines,
    _buffer = {""},
    _command = command,
  } as Async, { __index = Async})

  return self
end

function Async:run()
  self._job = vim.fn.jobstart(self._command, {
    on_stdout = function(_: integer, data: {string})
      self:_on_data(data)
    end
  })
end

function Async:stop()
  vim.fn.jobstop(self._job)
end

function Async:_on_data(data: {string})
  if #data == 1 and #(data[1]) == 0 then
    -- Reached eof, call on_lines with the remaining of the buffer
    self._on_lines(self._buffer)
    self._buffer = {""}
  end

  self._buffer[#self._buffer] = self._buffer[#self._buffer] .. data[1]

  for i=2,#data do
    self._buffer[#self._buffer + 1] = data[i]
  end

  -- Now if the buffer size is greater than _bufsize call on_lines
  if #self._buffer > self._bufsize then
    local last_line = table.remove(self._buffer)
    local old_buf = self._buffer
    self._buffer = { last_line }
    self._on_lines(old_buf)
  end
end

return Async
