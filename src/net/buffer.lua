local ffi = require("ffi")
local floor = math.floor

local Buffer = {}

local Writer = {}
Writer.__index = Writer

local Reader = {}
Reader.__index = Reader

local scratch = ffi.new("double[1]")
local scratchBytes = ffi.cast("uint8_t*", scratch)

function Buffer.writer(capacity)
    capacity = capacity or 65536
    return setmetatable({ data = ffi.new("uint8_t[?]", capacity), capacity = capacity, size = 0 }, Writer)
end

function Writer:reserve(n)
    local need = self.size + n
    if need <= self.capacity then return end
    local capacity = self.capacity
    while capacity < need do
        capacity = capacity * 2
    end
    local data = ffi.new("uint8_t[?]", capacity)
    ffi.copy(data, self.data, self.size)
    self.data = data
    self.capacity = capacity
end

function Writer:u8(v)
    self:reserve(1)
    self.data[self.size] = v
    self.size = self.size + 1
end

function Writer:varint(v)
    self:reserve(10)
    local data, size = self.data, self.size
    while v >= 128 do
        data[size] = v % 128 + 128
        size = size + 1
        v = floor(v / 128)
    end
    data[size] = v
    self.size = size + 1
end

function Writer:svarint(v)
    if v < 0 then
        self:varint(-v * 2 - 1)
    else
        self:varint(v * 2)
    end
end

function Writer:double(v)
    self:reserve(8)
    scratch[0] = v
    ffi.copy(self.data + self.size, scratchBytes, 8)
    self.size = self.size + 8
end

function Writer:bytes(ptr, n)
    self:reserve(n)
    ffi.copy(self.data + self.size, ptr, n)
    self.size = self.size + n
end

function Writer:string(s)
    self:varint(#s)
    self:bytes(s, #s)
end

function Writer:tostring()
    return ffi.string(self.data, self.size)
end

function Buffer.reader(s)
    local data = ffi.new("uint8_t[?]", #s + 1)
    ffi.copy(data, s, #s)
    return setmetatable({ data = data, size = #s, pos = 0, source = s }, Reader)
end

function Reader:check(n)
    if self.pos + n > self.size then
        error("Buffer truncated")
    end
end

function Reader:u8()
    self:check(1)
    local v = self.data[self.pos]
    self.pos = self.pos + 1
    return v
end

function Reader:varint()
    local data = self.data
    local v, scale = 0, 1
    while true do
        self:check(1)
        local b = data[self.pos]
        self.pos = self.pos + 1
        if b < 128 then
            return v + b * scale
        end
        v = v + (b - 128) * scale
        scale = scale * 128
    end
end

function Reader:svarint()
    local v = self:varint()
    if v % 2 == 1 then
        return -(v + 1) / 2
    end
    return v / 2
end

function Reader:double()
    self:check(8)
    ffi.copy(scratchBytes, self.data + self.pos, 8)
    self.pos = self.pos + 8
    return scratch[0]
end

function Reader:bytes(ptr, n)
    self:check(n)
    ffi.copy(ptr, self.data + self.pos, n)
    self.pos = self.pos + n
end

function Reader:string()
    local n = self:varint()
    self:check(n)
    local s = ffi.string(self.data + self.pos, n)
    self.pos = self.pos + n
    return s
end

return Buffer
