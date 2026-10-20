local Config = require("src.config.game")

local Economy = {}

function Economy.maxPopulation(game, player)
    local max = (player.tiles ^ Config.populationExponent) * Config.populationPerTile + Config.basePopulation
    max = max + (player.cities or 0) * Config.cityPopulation
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

function Economy.updatePlayer(game, player)
    local max = Economy.maxPopulation(game, player)
    player.maxPopulation = max
    local total = player.troops + player.workers
    local growth = (10 + math.max(0, total) ^ Config.growthExponent / 4) * (1 - total / max)
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
    player.income = income
    player.gold = player.gold + income
end

function Economy.step(game)
    if game.phase ~= "playing" then return end
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.tiles > 0 then
            Economy.updatePlayer(game, player)
        end
    end
end

return Economy
