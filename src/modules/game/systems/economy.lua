local Config = require("src.config.game")
local DMath = require("src.core.dmath")
local Hash = require("src.core.hash")

local Economy = {}

function Economy.maxPopulation(game, player)
    local max = DMath.pow(player.tiles, Config.populationExponent) * Config.populationPerTile + Config.basePopulation
    local housing = Economy.stacked(player.cities or 0, Config.cityPopulation, Config.cityDiminishing)
        + Economy.built(game, player, "farm") * Config.farmPopulation
    local capacity = Economy.housingCapacity(player)
    player.crowded = housing > capacity
    max = max + math.min(housing, capacity)
    if player.capital and not player.capital.dead then
        max = max + Config.capitalPopulation
    end
    if player:isBot() then
        max = max * Config.botPopulationFactor
    elseif player:isNation() then
        max = max * game:difficulty().population
    end
    return max
end

function Economy.housingCapacity(player)
    return Config.housingBase + player.tiles * Config.housingPerTile
end

function Economy.goldRate(game, player)
    local rate = math.sqrt(math.max(0, player.workers) * player.tiles) / Config.goldDivisor * (player.administration or 1)
    if player:isBot() then
        rate = rate * Config.botGoldFactor
    elseif player:isNation() then
        rate = rate * game:difficulty().gold
    end
    return rate
end

function Economy.efficiencyAt(points, x, y)
    if not points or #points == 0 then return nil end
    local best = math.huge
    for k = 1, #points, 2 do
        local dx, dy = points[k] - x, points[k + 1] - y
        local d = dx * dx + dy * dy
        if d < best then best = d end
    end
    local d = math.sqrt(best)
    if d <= Config.adminRange then return 1 end
    return math.max(Config.adminFloor, 1 - (d - Config.adminRange) / Config.adminFalloff)
end

local function sampleAdministration(game, player, points)
    local map = game.map
    local cx, cy = player:center()
    local sx, sy = player:spread()
    sx, sy = sx * 2.2 + 2, sy * 2.2 + 2
    local bucket = math.floor(game.tick / Config.adminRefreshTicks)
    local total, count = 0, 0
    for k = 1, Config.adminSamples do
        local h = Hash.combine(Hash.combine(Hash.combine(player.id, k), bucket), 0xad1)
        local ox = (h % 2001) / 1000 - 1
        local oy = (math.floor(h / 2001) % 2001) / 1000 - 1
        local x, y = math.floor(cx + ox * sx), math.floor(cy + oy * sy)
        if map:isValid(x, y) and map.owner[map:index(x, y)] == player.id then
            total = total + Economy.efficiencyAt(points, x + 0.5, y + 0.5)
            count = count + 1
        end
    end
    if count == 0 then return player.administration or 1 end
    return total / count
end

function Economy.refreshAdministration(game)
    local points = {}
    for _, unit in ipairs(game.units) do
        if Config.adminSources[unit.kind] and unit.buildLeft == 0 and not unit.dead then
            local list = points[unit.owner.id]
            if not list then
                list = {}
                points[unit.owner.id] = list
            end
            list[#list + 1] = unit.x
            list[#list + 1] = unit.y
        end
    end
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.tiles > 0 then
            local list = points[player.id]
            player.adminPoints = list
            if list then
                player.administration = sampleAdministration(game, player, list)
            end
        end
    end
end

function Economy.countBuildings(game)
    local counts = {}
    for _, unit in ipairs(game.units) do
        if unit.buildLeft == 0 and not unit.dead then
            local owned = counts[unit.owner.id]
            if not owned then
                owned = {}
                counts[unit.owner.id] = owned
            end
            owned[unit.kind] = (owned[unit.kind] or 0) + 1
            if unit.kind == "mine" then
                if not unit.richness then
                    unit.richness = Config.units.mine.biomes[game.map:terrainType(unit.tile)] or 1
                end
                owned.mineGold = (owned.mineGold or 0) + Config.units.mine.gold * unit.richness
            end
        end
    end
    game.buildingCounts = counts
end

function Economy.built(game, player, kind)
    local owned = game.buildingCounts and game.buildingCounts[player.id]
    return owned and owned[kind] or 0
end

function Economy.mineIncome(game, player)
    local owned = game.buildingCounts and game.buildingCounts[player.id]
    return owned and owned.mineGold or 0
end

function Economy.stacked(count, per, exponent)
    if count <= 0 then return 0 end
    return per * DMath.pow(count, exponent or Config.buildingDiminishing)
end

function Economy.upkeep(game, player)
    return Economy.built(game, player, "barracks") * Config.barracksUpkeep + Economy.built(game, player, "radar") * Config.radarUpkeep
end

function Economy.training(game, player)
    return math.min(Config.barracksTrainingCap, Economy.stacked(Economy.built(game, player, "barracks"), Config.barracksTraining))
end

function Economy.updatePlayer(game, player)
    local max = Economy.maxPopulation(game, player)
    player.maxPopulation = max
    local total = player.troops + player.workers
    local growth = (10 + DMath.pow(math.max(0, total), Config.growthExponent) / 4) * (1 - total / max)
    local crippled = player.capitalLostUntil and player.capitalLostUntil > game.tick
    if crippled and growth > 0 then
        growth = growth * Config.capitalPenalty
    end
    local upkeep = Economy.upkeep(game, player)
    local paid = upkeep > 0 and player.gold >= upkeep
    player.upkeepPaid = upkeep == 0 or paid
    local recruit = 1
    if growth > 0 then
        recruit = recruit + Economy.stacked(Economy.built(game, player, "farm"), Config.farmGrowth)
        if paid then
            recruit = recruit + Economy.stacked(Economy.built(game, player, "barracks"), Config.barracksRecruit)
        end
    end
    growth = growth * recruit
    player.growth = growth
    player.troops = player.troops + growth * player.troopRatio
    player.workers = player.workers + growth * (1 - player.troopRatio)

    total = player.troops + player.workers
    local diff = total * player.troopRatio - player.troops
    local limit = total * Config.rebalanceRate
    local move = math.max(-limit, math.min(limit, diff))
    player.troops = math.max(0, player.troops + move)
    player.workers = math.max(0, player.workers - move)

    local income = Economy.goldRate(game, player)
    if crippled then
        income = income * Config.capitalPenalty
    end
    income = income + Economy.mineIncome(game, player)
    if paid then
        income = income - upkeep
    end
    player.income = income
    player.gold = math.max(0, player.gold + income)
end

function Economy.step(game)
    if game.phase ~= "playing" then return end
    Economy.countBuildings(game)
    if game.tick % Config.adminRefreshTicks == 0 then
        Economy.refreshAdministration(game)
    end
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.tiles > 0 then
            Economy.updatePlayer(game, player)
        end
    end
end

Economy.intents = {
    troopRatio = function(game, intent)
        local player = game.players[intent.player]
        if player and type(intent.ratio) == "number" then
            player.troopRatio = math.max(0, math.min(1, intent.ratio))
        end
    end
}

return Economy
