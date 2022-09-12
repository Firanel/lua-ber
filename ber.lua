
local function bytesRequired(num)
  local i = 0
  while num > 0 do
    i = i + 1
    num = num >> 8
  end
  return i
end



local Types = {
  EOC = 0,
  BOOLEAN = 1,
  INTEGER = 2,
  BIT_STRING = 3,
  OCTET_STRING = 4,
  NULL = 5,
  SEQUENCE = 16,
  SET = 17,
}

local constructedOnly = {
  ["8"] = true,
  ["11"] = true,
  ["16"] = true,
  ["17"] = true,
  ["29"] = true,
}



local function identifier(options)
  local class = options.class or 0
  local constructed = options.constructed or false
  if options.constructed == nil and constructedOnly[options.type] then
    constructed = true
  end
  local tag = options.type or 0

  local octet = class << 6
  if constructed then octet = octet | (1 << 5) end
  if tag < 31 then
    octet = octet | tag
    return string.char(octet)
  end

  octet = octet | 31
  local longType = string.char(tag & 0x7f)
  tag = tag >> 7
  while tag > 0 do
      longType = string.char((tag & 0x7f) | 0x80)..longType
      tag = tag >> 7
  end
  return string.char(octet)..longType
end


local function length(len)
  if not len then
    return string.char(0x80)
  end

  if len < 128 then
    return string.char(len)
  end

  local i = bytesRequired(len)
  return string.pack("B >I"..i, i | 0x80, len)
end



local function encode(value)
  local mt = getmetatable(value)
  local tober = mt and mt.__tober
  if tober then
    if type(tober) == "function" then
      return encode(tober(value))
    else
      return encode(tober)
    end
  end

  local t = type(value)

  if t == "nil" then
    return identifier{type = Types.NULL} .. length(0)
  elseif t == "number" then
    if math.floor(value) == value then
      local len = bytesRequired(value)
      local res = identifier{type = Types.INTEGER} .. length(len)
      if len > 0 then
        res = res .. string.pack(">i"..len, value)
      end
      return res
    else
      error("Not implemented")
    end
  elseif t == "string" then
    return identifier{type = Types.OCTET_STRING} .. length(#value) .. value
  elseif t == "boolean" then
    return identifier{type = Types.BOOLEAN} .. length(1) .. string.char(value and 1 or 0)
  elseif t == "table" then
    if value[1] then
      local res = {}
      for i, v in ipairs(value) do
        res[i] = encode(v)
      end
      res = table.concat(res, "")
      return identifier{type = Types.SEQUENCE} .. length(#res) .. res
    else
      if value.constructed == nil and constructedOnly[value.type] then
        value.constructed = true
      end
      if value.constructed and value.children then
        value.data = encode(value.children)
        value.length = #value.data
      end

      if not value.length then
        if not value.data then
          value.data = ""
          value.length = 0
        else
          value.length = #value.data
        end
      end
      return identifier(value) .. length(value.length) .. value.data
    end
  else
    error("Type not supported: "..t)
  end
end



local function decode(value, cursor)
  local i = cursor or 1 -- Cursor

  -- Identifier octets

  local ident = string.byte(value, i)
  local class = ident >> 6
  local constructed = ident & 0x20 > 0
  local tag = ident & 0x1f

  -- Tag long form
  if tag == 31 then
    local v
    local values = {}

    repeat
      i = i + 1
      v = string.byte(value, i)
      table.insert(values, v & 0x7f, 0)
    until v & 0x80 == 0

    tag = 0
    for j, val in ipairs(values) do
      tag = tag | (val << (7 * (j - 1)))
    end
  end

  i = i + 1

  -- Length octets and read value

  local lenOc = string.byte(value, i)
  i = i + 1
  local length = 0
  local data

  if lenOc & 0x80 == 0 then -- Definite, short
    length = lenOc
    data = string.sub(value, i, i + length - 1)
    i = i + length
  elseif lenOc == 0x80 then -- Indefinite
    local start, e = string.find(value, "\x00\x00", i, true)
    assert(start, "End of content not found")
    length = start - i
    data = string.sub(value, i, start - 1)
    i = e + 1
  elseif lenOc == 0xff then -- Reserved
    error("Reserved length")
  else -- Definite, long
    length, i = string.unpack(">I"..(lenOc & 0x7f), value, i)
    data = string.sub(value, i, i + length - 1)
    i = i + length
  end


  return {
    class = class,
    constructed = constructed,
    tag = tag,
    length = length,
    data = data
  }, i
end



local function decodeToArray(value)
  local res = {}

  local cursor = 1

  while cursor <= #value do
    local r
    r, cursor = decode(value, cursor)
    table.insert(res, r)
  end

  return res
end



return {
  encode = encode,
  decode = decode,
  decodeToArray = decodeToArray,
  identifier = identifier,
  length = length,
}
