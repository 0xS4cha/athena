local flags = {}
local cache = {}

local function normalize(country)
    local key = tostring(country):gsub("^%s+", ""):gsub("%s+$", "")
    return key:lower():gsub("%s+", "-")
end

function flags:Load(country)
    if not country or country == "" then
        return nil
    end
    local key = normalize(country)
    if cache[key] ~= nil then
        return cache[key] or nil
    end
    local path = "assets/flags/" .. key .. ".png"
    if not love.filesystem.getInfo(path) then
        Logger:warn("flag", "Flag " .. key .. " missing")
        cache[key] = false
        return nil
    end
    local image = love.graphics.newImage(path, { mipmaps = true })
    image:setFilter("linear", "linear")
    image:setMipmapFilter("linear")
    cache[key] = image
    return image
end

function flags:Get(country)
    return self:Load(country)
end

return flags
