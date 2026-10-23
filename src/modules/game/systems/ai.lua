local Bot = require("src.modules.ai.bot")
local Nation = require("src.modules.ai.nation")

local AI = {}

local function brainFor(game, player)
    if player:isBot() then
        return Bot
    elseif player:isNation() or (player:isHuman() and (game.options.autoplay or player.disconnected)) then
        return Nation
    end
    return nil
end

local function assign(game, player)
    local brain = brainFor(game, player)
    if brain then
        player.brain = brain
        brain.setup(game, player)
        player.nextDecision = game.tick + game.aiRng:random(1, game:difficulty().decisionTicks * 2)
    end
end

function AI.started(game)
    if not game.authority then return end
    for _, player in ipairs(game.players) do
        assign(game, player)
    end
end

function AI.step(game)
    if game.phase ~= "playing" or not game.authority then return end
    local base = game:difficulty().decisionTicks
    for _, player in ipairs(game.players) do
        if player.brain and player.alive and game.tick >= player.nextDecision then
            player.nextDecision = game.tick + base + game.aiRng:random(0, base)
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

AI.intents = {
    disconnect = function(game, intent)
        local player = game.players[intent.player]
        if not player or not player:isHuman() or player.disconnected then return end
        player.disconnected = true
        if player.alive then
            game:addEvent(player.name .. " left the game. The AI takes over.", { color = { 0.95, 0.6, 0.3, 1 } })
        end
        if game.authority and game.phase ~= "spawn" and not player.brain then
            assign(game, player)
        end
    end,
    reconnect = function(game, intent)
        local player = game.players[intent.player]
        if not player or not player.disconnected then return end
        player.disconnected = false
        player.brain = nil
        if player.alive then
            game:addEvent(player.name .. " is back in command.", { color = { 0.3, 0.85, 0.45, 1 } })
        end
    end
}

return AI
