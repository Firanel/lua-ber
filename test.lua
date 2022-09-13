local ber = require "ber"


-- Utils


local function toHex(str)
  return str:gsub(".", function (s) return string.format("%02x ", string.byte(s)) end)
end

local function pprint(t)
  for k, v in pairs(t) do
    print(k, v)
  end
end

function recursive_compare(t1,t2)
  -- Use usual comparison first.
  if t1==t2 then return true end
  -- We only support non-default behavior for tables
  if (type(t1)~="table") then return false end
  -- They better have the same metatables
  local mt1 = getmetatable(t1)
  local mt2 = getmetatable(t2)
  if( not recursive_compare(mt1,mt2) ) then return false end

  -- Check each key-value pair
  -- We have to do this both ways in case we miss some.
  -- TODO: Could probably be smarter and not check those we've
  -- already checked though!
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if( not recursive_compare(v1,v2) ) then
      print("Diff", k1, v1, v2)
      return false
    end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if( not recursive_compare(v1,v2) ) then
      print("Diff", k2, v1, v2)
      return false
    end
  end

  return true
end


-- Tests


print "Testing..."



-- Examples


-- "Maggie", 4, true
local result = "\x31\x0e\x16\x06\x4d\x61\x67\x67\x69\x65\x02\x01\x04\x01\x01\xFF"
assert(result == ber.encode {
  type = ber.Types.SET,
  {
    type = ber.Types.IA5String,
    data = "Maggie"
  }, 4, true
})

-- Tag long form
result = "\x1F\x22\x05\x31\x30\x30\x30\x59"
assert(result == ber.encode {
  type = ber.Types.DURATION,
  data = "1000Y"
})

-- Sequence indexing
result = "\x30\x10\x80\x08\x62\x69\x67\x20\x68\x65\x61\x64\x81\x01\x02\x82\x01\x1A"
assert(result == ber.encode {
  index = true,
  "\x62\x69\x67\x20\x68\x65\x61\x64",
  2,
  26,
})



-- Internal tests


-- string
assert(recursive_compare(
  ber.decode(ber.encode "test"),
  {
    class = 0,
    constructed = false,
    type = 4,
    length = 4,
    data = "test",
  }
))

-- Sequence
local tmp = ber.encode "a" .. ber.encode "b"
assert(recursive_compare(
  ber.decode(ber.encode {"a", "b"}),
  {
    class = 0,
    constructed = true,
    type = ber.Types.SEQUENCE,
    length = #tmp,
    data = tmp,
    children = {{
      class = 0,
      constructed = false,
      type = 4,
      length = 1,
      data = "a",
    }, {
      class = 0,
      constructed = false,
      type = 4,
      length = 1,
      data = "b",
    }}
  }
))

-- metamethod
tmp = setmetatable({name = "steve"}, {
    __tober = function (this) return string.format("Hello %s!", this.name) end
})
assert(recursive_compare(
  ber.decode(ber.encode(tmp)),
  {
    class = 0,
    constructed = false,
    type = 4,
    length = 12,
    data = "Hello steve!"
  }
))



print "Done!"
