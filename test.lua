local ber = require "ber"



local function toHex(str)
  return str:gsub(".", function (s) return string.format("%02x ", string.byte(s)) end)
end

local function pprint(t)
  for k, v in pairs(t) do
    print(k, v)
  end
end



print "Testing..."



local str = "Hello world!"

assert(ber.decode(ber.encode(str)).data == str)

print(toHex(ber.encode(str)))
print(ber.encode(str))
pprint(ber.decode(ber.encode(str)))

print(toHex(ber.encode(0x1234)))
pprint(ber.decode(ber.encode(0x40)))
print(ber.decode(ber.encode(0x40)).data)

print(toHex(ber.encode{"hello", 4660, false}))



print "Done!"
