local fzy = require'fzy'
local say = require'say'
require 'busted.runner' { output = 'TAP', shuffle = true }

local function ordered_elements(state, arguments)
  if #arguments ~= 2 then
    return false
  end

  local source = arguments[1]
  local check = arguments[2]

  if type(source) ~= 'table' or type(check) ~= 'table' then
    print "type"
    return false
  end

  if #source ~= #check then
    print "len"
    return false
  end

  for i=1,#check do
    if source[i][1] ~= check[i] then
      print(source[i][1], check[i])
      return false
    end
  end

  return true
end

say:set("assertion.has_correct_elements.positive", "Expected %s \nto be ordered like: %s")
say:set("assertion.has_correct_elements.negative", "Expected %s \nto not be ordered like: %s")
assert:register("assertion", "has_correct_elements", ordered_elements, "assertion.has_correct_elements.positive", "assertion.has_correct_elements.negative")

describe('fzy native library', function()

  it('can create choices object', function()
    local c = fzy.create()

    assert.is_not_nil(c)
  end)

  it('filters results', function()
    local c = fzy.create()

    c:add { "babar", "baz", "foo" }

    -- Ensure that behavior of no avaiable items on the start
    assert.is.equal(0, c:available())

    c:search "a"

    assert.has_correct_elements(c:elements(), { "baz", "babar" })
  end)
end)
