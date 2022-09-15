local record Fzy
  record Choices
    add: function(Choices, {string})
    available: function(Choices): integer
    search: function(Choices, string): {{string, number}}
    selected: function(Choices): string, integer
    next: function(Choices): string, integer
    prev: function(Choices): string, integer
    get: function(Choices, integer): string
  end

  create: function(): Choices
  match: function(string, string): number, {integer}
end

return Fzy
