local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")
local Vision = require("src.modules.game.systems.vision")
local Personality = require("src.modules.ai.personality")
local Negotiator = require("src.modules.ai.negotiator")
local Coalitionist = require("src.modules.ai.coalitionist")

local memory = Negotiator.memory

local Strategist = {}

local MIN_TICK = 3000
local STRIKE_MEMORY = 3000
local MAX_STRIKES = 8
local RANDOM_SAMPLES = 6
local JITTER = 6
local TARGET_VALUES = {
    capital = 3, city = 2, silo = 2.5, factory = 1.6, tradePort = 1.3, militaryPort = 1.3,
    barracks = 1.2, radar = 1.2, mine = 1.1, farm = 1, sam = 0.8, defensePost = 0.8
}

local function enemyHasSilo(game, player)
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and not player:isAlliedWith(other) and other:unitCount("silo") > 0 then
            return true
        end
    end
    return false
end

local function chooseVictim(game, player, ctx)
    local land = game.map.landCount
    local best, bestScore
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and other.tiles > 0 and player:canAttack(other) and not other:isBot() then
            local score = -player:relation(other) + other.tiles / land * 300
            if Coalitionist.isTarget(game, player, other) then
                score = score + 100
            end
            if not bestScore or score > bestScore then
                best, bestScore = other, score
            end
        end
    end
    if best and bestScore > 60 / Personality.of(player).nuclear then return best end
    return nil
end

local function known(game, player, unit)
    return not Config.aiNukeFog or Vision.knows(game, player, unit.x, unit.y, unit.kind)
end

local function recentStrikes(game, player)
    local kept = {}
    for _, strike in ipairs(memory(player).strikes or {}) do
        if game.tick - strike.tick < STRIKE_MEMORY then
            kept[#kept + 1] = strike
        end
    end
    memory(player).strikes = kept
    return kept
end

local function remember(game, player, tile, kind)
    local strikes = recentStrikes(game, player)
    local x, y = game.map:coords(tile)
    strikes[#strikes + 1] = { x = x, y = y, radius = Config.nukes[kind].outer, tick = game.tick }
    while #strikes > MAX_STRIKES do
        table.remove(strikes, 1)
    end
end

local function randomTerritory(game, victim)
    local map = game.map
    local rng = game.aiRng
    local cx, cy = victim:center()
    local spread = math.sqrt(victim.tiles) * 0.9
    local x = cx + (rng:random() * 2 - 1) * spread
    local y = cy + (rng:random() * 2 - 1) * spread
    return map:findNear(x, y, 25, function(i) return map.owner[i] == victim.id end)
end

local function weight(game, strikes, tile, value)
    local map = game.map
    local x, y = map:coords(tile)
    for _, strike in ipairs(strikes) do
        local d2 = (strike.x - x) ^ 2 + (strike.y - y) ^ 2
        if d2 < strike.radius ^ 2 then
            value = value * 0.08
        elseif d2 < (strike.radius * 2) ^ 2 then
            value = value * 0.45
        end
    end
    if map.fallout[tile] > 0 then
        value = value * 0.3
    end
    return value
end

local function candidates(game, player, victim)
    local rng = game.aiRng
    local strikes = recentStrikes(game, player)
    local list = {}
    local function add(tile, value)
        if tile then
            list[#list + 1] = { tile = tile, weight = weight(game, strikes, tile, value) }
        end
    end
    for _, unit in ipairs(Units.list(game, victim)) do
        local value = TARGET_VALUES[unit.kind]
        if value and not unit.dead and known(game, player, unit) then
            add(unit.tile, value)
        end
    end
    local x, y = victim:center()
    if not Config.aiNukeFog or Vision.knows(game, player, x, y) then
        add(game.map:findNear(x, y, 30, function(i) return game.map.owner[i] == victim.id end), 1)
    end
    for _ = 1, RANDOM_SAMPLES do
        add(randomTerritory(game, victim), 0.9 + rng:random() * 0.4)
    end
    return list
end

local function pick(game, list)
    local total = 0
    for _, entry in ipairs(list) do
        total = total + entry.weight
    end
    if total <= 0 then return nil end
    local roll = game.aiRng:random() * total
    for _, entry in ipairs(list) do
        roll = roll - entry.weight
        if roll <= 0 then return entry.tile end
    end
    return list[#list].tile
end

local function targetTile(game, player, victim)
    local rng = game.aiRng
    local map = game.map
    local tile = pick(game, candidates(game, player, victim))
    if not tile then return nil end
    local x, y = map:coords(tile)
    x = x + rng:random(-JITTER, JITTER)
    y = y + rng:random(-JITTER, JITTER)
    return map:findNear(x, y, JITTER * 2, function(i) return map.owner[i] == victim.id end) or tile
end

Strategist.targetTile = targetTile

function Strategist.behavior(game, player, ctx)
    if game.tick < MIN_TICK or game.options.difficulty == "easy" or memory(player).saving then return false end
    local rng = game.aiRng
    local traits = Personality.of(player)
    if rng:random() > 0.3 * math.max(traits.nuclear, traits.caution) then return false end

    if player:unitCount("silo") == 0 then
        if player.gold > Units.cost(game, player, "silo") * 1.5 and rng:random() < 0.5 * traits.nuclear then
            local tile = player.spawnTile and game.map.owner[player.spawnTile] == player.id and player.spawnTile
            if not tile then
                local x, y = player:center()
                tile = game.map:findNear(x, y, 20, function(i) return game.map.owner[i] == player.id and Units.isSpaced(game, i) end)
            end
            if tile and Units.check(game, player, "silo", tile) then
                game:command({ type = "build", player = player.id, unit = "silo", tile = tile })
                return true
            end
        end
    end

    if player:unitCount("sam") < math.floor((1 + player.tiles / 40000) * traits.caution) and enemyHasSilo(game, player) and player.gold > Units.cost(game, player, "sam") then
        local cities = Units.list(game, player, "city")
        local anchor = cities[1] and cities[rng:random(#cities)].tile or player.spawnTile
        if anchor then
            local x, y = game.map:coords(anchor)
            local tile = game.map:findNear(x + rng:random(-8, 8), y + rng:random(-8, 8), 15, function(i)
                return game.map.owner[i] == player.id and Units.isSpaced(game, i)
            end)
            if tile and Units.check(game, player, "sam", tile) then
                game:command({ type = "build", player = player.id, unit = "sam", tile = tile })
                return true
            end
        end
    end

    local victim = chooseVictim(game, player, ctx)
    if not victim then return false end
    local tile = targetTile(game, player, victim)
    if not tile then return false end
    local reserve = 500000
    for _, kind in ipairs({ "mirv", "hydrogen", "atom" }) do
        local def = Config.nukes[kind]
        local allowed = kind ~= "mirv" or victim.tiles / game.map.landCount > 0.3
        if allowed and player.gold > def.cost + reserve and Nukes.check(game, player, kind, tile) then
            game:command({ type = "nuke", player = player.id, kind = kind, tile = tile })
            remember(game, player, tile, kind)
            return true
        end
    end
    return false
end

return Strategist
