local Ordered = {}

local function compare(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
end

function Ordered.keys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, compare)
    return keys
end

function Ordered.pairs(t)
    local keys = Ordered.keys(t)
    local k = 0
    return function()
        k = k + 1
        local key = keys[k]
        if key == nil then return nil end
        return key, t[key]
    end
end

return Ordered
