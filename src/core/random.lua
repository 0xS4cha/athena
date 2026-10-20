local bit = require("bit")

local band, bxor, lshift, rshift, tobit = bit.band, bit.bxor, bit.lshift, bit.rshift, bit.tobit
local floor = math.floor

local Random = {}
Random.__index = Random

function Random.new(seed)
    local self = setmetatable({}, Random)
    self:setSeed(seed or os.time())
    return self
end

function Random:setSeed(seed)
    local s = tobit(floor(seed) % 4294967296)
    if s == 0 then s = 0x6d2b79f5 end
    self.state = s
    for _ = 1, 8 do self:next() end
end

function Random:next()
    local s = self.state
    s = bxor(s, lshift(s, 13))
    s = bxor(s, rshift(s, 17))
    s = bxor(s, lshift(s, 5))
    self.state = s
    return band(s, 0x7fffffff)
end

function Random:random(a, b)
    local r = self:next() / 2147483648
    if not a then
        return r
    end
    if not b then
        return floor(r * a) + 1
    end
    return a + floor(r * (b - a + 1))
end

return Random
