local Attack = require("src.modules.game.systems.attack")
local Builder = require("src.modules.ai.builder")
local Navy = require("src.modules.ai.navy")
local Strategist = require("src.modules.ai.strategist")
local Diplomat = require("src.modules.ai.diplomat")
local Personality = require("src.modules.ai.personality")
local Negotiator = require("src.modules.ai.negotiator")

local Nation = {}

Nation.behaviors = { Diplomat.behavior, Strategist.behavior, Builder.behavior, Navy.behavior }

function Nation.setup(game, player)
    local traits = Personality.of(player)
    local ratio = 0.55 + game.aiRng:random() * 0.15 + (traits.aggression - 1) * 0.1
    game:command({ type = "troopRatio", player = player.id, ratio = math.max(0.4, math.min(0.8, ratio)) })
end

function Nation.targetScore(game, player, other)
    local traits = Personality.of(player)
    local score = player.troops / math.max(1, other.troops)
    if other:isBot() then
        score = score * 1.6
    end
    if other.traitorUntil > game.tick then
        score = score * 1.4
    end
    if #Attack.incoming(game, other) > 0 then
        score = score * traits.opportunism
    end
    if Negotiator.plannedTarget(game, player) == other.id then
        score = score * 1.6
    end
    local relation = player:relation(other)
    if relation < 0 then
        score = score * (1 - relation / 100)
    else
        score = score * (1 - relation / 250)
    end
    for allyId in pairs(player.allies) do
        local ally = game.players[allyId]
        if ally and ally.target == other.id then
            score = score * 1.5
        end
    end
    return score
end

function Nation.chooseTarget(game, player, neighbors)
    local best, bestScore
    for _, other in ipairs(neighbors) do
        if player:canAttack(other) then
            local score = Nation.targetScore(game, player, other)
            if not bestScore or score > bestScore then
                best, bestScore = other, score
            end
        end
    end
    return best, bestScore
end

function Nation.expandOrAttack(game, player, ctx)
    local rng = game.aiRng
    local traits = Personality.of(player)
    if player.troops < player.maxPopulation * 0.2 * traits.caution then return end
    if ctx.neutral then
        game:command({ type = "attack", player = player.id, target = 0, ratio = 0.25 + rng:random() * 0.2 })
        return true
    end
    local target, score = Nation.chooseTarget(game, player, ctx.neighbors)
    local saturated = player:population() > player.maxPopulation * 0.9
    local ready = player.troops > player.maxPopulation * math.min(0.7, 0.45 * traits.caution)
    if target and ((score > 1.1 / traits.aggression and ready) or (saturated and score > 0.4 / traits.aggression)) then
        local ratio = (0.3 + rng:random() * 0.2) * math.min(1.3, traits.aggression)
        game:command({ type = "attack", player = player.id, target = target.id, ratio = ratio })
        return true
    end
end

function Nation.decide(game, player)
    local neighbors, neutral = Attack.neighbors(game, player)
    local isolated = not neutral
    for _, other in ipairs(neighbors) do
        if player:canAttack(other) then isolated = false end
    end
    local ctx = { neighbors = neighbors, neutral = neutral, isolated = isolated }
    for _, behavior in ipairs(Nation.behaviors) do
        if behavior(game, player, ctx) then
            return
        end
    end
    Nation.expandOrAttack(game, player, ctx)
end

return Nation
