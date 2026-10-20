local Bot = require("src.modules.ai.bot")
local Nation = require("src.modules.ai.nation")

local AI = {}

local function brainFor(game, player)
    if player:isBot() then
        return Bot
    elseif player:isNation() or (player:isHuman() and game.options.autoplay) then
        return Nation
    end
    return nil
end

function AI.started(game)
    local base = game:difficulty().decisionTicks
    for _, player in ipairs(game.players) do
        local brain = brainFor(game, player)
        if brain then
            player.brain = brain
            brain.setup(game, player)
            player.nextDecision = game.tick + game.rng:random(1, base * 2)
        end
    end
end

function AI.step(game)
    if game.phase ~= "playing" then return end
    local base = game:difficulty().decisionTicks
    for _, player in ipairs(game.players) do
        if player.brain and player.alive and game.tick >= player.nextDecision then
            player.nextDecision = game.tick + base + game.rng:random(0, base)
            player.brain.decide(game, player)
        end
    end
end

function AI.attackLaunched(game, attack)
    if attack.target then
        attack.target:changeRelation(attack.attacker, -20)
        attack.target.lastAttacker = attack.attacker.id
    end
end

return AI
