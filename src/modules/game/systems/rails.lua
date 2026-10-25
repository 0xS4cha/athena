local Config = require("src.config.game")
local DMath = require("src.core.dmath")

local function sq(v) return v * v end

local Rails = {}

local STATIONS = { city = true, tradePort = true }

function Rails.init(game)
    game.rails = {}
end

local function exists(game, a, b)
    for _, rail in ipairs(game.rails) do
        if (rail.a == a and rail.b == b) or (rail.a == b and rail.b == a) then
            return true
        end
    end
    return false
end

function Rails.valid(game, rail)
    if rail.a.dead or rail.b.dead or rail.a.owner ~= rail.b.owner then
        return false
    end
    local owner = rail.a.owner.id
    local own = game.map.owner
    for _, tile in ipairs(rail.tiles) do
        if own[tile] ~= owner then return false end
    end
    return true
end

function Rails.connect(game, factory, station)
    if exists(game, factory, station) then return end
    local distance = math.sqrt(sq(factory.x - station.x) + sq(factory.y - station.y))
    if distance > Config.railRadius or distance < 2 then return end
    local tiles = game.pathfinder:land(factory.tile, station.tile, factory.owner.id, Config.railMaxNodes)
    if not tiles or #tiles > Config.railRadius * 2 then return end
    table.insert(game.rails, { a = factory, b = station, tiles = tiles, built = 0, progress = 0, direction = 1 })
end

function Rails.links(game, factory)
    local count = 0
    for _, rail in ipairs(game.rails) do
        if rail.a == factory then count = count + 1 end
    end
    return count
end

local function nearest(game, unit, accept)
    local list = {}
    for _, other in ipairs(game.units) do
        if other.owner == unit.owner and other.buildLeft == 0 and not other.dead and accept(other) then
            list[#list + 1] = other
        end
    end
    table.sort(list, function(a, b)
        local da, db = sq(a.x - unit.x) + sq(a.y - unit.y), sq(b.x - unit.x) + sq(b.y - unit.y)
        if da == db then return a.id < b.id end
        return da < db
    end)
    return list
end

function Rails.unitCompleted(game, unit)
    if unit.kind == "factory" then
        for _, station in ipairs(nearest(game, unit, function(other) return STATIONS[other.kind] end)) do
            if Rails.links(game, unit) >= Config.railLinks then break end
            Rails.connect(game, unit, station)
        end
    elseif STATIONS[unit.kind] then
        for _, factory in ipairs(nearest(game, unit, function(other) return other.kind == "factory" end)) do
            if Rails.links(game, factory) < Config.railLinks then
                Rails.connect(game, factory, unit)
            end
        end
    end
end

function Rails.trainGold(rail, active)
    local gold = Config.trainGold + #rail.tiles * Config.trainGoldPerTile
    return gold * DMath.pow(math.max(1, active), Config.trainDiminishing - 1)
end

function Rails.step(game)
    if game.phase ~= "playing" then return end
    local check = game.tick % Config.railCheckTicks == 0
    local list = game.rails
    local active = {}
    for _, rail in ipairs(list) do
        if rail.built >= #rail.tiles then
            local id = rail.a.owner.id
            active[id] = (active[id] or 0) + 1
        end
    end
    for k = #list, 1, -1 do
        local rail = list[k]
        if check and not Rails.valid(game, rail) then
            table.remove(list, k)
        elseif rail.built < #rail.tiles then
            rail.built = math.min(#rail.tiles, rail.built + Config.railBuildSpeed)
        else
            rail.progress = rail.progress + Config.trainSpeed
            if rail.progress >= #rail.tiles then
                rail.progress = 0
                rail.direction = -rail.direction
                local owner = rail.a.owner
                owner.gold = owner.gold + Rails.trainGold(rail, active[owner.id])
            end
        end
    end
end

function Rails.trainPosition(game, rail)
    local index = math.max(1, math.min(#rail.tiles, math.floor(rail.progress) + 1))
    if rail.direction < 0 then
        index = #rail.tiles - index + 1
    end
    local x, y = game.map:coords(rail.tiles[index])
    return x + 0.5, y + 0.5
end

return Rails
