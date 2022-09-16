local Async = {}













function Async.create(command, bsize, on_lines)
   local self = setmetatable({
      _bufsize = bsize,
      _on_lines = on_lines,
      _buffer = { "" },
      _command = command,
   }, { __index = Async })

   return self
end

function Async:run()
   self._job = vim.fn.jobstart(self._command, {
      on_stdout = function(_, data)
         self:_on_data(data)
      end,
   })
end

function Async:stop()
   vim.fn.jobstop(self._job)
end

function Async:_on_data(data)
   if #data == 1 and #(data[1]) == 0 then

      self._on_lines(self._buffer)
      self._buffer = { "" }
   end

   self._buffer[#self._buffer] = self._buffer[#self._buffer] .. data[1]

   for i = 2, #data do
      self._buffer[#self._buffer + 1] = data[i]
   end


   if #self._buffer > self._bufsize then
      local last_line = table.remove(self._buffer)
      local old_buf = self._buffer
      self._buffer = { last_line }
      self._on_lines(old_buf)
   end
end

return Async
