local record Fzy
  record Choices
    add: function(Choices, {string})
    available: function(Choices): integer
    search: function(Choices, string): {{string, number}}
    selected: function(Choices): string
    next: function(Choices): string
    prev: function(Choices): string
  end

  create: function(): Choices
  match: function(string, string): number, {integer}
end

return Fzy
