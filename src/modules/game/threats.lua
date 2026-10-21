local Config = require("src.config.game")
local Vision = require("src.modules.game.systems.vision")

local Threats = {}

local MAX_TILES = 4000

Threats.levels = {
    { label = "Low", limit = 0.4, color = { 0.35, 0.85, 0.45 } },
    { label = "Medium", limit = 0.9, color = { 1, 0.82, 0.25 } },
    { label = "High", limit = 1.6, color = { 1, 0.5, 0.2 } },
    { label = "Critical", limit = math.huge, color = { 0.95, 0.2, 0.18 } }
}

function Threats.level(score)
    for k, level in ipairs(Threats.levels) do
        if score < level.limit then
            return k, level
        end
    end
    return #Threats.levels, Threats.levels[#Threats.levels]
end

function Threats.troops(game, viewer, player)
    if Vision.observes(game, viewer, player) then
        return player.troops
    end
    return Vision.estimate(game, player)
end

local function hostility(game, player, other)
    local value = 1
    local relation = player:relation(other)
    if relation < 0 then
        value = value + -relation / 100
    end
    if other.traitorUntil > game.tick then
        value = value * 1.2
    end
    if other.target == player.id then
        value = value * 1.3
    end
    if other:isBot() then
        value = value * 0.6
    end
    local pact = player.pacts[other.id]
    if pact then
        value = value * (pact.endsTick and 0.8 or 0.25)
    end
    for _, attack in ipairs(game.attacks) do
        if not attack.done and attack.attacker == other and attack.target == player then
            value = value * 1.5
            break
        end
    end
    return value
end

function Threats.compute(game, player)
    local map = game.map
    local own = map.owner
    local nb = {}
    local fronts = {}
    local order = {}
    local count = 0
    for tile in pairs(player.borders) do
        local n = map:neighbors(tile, nb)
        for k = 1, n do
            local id = own[nb[k]]
            if id ~= 0 and id ~= player.id then
                local other = game.players[id]
                if other and not player:isAlliedWith(other) then
                    local front = fronts[id]
                    if not front then
                        front = { player = other, tiles = {}, sumX = 0, sumY = 0 }
                        fronts[id] = front
                        order[#order + 1] = front
                    end
                    if count < MAX_TILES then
                        local x, y = map:coords(tile)
                        front.tiles[#front.tiles + 1] = tile
                        front.sumX, front.sumY = front.sumX + x, front.sumY + y
                        count = count + 1
                    end
                    break
                end
            end
        end
    end
    local mine = math.max(1, player.troops)
    for _, front in ipairs(order) do
        local other = front.player
        front.troops = Threats.troops(game, player, other)
        front.estimated = not Vision.observes(game, player, other)
        front.score = front.troops / mine * hostility(game, player, other)
        front.level = Threats.level(front.score)
        local n = math.max(1, #front.tiles)
        front.x, front.y = front.sumX / n + 0.5, front.sumY / n + 0.5
    end
    table.sort(order, function(a, b) return a.score > b.score end)
    return order
end

function Threats.fronts(game, player)
    local cache = game.threatCache
    local bucket = math.floor(game.tick / Config.visionRefreshTicks)
    if not cache or cache.bucket ~= bucket or cache.player ~= player then
        cache = { bucket = bucket, player = player, fronts = Threats.compute(game, player) }
        game.threatCache = cache
    end
    return cache.fronts
end

return Threats
