local Config = require("src.config.game")

local Keybinds = {}

local FILE = "keybinds.txt"

local DEFAULTS = {
    ["build:city"] = "c",
    ["build:farm"] = "f",
    ["build:tradePort"] = "t",
    ["build:militaryPort"] = "m",
    ["build:factory"] = "g",
    ["build:mine"] = "n",
    ["build:barracks"] = "b",
    ["build:radar"] = "r",
    ["build:defensePost"] = "d",
    ["build:silo"] = "v",
    ["build:sam"] = "s",
    ["build:bunker"] = "k",
    ["build:warship"] = "w",
    ["nuke:atom"] = "z",
    ["nuke:hydrogen"] = "x",
    ["nuke:mirv"] = "q"
}

Keybinds.reserved = {
    escape = true, space = true, ["return"] = true, kpenter = true, tab = true,
    backspace = true, delete = true, up = true, down = true, left = true, right = true,
    p = true, h = true, ["="] = true, ["-"] = true, ["kp+"] = true, ["kp-"] = true,
    ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true, ["7"] = true
}

Keybinds.actions = {}
for _, kind in ipairs(Config.buildMenu) do
    local def = Config.units[kind]
    Keybinds.actions[#Keybinds.actions + 1] = { id = "build:" .. kind, group = "build", kind = kind, label = def.label, icon = def.icon }
end
for _, kind in ipairs(Config.nukeTypes) do
    local def = Config.nukes[kind]
    Keybinds.actions[#Keybinds.actions + 1] = { id = "nuke:" .. kind, group = "nuke", kind = kind, label = def.label, icon = def.icon }
end

Keybinds.byId = {}
for _, action in ipairs(Keybinds.actions) do
    Keybinds.byId[action.id] = action
end

local binds

local function defaults()
    local list = {}
    for id, key in pairs(DEFAULTS) do
        list[id] = key
    end
    return list
end

function Keybinds.load()
    binds = defaults()
    local content = love.filesystem.getInfo(FILE) and love.filesystem.read(FILE)
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local id, key = line:match("^([^=]+)=(.*)$")
        if id and Keybinds.byId[id] then
            binds[id] = key ~= "" and not Keybinds.reserved[key] and key or false
        end
    end
end

function Keybinds.save()
    local lines = {}
    for _, action in ipairs(Keybinds.actions) do
        lines[#lines + 1] = action.id .. "=" .. (Keybinds.get(action.id) or "")
    end
    love.filesystem.write(FILE, table.concat(lines, "\n") .. "\n")
end

function Keybinds.get(id)
    if not binds then Keybinds.load() end
    return binds[id] or nil
end

function Keybinds.find(key)
    for _, action in ipairs(Keybinds.actions) do
        if Keybinds.get(action.id) == key then
            return action
        end
    end
end

function Keybinds.set(id, key)
    if not binds then Keybinds.load() end
    if key and Keybinds.reserved[key] then
        return false, string.upper(key) .. " is reserved"
    end
    local previous = key and Keybinds.find(key)
    if previous and previous.id ~= id then
        binds[previous.id] = false
    end
    binds[id] = key or false
    Keybinds.save()
    if previous and previous.id ~= id then
        return true, "Unbound from " .. previous.label
    end
    return true
end

function Keybinds.reset()
    binds = defaults()
    Keybinds.save()
end

function Keybinds.label(key)
    if not key then return "-" end
    return string.upper(key)
end

return Keybinds
