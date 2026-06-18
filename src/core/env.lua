local env = {}

function env.load(path)
    local Logger = require("src.core.logger")
    path = path or ".env"
    local content = love.filesystem.read(path)
    if not content then
        Logger:warn("core", ".env not found")
        return env
    end

    for line in content:gmatch("[^\r\n]+") do
        if not line:match("^%s*#") and line:match("%S") then
            local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if key then
                value = value:gsub('^["\'](.*)["\']$', "%1")
                env[key] = value
            end
        end
    end
    Logger:info("core", "variables loaded successfuly")
    return env
end

function env.get(variable, default_value) 
    if not env[variable] then
        env[variable] = default_value
    end 
    return env[variable]
end

return env