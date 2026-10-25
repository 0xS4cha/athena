local Units = require("src.modules.game.systems.units")
local Config = require("src.config.game")
local Personality = require("src.modules.ai.personality")
local Economy = require("src.modules.game.systems.economy")

local Builder = {}

local function randomOwnTile(game, player, predicate, scale)
    local map = game.map
    local rng = game.aiRng
    local cx, cy = player:center()
    local spread = math.sqrt(player.tiles) * (scale or 0.6)
    for _ = 1, 12 do
        local tile = map:findNear(cx + (rng:random() * 2 - 1) * spread, cy + (rng:random() * 2 - 1) * spread, 8, function(i)
            return map.owner[i] == player.id and (not predicate or predicate(i))
        end)
        if tile then return tile end
    end
    return nil
end

local function remoteTile(game, player)
    local best, bestEfficiency
    for _ = 1, 6 do
        local tile = randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end, 1.3)
        if tile then
            local x, y = game.map:coords(tile)
            local efficiency = Economy.efficiencyAt(player.adminPoints, x + 0.5, y + 0.5) or 1
            if not bestEfficiency or efficiency < bestEfficiency then
                best, bestEfficiency = tile, efficiency
            end
        end
    end
    return best
end

local function coastTile(game, player)
    local map = game.map
    local candidates = {}
    for b in pairs(player.borders) do
        if map:isCoast(b) then
            candidates[#candidates + 1] = b
            if #candidates > 200 then break end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[game.aiRng:random(#candidates)]
end

local function frontTile(game, player, enemy)
    local map = game.map
    local nb = {}
    local candidates = {}
    for b in pairs(player.borders) do
        local count = map:neighbors(b, nb)
        for k = 1, count do
            if map.owner[nb[k]] == enemy.id then
                candidates[#candidates + 1] = b
                break
            end
        end
        if #candidates > 100 then break end
    end
    if #candidates == 0 then return nil end
    return candidates[game.aiRng:random(#candidates)]
end

function Builder.request(game, player, kind, tile)
    if not tile then return false end
    local ok = Units.check(game, player, kind, tile)
    if not ok then return false end
    game:command({ type = "build", player = player.id, unit = kind, tile = tile })
    return true
end

Builder.wishes = {
    function(game, player)
        if not player.crowded and player:unitCount("city") < 1 + math.floor(player.tiles * Personality.of(player).greed / 12000) then
            if (player.administration or 1) < 0.85 then
                return "city", remoteTile(game, player)
            end
            return "city", randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
        end
    end,
    function(game, player)
        if player:unitCount("tradePort") < 1 + math.floor(player:unitCount("city") * Personality.of(player).greed / 2) then
            local tile = coastTile(game, player)
            if tile then return "tradePort", tile end
        end
    end,
    function(game, player, ctx)
        local wanted = ctx.isolated and 2 or 1
        if (ctx.isolated or game.tick > 1500) and player:unitCount("militaryPort") < wanted then
            local tile = coastTile(game, player)
            if tile then return "militaryPort", tile end
        end
    end,
    function(game, player)
        local cities = player:unitCount("city")
        if cities >= 2 and player:unitCount("factory") < 1 + math.floor(cities * Personality.of(player).greed / 3) then
            return "factory", randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
        end
    end,
    function(game, player)
        local ports = player:unitCount("militaryPort")
        if ports > 0 and player:unitCount("warship") < ports + 1 and game.aiRng:random() < 0.3 then
            local port = Units.nearestPort(game, player, player.spawnTile or 0, "militaryPort")
            if port then return "warship", port.tile end
        end
    end,
    function(game, player)
        local plains = player.biomeTiles[Config.biomes.plains.id]
        if plains < 500 or player:unitCount("farm") >= 1 + math.floor(plains / 8000) then return end
        return "farm", randomOwnTile(game, player, function(i)
            return game.map:terrainType(i) == "plains" and Units.isSpaced(game, i)
        end)
    end,
    function(game, player)
        local rich = player.biomeTiles[Config.biomes.mountain.id] + player.biomeTiles[Config.biomes.desert.id]
        if rich < 400 or player:unitCount("mine") >= 1 + math.floor(rich / 6000) then return end
        local biomes = Config.units.mine.biomes
        return "mine", randomOwnTile(game, player, function(i)
            return biomes[game.map:terrainType(i)] ~= nil and Units.isSpaced(game, i)
        end)
    end,
    function(game, player, ctx)
        if game.tick < 2500 or player.income < 80 or player:unitCount("radar") >= 1 + math.floor(player.tiles / 60000) then return end
        local hostile = false
        for _, other in ipairs(ctx.neighbors) do
            if player:canAttack(other) and not other:isBot() then hostile = true end
        end
        if not hostile then return end
        local tile = randomOwnTile(game, player, function(i) return game.map:terrainType(i) == "mountain" and Units.isSpaced(game, i) end)
        return "radar", tile or randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
    end,
    function(game, player, ctx)
        local traits = Personality.of(player)
        if player:unitCount("barracks") >= 1 + math.floor(player.tiles * traits.aggression / 25000) or player.income < 40 then return end
        for _, other in ipairs(ctx.neighbors) do
            if player:canAttack(other) and not other:isBot() and other.troops > player.troops * 0.8 / traits.aggression then
                return "barracks", randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
            end
        end
    end,
    function(game, player, ctx)
        local traits = Personality.of(player)
        if player:unitCount("defensePost") >= math.floor((2 + player.tiles / 20000) * traits.caution) then return end
        for _, other in ipairs(ctx.neighbors) do
            if not player:isAlliedWith(other) and other.troops > player.troops * 1.2 / traits.caution then
                return "defensePost", frontTile(game, player, other)
            end
        end
    end
}

function Builder.behavior(game, player, ctx)
    if player.aiMemory and player.aiMemory.saving then return false end
    if game.aiRng:random() > math.min(0.85, 0.5 * Personality.of(player).greed) then return false end
    for _, wish in ipairs(Builder.wishes) do
        local kind, tile = wish(game, player, ctx)
        if kind and tile and player.gold >= Units.cost(game, player, kind) then
            if Builder.request(game, player, kind, tile) then
                return false
            end
        end
    end
    return false
end

return Builder
