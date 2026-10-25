local Config = require("src.config.game")
local Ships = require("src.modules.game.systems.ships")
local Personality = require("src.modules.ai.personality")

local function sq(v) return v * v end

local Navy = {}

local function randomNeutralLand(game, player)
    local map = game.map
    local rng = game.aiRng
    local cx, cy = player:center()
    local radius = 150 + math.sqrt(player.tiles)
    for _ = 1, 40 do
        local x = math.floor(cx + (rng:random() * 2 - 1) * radius)
        local y = math.floor(cy + (rng:random() * 2 - 1) * radius)
        if map:isValid(x, y) then
            local i = map:index(x, y)
            if map:isLand(i) and map.owner[i] == 0 then
                return i
            end
        end
    end
    return nil
end

local function enemyTarget(game, player)
    local cx, cy = player:center()
    local best, bestScore
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and other.tiles > 0 and player:canAttack(other) then
            local ox, oy = other:center()
            local d = math.sqrt(sq(ox - cx) + sq(oy - cy))
            local score = d * (other.troops / math.max(1, player.troops) + 0.3) * (other:isBot() and 0.6 or 1) * (0.7 + game.aiRng:random() * 0.6)
            if not bestScore or score < bestScore then
                best, bestScore = other, score
            end
        end
    end
    if not best then return nil end
    local ox, oy = best:center()
    return game.map:findNear(ox, oy, 40, function(i) return game.map.owner[i] == best.id end)
end

function Navy.behavior(game, player, ctx)
    local traits = Personality.of(player)
    if player:unitCount("transport") > 0 or game.aiRng:random() > 0.35 * traits.aggression then return false end
    if player.troops < player.maxPopulation * 0.35 * traits.caution then return false end
    local hasTarget = ctx.neutral
    for _, other in ipairs(ctx.neighbors) do
        if player:canAttack(other) then hasTarget = true end
    end
    if hasTarget and game.aiRng:random() > 0.1 then return false end
    local tile = randomNeutralLand(game, player) or enemyTarget(game, player)
    if not tile or not Ships.canSendBoat(game, player, tile) then return false end
    game:command({ type = "boat", player = player.id, tile = tile, ratio = 0.3 })
    return true
end

return Navy
