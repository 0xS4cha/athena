local function newClass(base)
    local c = {}
    if type(base) == 'table' then
        for i, v in pairs(base) do c[i] = v end
        c._base = base
    end
    c.__index = c

    local mt = {}
    mt.__call = function(class_tbl, ...)
        local obj = {}
        setmetatable(obj, c)
        if obj.init then obj:init(...) end
        return obj
    end
    setmetatable(c, mt)
    return c
end

return newClass