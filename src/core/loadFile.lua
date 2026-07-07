local json = require("src.core/json")
local LoadFile = {}

local cache = {}

function LoadFile:Json(path, force)
    if not path then return nil end

    if cache[path] and not force then
        return cache[path]
    end

    local raw, err = love.filesystem.read(path)
    if not raw then
        error("Failed to load " .. path .. ": " .. tostring(err))
    end

    local content = json.decode(raw)
    cache[path] = content

    return content
end

function LoadFile:Bin(path, force)
    if not path then return nil end

    if cache[path] and not force then
        return cache[path]
    end

    local raw, sizeOrErr = love.filesystem.read(path)
    if not raw then
        error("Failed to load " .. path .. ": " .. tostring(sizeOrErr))
    end

    cache[path] = raw

    return raw
end

return LoadFile