local Attack = require("src.modules.game.systems.attack")
local Builder = require("src.modules.ai.builder")

local Nation = {}

Nation.behaviors = { Builder.behavior }

function Nation.setup(game, player)
    player.troopRatio = 0.55 + game.rng:random() * 0.15
end

function Nation.targetScore(game, player, other)
    local score = player.troops / math.max(1, other.troops)
    if other:isBot() then
        score = score * 1.6
    end
    if other.traitorUntil > game.tick then
        score = score * 1.4
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
        if not player:isAlliedWith(other) then
            local score = Nation.targetScore(game, player, other)
            if not bestScore or score > bestScore then
                best, bestScore = other, score
            end
        end
    end
    return best, bestScore
end

function Nation.expandOrAttack(game, player, ctx)
    local rng = game.rng
    if player.troops < player.maxPopulation * 0.2 then return end
    if ctx.neutral then
        game:pushIntent({ type = "attack", player = player.id, target = 0, ratio = 0.25 + rng:random() * 0.2 })
        return true
    end
    local target, score = Nation.chooseTarget(game, player, ctx.neighbors)
    local saturated = player:population() > player.maxPopulation * 0.9
    if target and ((score > 1.1 and player.troops > player.maxPopulation * 0.45) or (saturated and score > 0.4)) then
        game:pushIntent({ type = "attack", player = player.id, target = target.id, ratio = 0.3 + rng:random() * 0.2 })
        return true
    end
end

function Nation.decide(game, player)
    local neighbors, neutral = Attack.neighbors(game, player)
    local ctx = { neighbors = neighbors, neutral = neutral }
    for _, behavior in ipairs(Nation.behaviors) do
        if behavior(game, player, ctx) then
            return
        end
    end
    Nation.expandOrAttack(game, player, ctx)
end

return Nation
