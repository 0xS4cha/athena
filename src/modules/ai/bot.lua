local Attack = require("src.modules.game.systems.attack")

local Bot = {}

function Bot.setup(game, player)
    game:command({ type = "troopRatio", player = player.id, ratio = 0.75 })
end

function Bot.decide(game, player)
    local rng = game.aiRng
    if player.troops < player.maxPopulation * 0.25 then return end
    local neighbors, neutral = Attack.neighbors(game, player)
    if neutral and rng:random() < 0.85 then
        game:command({ type = "attack", player = player.id, target = 0, ratio = 0.3 + rng:random() * 0.2 })
        return
    end
    if rng:random() > 0.4 then return end
    local weakest
    for _, other in ipairs(neighbors) do
        if not player:isAlliedWith(other) and (not weakest or other.troops < weakest.troops) then
            weakest = other
        end
    end
    local saturated = player:population() > player.maxPopulation * 0.9
    if weakest and (weakest.troops < player.troops * 1.2 or saturated) then
        game:command({ type = "attack", player = player.id, target = weakest.id, ratio = 0.4 })
    end
end

return Bot
