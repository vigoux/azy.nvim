local Async = {}











function Async.create(command, bsize, on_lines)
   local self = setmetatable({
      _bufsize = bsize,
      _on_lines = on_lines,
      _buffer = {},
   }, { __index = Async })

   self._job = vim.fn.jobstart(command, {
      on_stdout = function(_, data)
         self:_on_data(data)
      end,
   })
   return self
end

function Async:cancel()
   vim.fn.jobstop(self._job)
end

function Async:_on_data(data)
   if data == { [[]] } then
   end
end

return Async
