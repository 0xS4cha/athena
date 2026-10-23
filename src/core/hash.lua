local bit = require("bit")

local bxor, rshift, tobit = bit.bxor, bit.rshift, bit.tobit

local Hash = {}

local function u32(x)
    x = tobit(x)
    if x < 0 then x = x + 4294967296 end
    return x
end

local function mul32(a, b)
    a, b = u32(a), u32(b)
    local alo, ahi = a % 65536, (a - a % 65536) / 65536
    local blo, bhi = b % 65536, (b - b % 65536) / 65536
    return u32(((ahi * blo + alo * bhi) % 65536) * 65536 + alo * blo)
end

local function fmix(h)
    h = bxor(h, rshift(h, 16))
    h = mul32(h, 0x85ebca6b)
    h = bxor(h, rshift(h, 13))
    h = mul32(h, 0xc2b2ae35)
    h = bxor(h, rshift(h, 16))
    return u32(h)
end

function Hash.toggle(h, i, owner)
    return u32(bxor(h, fmix(bxor(mul32(i, 0x9e3779b1), mul32(owner, 0x7feb352d)))))
end

function Hash.combine(h, v)
    v = v % 4294967296
    return fmix(bxor(mul32(h, 31), mul32(v, 0x27d4eb2f)))
end

return Hash
