local Icons = {}

local cache = {}

function Icons.get(name)
    if not name then return nil end
    if cache[name] == nil then
        local ok, img = pcall(love.graphics.newImage, "assets/Icons/" .. name)
        if ok then
            img:setFilter("nearest", "nearest")
            cache[name] = img
        else
            cache[name] = false
        end
    end
    return cache[name] or nil
end

return Icons
