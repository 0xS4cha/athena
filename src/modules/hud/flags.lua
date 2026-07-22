local flags = {}

--- @param country string? 
--- @return table? flags
function flags:Load(country)
    local Logger = require("src.core.logger")
    if not country then
        Logger:warn("flag", "You can not load an invalid flag: " .. tostring(country))
        return
    end

    local key = tostring(country):gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        Logger:warn("flag", "You can not load an invalid flag: " .. tostring(country))
        return
    end

    local normalizedKey = key:lower():gsub("%s+", "-")
    local candidates = { key, normalizedKey }
    local loadedImage

    for _, candidate in ipairs(candidates) do
        local path = "assets/flags/" .. candidate .. ".png"
        if love.filesystem.getInfo(path) then
            loadedImage = love.graphics.newImage(path)
            loadedImage:setFilter("linear", "linear")
            flags[key] = loadedImage
            flags[normalizedKey] = loadedImage
            break
        end
    end

    if not loadedImage then
        local fallbackPath = "assets/flags/xx.png"
        if love.filesystem.getInfo(fallbackPath) then
            loadedImage = love.graphics.newImage(fallbackPath)
            loadedImage:setFilter("linear", "linear")
            flags[key] = loadedImage
            flags[normalizedKey] = loadedImage
            Logger:warn("flag", "Flag " .. key .. " missing, using fallback xx")
            return loadedImage
        end

        Logger:warn("flag", "You can not load an invalid flag: " .. key)
        return
    end

    Logger:info("flag", "Flag " .. key .. " loaded successfully")
    return loadedImage
end

--- @param country string
--- @return any
function flags:Get(country)
    if not country then
        return
    end

    local key = tostring(country):gsub("^%s+", ""):gsub("%s+$", "")
    local normalizedKey = key:lower():gsub("%s+", "-")
    return flags[country] or flags[key] or flags[normalizedKey]
end

return flags