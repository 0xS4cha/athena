local GM = require("src.core.index")
GM.Modules = {}
GM.Modules.List = {}
GM.Modules.HasFunction = { Think = {}, Draw = {}, KeyPressed = {}, MousePressed = {}, MouseReleased = {}, WheelMoved = {}, TextInput = {} }

local lastTick = love.timer.getTime()

--- @param name string
--- @param priority number?
--- @param submodules string[]?
function GM.Modules:Register(name, priority, submodules)
    table.insert(self.List, {
        name = name,
        priority = priority or 50,
        submodules = submodules
    })
end

--- @param dir string
--- @param results string[]?
--- @param is_recursion boolean?
--- @return string[]
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

--- @return void
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
            Logger:info("Module", string.format("Initialized %s in %.2f ms", name, timeTaken))
            if self[name].Think then
                table.insert(GM.Modules.HasFunction.Think, name)
            end
            if self[name].Draw then
                table.insert(GM.Modules.HasFunction.Draw, name)
            end
            if self[name].KeyPressed then
                table.insert(GM.Modules.HasFunction.KeyPressed, name)
            end
            if self[name].MousePressed then
                table.insert(GM.Modules.HasFunction.MousePressed, name)
            end
            if self[name].MouseReleased then
                table.insert(GM.Modules.HasFunction.MouseReleased, name)
            end
            if self[name].WheelMoved then
                table.insert(GM.Modules.HasFunction.WheelMoved, name)
            end
            if self[name].TextInput then
                table.insert(GM.Modules.HasFunction.TextInput, name)
            end
        else
            Logger:warn("Module", "Module " .. name .. " registered but does not have a function")
        end
    end
end




--- @param dt number?
--- @return void
function GM:Think(dt)
    if love.timer.getTime() - lastTick >= 1 then
        lastTick = love.timer.getTime()
        self.TickSecond = true
    end

    for _, moduleName in pairs(GM.Modules.HasFunction.Think) do
        self[moduleName]:Think(dt)
    end

    if self.TickSecond then
        self.TickSecond = nil
    end
end

--- @return void
function GM:Draw()
    for _, moduleName in pairs(GM.Modules.HasFunction.Draw) do
        self[moduleName]:Draw()
    end
end

--- @param key string
--- @param scancode string
--- @param isrepeat boolean
--- @return void
function GM:KeyPressed(key, scancode, isrepeat)
    for _, moduleName in pairs(self.Modules.HasFunction.KeyPressed) do
        self[moduleName]:KeyPressed(key, scancode, isrepeat)
    end
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function GM:MousePressed(x, y, button, istouch, presses)
    for _, moduleName in pairs(self.Modules.HasFunction.MousePressed) do
        self[moduleName]:MousePressed(x, y, button, istouch, presses)
    end
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function GM:MouseReleased(x, y, button, istouch, presses)
    for _, moduleName in pairs(self.Modules.HasFunction.MouseReleased) do
        self[moduleName]:MouseReleased(x, y, button, istouch, presses)
    end
end

--- @param x number
--- @param y number
--- @return void
function GM:WheelMoved(x, y)
    for _, moduleName in pairs(self.Modules.HasFunction.WheelMoved) do
        self[moduleName]:WheelMoved(x, y)
    end
end

--- @param text string
--- @return void
function GM:TextInput(text)
    for _, moduleName in pairs(self.Modules.HasFunction.TextInput) do
        self[moduleName]:TextInput(text)
    end
end

return GM.Modules