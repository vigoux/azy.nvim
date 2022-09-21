local fzy = require'fzy'
require 'busted.runner' { output = 'TAP', shuffle = true }

-- Setup some helpers to check the elemenst
local say = require'say'
local function ordered_elements(state, arguments)
  if #arguments ~= 2 then
    return false
  end

  local source = arguments[1]
  local check = arguments[2]

  if type(source) ~= 'userdata' or type(check) ~= 'table' then
    print "type"
    return false
  end

  source = source:elements()

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

-- Actual tests
describe('fzy native library', function()

  it('can create choices object', function()
    local c = fzy.create()

    assert.is_not_nil(c)
  end)

  describe('choices object', function()
    local c

    before_each(function()
      c = fzy.create()
      c:add { "babar", "baz", "foo" }
    end)

    it('filters results', function()
      -- Ensure that behavior of no avaiable items on the start
      assert.is.equal(0, c:available())

      c:search "a"

      assert.has_correct_elements(c, { "baz", "babar" })
    end)

    it('allows to filter incrementally', function()
      c:search "a"

      c:add_incremental { "abar" }

      assert.has_correct_elements(c, { "abar", "baz", "babar" })
    end)

    it('correctly filters with new queries', function()
      c:search "a"
      assert.has_correct_elements(c, { "baz", "babar" })
      c:search "ab"
      assert.has_correct_elements(c, { "babar" })
    end)
  end)

  describe('cursor navigation', function()
    local c

    before_each(function()
      c = fzy.create()
      c:add { "babar", "baz", "foo" }
    end)

    it('is not set on start', function()
      assert.is_nil(c:selected())
    end)

    it('is set after search', function()
      c:search "a"
      assert.is.equal("baz", c:selected())
    end)

    it('correctly moves', function()
      c:search "a"

      assert.is.equal("baz", c:selected())
      assert.is.equal("babar", c:next())
      assert.is.equal("baz", c:prev())
    end)

    it('wraps around', function()
      c:search "a"

      assert.is.equal("baz", c:selected())
      assert.is.equal("babar", c:next())
      assert.is.equal("baz", c:next())
    end)

    it('moves when incrementally adding results', function()
      c:search "a"

      assert.is.equal("baz", c:selected())

      c:add_incremental { "abar" }

      assert.is.equal("baz", c:selected())
      assert.is.equal("abar", c:prev())
    end)
  end)
end)
