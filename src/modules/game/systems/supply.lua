local Config = require("src.config.game")

local Supply = {}

local CELL = 8

local EMPTY = {}

function Supply.refresh(game, player)
    local points = {}
    for _, unit in ipairs(game.units) do
        if Config.supplySources[unit.kind] and unit.owner == player and unit.buildLeft == 0 and not unit.dead then
            points[#points + 1] = unit.x
            points[#points + 1] = unit.y
        end
    end
    local map = game.map
    for _, rail in ipairs(game.rails or {}) do
        if rail.a.owner == player and rail.built >= #rail.tiles then
            for k = 1, #rail.tiles, Config.supplyRailStep do
                local x, y = map:coords(rail.tiles[k])
                points[#points + 1] = x + 0.5
                points[#points + 1] = y + 0.5
            end
        end
    end
    player.supplyPoints = points
    player.supplyTick = game.tick
    player.supplyCache = {}
end

function Supply.points(game, player)
    return player.supplyPoints or EMPTY
end

function Supply.refreshAll(game)
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned then
            Supply.refresh(game, player)
        end
    end
end

function Supply.started(game)
    Supply.refreshAll(game)
end

function Supply.step(game)
    if game.phase ~= "playing" or game.tick % Config.supplyRefreshTicks ~= 0 then return end
    Supply.refreshAll(game)
end

function Supply.distance(game, player, x, y)
    local points = Supply.points(game, player)
    if #points == 0 then return nil end
    local best = math.huge
    for k = 1, #points, 2 do
        local dx, dy = points[k] - x, points[k + 1] - y
        local d = dx * dx + dy * dy
        if d < best then best = d end
    end
    return math.sqrt(best)
end

function Supply.multiplierAt(game, player, x, y)
    local d = Supply.distance(game, player, x, y)
    if not d or d <= Config.supplyRange then return 1 end
    return math.min(Config.supplyMaxPenalty, 1 + (d - Config.supplyRange) / Config.supplyFalloff)
end

function Supply.multiplier(game, player, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local key = math.floor(y / CELL) * 65536 + math.floor(x / CELL)
    local cache = player.supplyCache
    if not cache then return 1 end
    local value = cache[key]
    if not value then
        value = Supply.multiplierAt(game, player, (math.floor(x / CELL) + 0.5) * CELL, (math.floor(y / CELL) + 0.5) * CELL)
        cache[key] = value
    end
    return value
end

return Supply
