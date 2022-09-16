local ui = require'azy.ui'

local record Async
  _running: boolean
  _job: vim.fn.Job
  _bufsize: integer
  _on_lines: function(Async, {string})
  _buffer: {string}
  _command: {string}

  _on_data: function(Async, {string})
  stop: function(Async)
  run: function(Async)

  create: function({string}, integer, function({string})): Async
  ui: function({string}, (function(string): AzyElement), function(AzyElement)): function()
end

function Async.create(command: {string}, bsize: integer, on_lines: function(Async, {string})): Async
  local self = setmetatable({
    _bufsize = bsize,
    _on_lines = on_lines,
    _buffer = {""},
    _command = command,
    _runnning = false
  } as Async, { __index = Async})

  return self
end

function Async:run()
  self._job = vim.fn.jobstart(self._command, {
    on_stdout = function(_: integer, data: {string})
      self:_on_data(data)
    end
  })
  self._running = true
end

function Async:stop()
  self._running = false
  vim.fn.jobstop(self._job)
end

function Async:_on_data(data: {string})
  if not self._running then
    return
  end

  if #data == 1 and #(data[1]) == 0 then
    -- Reached eof, call on_lines with the remaining of the buffer
    self._on_lines(self, self._buffer)
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
    self._on_lines(self, old_buf)
  end
end

function Async.ui(command: {string}, transform: (function(string): AzyElement), sink: function(AzyElement)): function()
  return function()
    local job = Async.create(command, 10000, function(j: Async, lines: {string})
      if not ui.add(vim.tbl_map(transform, lines)) then
        -- UI got stopped, stop the job too
        j:stop()
      end
    end)
    ui.create({}, function(e: AzyElement)
      job:stop()
      sink(e)
    end)
    job:run()
  end
end


return Async
