local Config = require("src.config.game")

local Rails = {}

local STATIONS = { city = true, tradePort = true }

function Rails.init(game)
    game.rails = {}
end

local function line(map, a, b)
    local x1, y1 = map:coords(a)
    local x2, y2 = map:coords(b)
    local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
    local tiles = {}
    for k = 0, steps do
        local x = math.floor(x1 + (x2 - x1) * k / steps + 0.5)
        local y = math.floor(y1 + (y2 - y1) * k / steps + 0.5)
        tiles[#tiles + 1] = map:index(x, y)
    end
    return tiles
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
    local distance = math.sqrt((factory.x - station.x) ^ 2 + (factory.y - station.y) ^ 2)
    if distance > Config.railRadius or distance < 2 then return end
    local rail = { a = factory, b = station, tiles = line(game.map, factory.tile, station.tile), progress = 0, direction = 1 }
    if Rails.valid(game, rail) then
        table.insert(game.rails, rail)
    end
end

function Rails.unitCompleted(game, unit)
    if unit.kind == "factory" then
        for _, other in ipairs(game.units) do
            if STATIONS[other.kind] and other.owner == unit.owner and other.buildLeft == 0 and not other.dead then
                Rails.connect(game, unit, other)
            end
        end
    elseif STATIONS[unit.kind] then
        for _, other in ipairs(game.units) do
            if other.kind == "factory" and other.owner == unit.owner and other.buildLeft == 0 and not other.dead then
                Rails.connect(game, other, unit)
            end
        end
    end
end

function Rails.step(game)
    if game.phase ~= "playing" then return end
    local check = game.tick % Config.railCheckTicks == 0
    local list = game.rails
    for k = #list, 1, -1 do
        local rail = list[k]
        if check and not Rails.valid(game, rail) then
            table.remove(list, k)
        else
            rail.progress = rail.progress + Config.trainSpeed
            if rail.progress >= #rail.tiles then
                rail.progress = 0
                rail.direction = -rail.direction
                local owner = rail.a.owner
                local gold = Config.trainGold + #rail.tiles * Config.trainGoldPerTile
                owner.gold = owner.gold + gold
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
