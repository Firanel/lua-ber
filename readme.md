# Lua BER encoding / decoding


!!! Work in progress

BER encoding and decoding in pure Lua.


## Usage

The BerObject:

| Property | Description | Default value |
| --- | --- | --- |
| class | Tag class: 0-3 (Universal / Application / Context-specific / Private) | 0 |
| constructed | Is a constructed type | false unless only constructed is permitted (native tags only) |
| type | ASN.1 tag | 0 (End of content) |
| length | Data length (in Bytes) | nil (Calculated from data) |
| data | Data as string | nil |
| children | Children for constructed types | nil |


### Encode

Generate the identifier octets:
```lua
local result = ber.identifier {
  type = ber.Types.INTEGER
}
```

Generate the length octets:
```lua
result = result .. ber.length(2)
```

Add the data:
```lua
result = result .. string.pack(">i2", 4660)
```

All in a single step:
```lua
assert(result == ber.encode {
  type = ber.Types.INTEGER,
  data = string.pack(">i2", 4660)
})
```

`nil`, integers, booleans and strings, can be automatically encoded:
```lua
assert(result == ber.encode(4660))
```

Automatic encoding is DER compliant.  
Strings are encoded as octet strings. If you wish to save a readable string a more specialized
type, like UTF8String, should be used.

Use tables with numbered indices to encode multiple elements in sequence:
```lua
assert(ber.encode {"hello", 42} == ber.encode "hello" .. ber.encode(42))
```

If `constructed` is true and `children` is set, `encode` will first encode children and use the result as the data.
```lua
ber.encode {
  type = ber.Types.SEQUENCE, -- constructed is implied with sequence type
  children = "I'm an only child"
}

ber.encode {
  type = ber.Types.SEQUENCE,
  children = {"First", 42}
}
```

The metatable index `__tober` can be used to customize encoding, by providing an encodable value
or a function returning an encodable value.
```lua
local obj = setmetatable({
  name = "Steve"
}, {
  __tober = function (this) return "Hello "..this.name end
})

assert(ber.encode(obj) == ber.encode "Hello Steve")
```


### Decode

