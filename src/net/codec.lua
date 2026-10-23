local Buffer = require("src.net.buffer")

local floor = math.floor

local Codec = {}

local NIL, FALSE, TRUE, UINT, NINT, DOUBLE, STRING, TABLE = 0, 1, 2, 3, 4, 5, 6, 7
local MAX_INT = 2 ^ 53

local write

local function writeNumber(w, v)
    if v == floor(v) and v >= -MAX_INT and v <= MAX_INT then
        if v >= 0 then
            w:u8(UINT)
            w:varint(v)
        else
            w:u8(NINT)
            w:varint(-v)
        end
    else
        w:u8(DOUBLE)
        w:double(v)
    end
end

local function writeTable(w, t, depth)
    if depth > 32 then error("Codec: table nested too deeply") end
    w:u8(TABLE)
    local n = #t
    w:varint(n)
    for k = 1, n do
        write(w, t[k], depth + 1)
    end
    local count = 0
    for k in pairs(t) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == floor(k)) then
            count = count + 1
        end
    end
    w:varint(count)
    for k, v in pairs(t) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == floor(k)) then
            write(w, k, depth + 1)
            write(w, v, depth + 1)
        end
    end
end

write = function(w, v, depth)
    local kind = type(v)
    if v == nil then
        w:u8(NIL)
    elseif kind == "boolean" then
        w:u8(v and TRUE or FALSE)
    elseif kind == "number" then
        writeNumber(w, v)
    elseif kind == "string" then
        w:u8(STRING)
        w:string(v)
    elseif kind == "table" then
        writeTable(w, v, depth)
    else
        error("Codec: cannot encode " .. kind)
    end
end

local function read(r, depth)
    if depth > 32 then error("Codec: table nested too deeply") end
    local tag = r:u8()
    if tag == NIL then
        return nil
    elseif tag == FALSE then
        return false
    elseif tag == TRUE then
        return true
    elseif tag == UINT then
        return r:varint()
    elseif tag == NINT then
        return -r:varint()
    elseif tag == DOUBLE then
        return r:double()
    elseif tag == STRING then
        return r:string()
    elseif tag == TABLE then
        local t = {}
        local n = r:varint()
        for k = 1, n do
            t[k] = read(r, depth + 1)
        end
        for _ = 1, r:varint() do
            local key = read(r, depth + 1)
            local value = read(r, depth + 1)
            if key ~= nil and key == key then
                t[key] = value
            end
        end
        return t
    end
    error("Codec: unknown tag " .. tostring(tag))
end

function Codec.write(w, v)
    write(w, v, 0)
end

function Codec.read(r)
    return read(r, 0)
end

function Codec.encode(v)
    local w = Buffer.writer(256)
    write(w, v, 0)
    return w:tostring()
end

function Codec.decode(s)
    local r = Buffer.reader(s)
    local ok, value = pcall(read, r, 0)
    if not ok then return nil, value end
    return value
end

return Codec
