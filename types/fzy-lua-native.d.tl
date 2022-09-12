local record Fzy
  score: function(string, string, boolean): integer
  positions: function(string, string, boolean): {integer}
  filter_many: function(string, {string}, boolean): {{integer}}
  filter: function(string, {string}, boolean): {{string,{integer},integer}}
end

return Fzy
