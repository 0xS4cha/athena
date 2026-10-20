local Config = require("src.config.game")
local Format = require("src.core.format")
local Units = require("src.modules.game.systems.units")
local Attack = require("src.modules.game.systems.attack")
local Pathfinding = require("src.modules.map.pathfinding")

local Ships = {}

function Ships.init(game)
    game.pathfinder = Pathfinding.new(game.map)
end

function Ships.findPath(game, from, to)
    return game.pathfinder:water(from, to, Config.pathMaxNodes)
end

function Ships.place(game, unit)
    local path = unit.path
    local index = math.min(#path, math.max(1, math.floor(unit.progress)))
    local x, y = game.map:coords(path[index])
    unit.x = x + 0.5
    unit.y = y + 0.5
    unit.tile = path[index]
end

function Ships.advance(game, unit, speed)
    unit.progress = unit.progress + speed
    Ships.place(game, unit)
    return unit.progress >= #unit.path
end

function Ships.landingTile(game, player, tile)
    local map = game.map
    if map:isWater(tile) then return nil end
    local ownerId = map.owner[tile]
    if ownerId == player.id then return nil end
    if map:isCoast(tile) then return tile end
    local x, y = map:coords(tile)
    return map:findNear(x, y, Config.boatLandingSearch, function(i)
        return map.owner[i] == ownerId and map:isCoast(i)
    end)
end

function Ships.launchTile(game, player, destination)
    local map = game.map
    local dx, dy = map:coords(destination)
    local candidates = {}
    for b in pairs(player.borders) do
        if map:isCoast(b) then
            local x, y = map:coords(b)
            candidates[#candidates + 1] = { tile = b, d = (x - dx) * (x - dx) + (y - dy) * (y - dy) }
        end
    end
    table.sort(candidates, function(a, b) return a.d < b.d end)
    for k = 1, math.min(25, #candidates) do
        if game.pathfinder:connected(candidates[k].tile, destination) then
            return candidates[k].tile
        end
    end
    return nil
end

function Ships.canSendBoat(game, player, tile)
    if player:unitCount("transport") >= Config.maxBoats then
        return false, "Max boats"
    end
    local destination = Ships.landingTile(game, player, tile)
    if not destination then return false, "No landing" end
    local target = game:playerAt(destination)
    if target and player:isAlliedWith(target) then return false, "Allied" end
    local source = Ships.launchTile(game, player, destination)
    if not source then return false, "No sea route" end
    return true, nil, source, destination
end

function Ships.updateTransport(game, unit)
    if not Ships.advance(game, unit, Config.boatSpeed) then return end
    local player = unit.owner
    local map = game.map
    local tile = unit.path[#unit.path]
    local ownerId = map.owner[tile]
    local target = ownerId ~= 0 and game.players[ownerId] or nil
    player.troops = player.troops + unit.troops
    if ownerId ~= player.id and player.alive and not (target and player:isAlliedWith(target)) then
        game:setOwner(tile, player.id)
        Attack.launch(game, player, ownerId, unit.troops)
    end
    Units.remove(game, unit)
end

function Ships.sendBoat(game, player, tile, troops)
    local ok, reason, source, destination = Ships.canSendBoat(game, player, tile)
    if not ok then
        game:notify(player, "Cannot send boat: " .. reason .. ".")
        return nil
    end
    troops = math.floor(math.min(troops, player.troops))
    if troops < 1 then return nil end
    local path = Ships.findPath(game, source, destination)
    if not path then
        game:notify(player, "No sea route to that coast.")
        return nil
    end
    player.troops = player.troops - troops
    local unit = Units.add(game, player, "transport", source, {
        path = path,
        progress = 1,
        troops = troops,
        destination = destination,
        update = Ships.updateTransport
    })
    local target = game:playerAt(destination)
    if target then
        game:notify(target, string.format("%s is sending a boat with %s troops!", player.name, Format.number(troops)), { color = { 0.95, 0.35, 0.3, 1 } })
    end
    return unit
end

function Ships.eliminated(game, player)
    for _, unit in ipairs(game.units) do
        if unit.owner == player and not Units.isBuilding(unit.kind) then
            Units.remove(game, unit)
        end
    end
end

Ships.intents = {
    boat = function(game, intent)
        if game.phase ~= "playing" then return end
        local player = game.players[intent.player]
        if not player or not player.alive then return end
        Ships.sendBoat(game, player, intent.tile, player.troops * (intent.ratio or player.attackRatio))
    end
}

return Ships
