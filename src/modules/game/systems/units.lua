local Config = require("src.config.game")
local Format = require("src.core.format")

local Units = {}

function Units.definition(kind)
    return Config.units[kind]
end

function Units.isBuilding(kind)
    for _, k in ipairs(Config.buildingTypes) do
        if k == kind then return true end
    end
    return false
end

function Units.cost(game, player, kind)
    local def = Config.units[kind]
    local n = player:unitCount(kind)
    local cost = def.cost
    if def.scale == "double" then
        cost = def.cost * 2 ^ n
    elseif def.scale == "linear" then
        cost = def.cost * (n + 1)
    end
    return math.min(def.cap, cost)
end

function Units.list(game, player, kind)
    local list = {}
    for _, unit in ipairs(game.units) do
        if unit.owner == player and (not kind or unit.kind == kind) then
            list[#list + 1] = unit
        end
    end
    return list
end

function Units.isSpaced(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local r = Config.buildingSpacing
    for dy = -r, r do
        for dx = -r, r do
            local tx, ty = x + dx, y + dy
            if map:isValid(tx, ty) and game.buildingAt[map:index(tx, ty)] then
                return false
            end
        end
    end
    return true
end

function Units.findPortTile(game, player, tile)
    local map = game.map
    local x, y = map:coords(tile)
    return map:findNear(x, y, Config.portSearch, function(i)
        return map.owner[i] == player.id and map:isCoast(i) and Units.isSpaced(game, i)
    end)
end

function Units.nearestPort(game, player, tile, kind)
    local map = game.map
    local x, y = map:coords(tile)
    local best, bestD
    kind = kind or "militaryPort"
    for _, unit in ipairs(game.units) do
        if unit.kind == kind and unit.owner == player and unit.buildLeft == 0 and not unit.dead and not unit.blockaded then
            local d = (unit.x - x) ^ 2 + (unit.y - y) ^ 2
            if not bestD or d < bestD then
                best, bestD = unit, d
            end
        end
    end
    return best
end

function Units.check(game, player, kind, tile)
    local def = Config.units[kind]
    if not def or def.buildable == false then return false, "Unknown unit" end
    if game.phase ~= "playing" or not player.alive then return false, "Not now" end
    local map = game.map
    if def.naval then
        local port = Units.nearestPort(game, player, tile, "militaryPort")
        if not port then return false, player:unitCount("militaryPort") > 0 and "Blockaded" or "Needs military port" end
        tile = port.tile
    elseif def.coastal then
        tile = Units.findPortTile(game, player, tile)
        if not tile then return false, "Needs coast" end
    else
        if map.owner[tile] ~= player.id or not map:isLand(tile) then return false, "Not your land" end
        if not Units.isSpaced(game, tile) then return false, "Too close" end
        if def.biomes and not def.biomes[map:terrainType(tile)] then return false, def.biomeHint end
    end
    if player.gold < Units.cost(game, player, kind) then return false, "No gold" end
    return true, nil, tile
end

function Units.add(game, player, kind, tile, fields)
    local map = game.map
    local x, y = map:coords(tile)
    game.unitSerial = game.unitSerial + 1
    local unit = {
        id = game.unitSerial,
        kind = kind,
        owner = player,
        tile = tile,
        x = x + 0.5,
        y = y + 0.5,
        buildLeft = 0,
        cooldown = 0
    }
    if fields then
        for k, v in pairs(fields) do unit[k] = v end
    end
    table.insert(game.units, unit)
    player.unitCounts[kind] = player:unitCount(kind) + 1
    if Units.isBuilding(kind) then
        game.buildingAt[tile] = unit
    end
    return unit
end

function Units.complete(game, unit)
    unit.buildLeft = 0
    unit.completedTick = game.tick
    if unit.kind == "city" then
        unit.owner.cities = unit.owner.cities + 1
    end
    game:emit("unitCompleted", unit)
end

function Units.build(game, player, kind, tile)
    local ok, _, target = Units.check(game, player, kind, tile)
    if not ok then return nil end
    local cost = Units.cost(game, player, kind)
    player.gold = player.gold - cost
    local def = Config.units[kind]
    local unit = Units.add(game, player, kind, target, { buildLeft = def.buildTicks, buildTotal = def.buildTicks, cost = cost })
    if def.buildTicks == 0 then
        Units.complete(game, unit)
    end
    return unit
end

function Units.remove(game, unit)
    if unit.dead then return end
    unit.dead = true
    local owner = unit.owner
    owner.unitCounts[unit.kind] = math.max(0, owner:unitCount(unit.kind) - 1)
    if unit.kind == "city" and unit.buildLeft == 0 then
        owner.cities = math.max(0, owner.cities - 1)
    end
    if game.buildingAt[unit.tile] == unit then
        game.buildingAt[unit.tile] = nil
    end
    game:emit("unitRemoved", unit)
end

function Units.transfer(game, unit, player)
    local previous = unit.owner
    previous.unitCounts[unit.kind] = math.max(0, previous:unitCount(unit.kind) - 1)
    player.unitCounts[unit.kind] = player:unitCount(unit.kind) + 1
    if unit.kind == "city" then
        previous.cities = math.max(0, previous.cities - 1)
        player.cities = player.cities + 1
    end
    unit.owner = player
    unit.capturedTick = game.tick
    game.defenseVersion = game.defenseVersion + 1
    game:notify(previous, string.format("%s captured your %s.", player.name, Config.units[unit.kind].label), { color = { 0.95, 0.5, 0.3, 1 } })
    game:notify(player, string.format("You captured a %s from %s.", Config.units[unit.kind].label, previous.name), { color = { 0.3, 0.85, 0.45, 1 } })
end

local function defensePosts(game, player)
    if not player.defensePosts or player.defenseDirty ~= game.defenseVersion then
        local list = {}
        for _, unit in ipairs(game.units) do
            if unit.kind == "defensePost" and unit.owner == player and unit.buildLeft == 0 and not unit.dead then
                list[#list + 1] = unit
            end
        end
        player.defensePosts = list
        player.defenseDirty = game.defenseVersion
    end
    return player.defensePosts
end

function Units.defenseBonus(game, player, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local bonus = 1
    local capital = player.capital
    if capital and not capital.dead then
        local cdef = Config.units.capital
        if (capital.x - x) ^ 2 + (capital.y - y) ^ 2 <= cdef.radius * cdef.radius then
            bonus = cdef.defense
        end
    end
    if player:unitCount("defensePost") == 0 then return bonus end
    local def = Config.units.defensePost
    local r2 = def.radius * def.radius
    for _, unit in ipairs(defensePosts(game, player)) do
        local dx, dy = unit.x - x, unit.y - y
        if dx * dx + dy * dy <= r2 then
            return math.max(bonus, def.defense)
        end
    end
    return bonus
end

function Units.init(game)
    game.units = {}
    game.unitSerial = 0
    game.buildingAt = {}
    game.defenseBonus = Units.defenseBonus
    game.defenseVersion = 0
end

function Units.unitCompleted(game, unit)
    if unit.kind == "defensePost" then
        game.defenseVersion = game.defenseVersion + 1
    end
end

Units.unitRemoved = Units.unitCompleted

function Units.tileChanged(game, i, previous, id)
    local unit = game.buildingAt[i]
    if not unit or unit.owner.id == id then return end
    local def = Config.units[unit.kind]
    if id == 0 or unit.buildLeft > 0 or def.destroyOnCapture then
        unit.capturedBy = id ~= 0 and game.players[id] or nil
        Units.remove(game, unit)
    else
        Units.transfer(game, unit, game.players[id])
    end
end

function Units.step(game)
    if game.phase ~= "playing" then return end
    local list = game.units
    for k = 1, #list do
        local unit = list[k]
        if not unit.dead then
            if unit.buildLeft > 0 then
                unit.buildLeft = unit.buildLeft - 1
                if unit.buildLeft == 0 then
                    Units.complete(game, unit)
                end
            elseif unit.cooldown > 0 then
                unit.cooldown = unit.cooldown - 1
            end
            if unit.update and not unit.dead then
                unit.update(game, unit)
            end
        end
    end
    for k = #list, 1, -1 do
        if list[k].dead then
            table.remove(list, k)
        end
    end
end

Units.intents = {
    build = function(game, intent)
        local player = game.players[intent.player]
        if not player then return end
        local unit = Units.build(game, player, intent.unit, intent.tile)
        if unit then
            game:notify(player, string.format("Building %s (%s gold).", Config.units[intent.unit].label, Format.number(unit.cost)))
        end
    end
}

return Units
