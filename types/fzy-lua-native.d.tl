local record Fzy
  score: function(string, string, boolean): number
  positions: function(string, string, boolean): {integer}
  match_many: function(string, {string}, boolean): {{string, number}}
  filter_many: function(string, {string}, boolean): {{integer}}
  filter: function(string, {string}, boolean): {{string,{integer},number}}
end

return Fzy
