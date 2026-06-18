local GM = require("src.core.index")
GM.Modules = {}
GM.Map = {}
GM.Modules.List = {}

function GM.Modules:Register(name, priority, submodules)
    table.insert(self.List, {
        name = name,
        priority = priority or 50,
        submodules = submodules
    })
end

function GM.Modules:Load(dir, results, is_recursion)
    results = results or {}
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local path = dir .. "/" .. item
        local info = love.filesystem.getInfo(path)
        if info.type == "directory" then
            GM.Modules:Load(path, results, true)
        elseif item:match("%.lua$") then
            table.insert(results, path)
        end
    end
    if not is_recursion then
        table.sort(results, function(a, b)
            local aIsIndex = a:match("%index.lua$")
            local bIsIndex = b:match("%index.lua$")
            if aIsIndex ~= bIsIndex then
                return aIsIndex
            end
            return a < b
        end)
        for _, v in pairs(results) do
            local modulePath = v:gsub("%.lua$", ""):gsub("/", ".")
            require(modulePath)
        end
    end
    return results
end

function GM:InitializeModules()
    table.sort(self.Modules.List, function(a, b)
        return a.priority < b.priority
    end)

    local startTime = os.clock()

    for _, module in pairs(self.Modules.List) do
        local name = module.name
        if self[name] then
            if self[name].Initialize then
                Logger:info("Module", "Initializing", name)
                self[name]:Initialize()
            end

            if module.submodules then
                for _, submodule in pairs(module.submodules) do
                    if self[name][submodule] then
                        if self[name][submodule].Initialize then
                            self[name][submodule]:Initialize()
                        end
                    end
                end
            end

            local timeTaken = os.clock() - startTime
            local timeStr = tostring(timeTaken)
            if timeTaken > 1 then
                timeStr = "^1" .. timeStr
            end
            Logger:info("Module", "Initialized " .. name .. " in " .. timeStr .. "ms")
        else
            Logger:warn("Module", "Module " .. name .. " registered but does not have a function")
        end
    end
end


return GM.Modules