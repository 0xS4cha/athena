local Codec = require("src.net.codec")
local Protocol = require("src.net.protocol")
local T = require("tests.helpers")

local function same(a, b, path)
    path = path or "value"
    if type(a) ~= type(b) then error(path .. ": type " .. type(a) .. " vs " .. type(b)) end
    if type(a) ~= "table" then
        if a ~= b then error(string.format("%s: %s vs %s", path, tostring(a), tostring(b))) end
        return
    end
    for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do
        if a[k] == nil then error(path .. "." .. tostring(k) .. " unexpected") end
    end
end

return {
    {
        name = "round-trips scalars exactly",
        run = function()
            local values = { 0, 1, 127, 128, 300, 2 ^ 31, 2 ^ 53, -1, -129, -2 ^ 40, 0.1, 1 / 3, -2.5e-12, 1e300, math.pi, "", "hello", "\0bin\255", true, false }
            for _, v in ipairs(values) do
                local decoded = Codec.decode(Codec.encode(v))
                T.equal(decoded, v, "round trip of " .. tostring(v))
            end
        end
    },
    {
        name = "round-trips nested tables with array and hash parts",
        run = function()
            local value = { 1, 2, { 3, "x" }, name = "room", nested = { deep = { true, false, 0.25 } }, [10] = "sparse", [-3] = "negative" }
            same(Codec.decode(Codec.encode(value)), value)
        end
    },
    {
        name = "keeps ratios bit exact so clients apply the same commands",
        run = function()
            local intent = { type = "attack", ratio = 0.3 + 0.123456789 * 0.2, seq = 7 }
            local decoded = Codec.decode(Codec.encode(intent))
            T.expect(decoded.ratio == intent.ratio, "ratio changed through the codec")
        end
    },
    {
        name = "rejects corrupted payloads without throwing",
        run = function()
            local raw = Codec.encode({ 1, 2, 3, "abc" })
            T.equal(Codec.decode(raw:sub(1, #raw - 2)), nil, "truncated payload")
            T.equal(Protocol.Decode("garbage"), nil, "protocol garbage")
        end
    },
    {
        name = "encodes protocol messages",
        run = function()
            local kind, data = Protocol.Decode(Protocol.Encode("frame", { t = 12, c = {}, h = 99 }))
            T.equal(kind, "frame")
            T.equal(data.t, 12)
            T.equal(data.h, 99)
        end
    }
}
