local Config = require("src.config.game")

local Economy = {}

function Economy.maxPopulation(game, player)
    local max = (player.tiles ^ Config.populationExponent) * Config.populationPerTile + Config.basePopulation
    max = max + (player.cities or 0) * Config.cityPopulation
    max = max + Economy.built(game, player, "farm") * Config.farmPopulation
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

function Economy.goldRate(game, player)
    local rate = math.sqrt(math.max(0, player.workers) * player.tiles) / Config.goldDivisor
    if player:isBot() then
        rate = rate * Config.botGoldFactor
    elseif player:isNation() then
        rate = rate * game:difficulty().gold
    end
    return rate
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

function Economy.stacked(count, per)
    if count <= 0 then return 0 end
    return per * count ^ Config.buildingDiminishing
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
    local growth = (10 + math.max(0, total) ^ Config.growthExponent / 4) * (1 - total / max)
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
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.tiles > 0 then
            Economy.updatePlayer(game, player)
        end
    end
end

return Economy
