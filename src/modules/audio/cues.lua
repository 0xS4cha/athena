local Vision = require("src.modules.game.systems.vision")
local Victory = require("src.modules.game.systems.victory")

local Cues = {}

local DISTANT_BLAST = 0.45

local RULES = {
    started = function() return "start" end,
    attackLaunched = function(game, attack)
        if attack.attacker == game.human then return "attack" end
        if attack.target == game.human then return "underAttack" end
    end,
    nukeFired = function(game, _, player)
        if player == game.human then return "nukeLaunch" end
    end,
    nukeDetected = function() return "nukeAlarm" end,
    nukeDetonated = function(game, attacker, cx, cy)
        local human = game.human
        if attacker == human then return "nukeBlast" end
        if not human.alive then return "nukeBlast", DISTANT_BLAST end
        if Vision.passive(game, human, cx, cy) then return "nukeBlast" end
    end,
    nukeIntercepted = function(game, nuke, sam)
        if nuke.owner == game.human or sam.owner == game.human then return "intercept" end
    end,
    eliminated = function(game, player, by)
        if player == game.human then return "defeat" end
        if by == game.human then return "conquest" end
    end,
    gameEnded = function(game)
        return Victory.won(game, game.human) and "victory" or "defeat"
    end,
    unitCompleted = function(game, unit)
        if unit.owner == game.human and unit.kind ~= "nuke" then return "build" end
    end,
    unitRemoved = function(game, unit)
        if unit.kind == "capital" and unit.owner == game.human and game.human.alive then return "capitalLost" end
    end,
    allianceFormed = function(game, a, b)
        if a == game.human or b == game.human then return "alliance" end
    end,
    allianceBroken = function(game, _, victim)
        if victim == game.human then return "betrayal" end
    end,
    coalitionFounded = function(game, coalition)
        for _, member in ipairs(coalition.members) do
            if member == game.human then return "alliance" end
        end
    end,
    tradeCompleted = function(game, unit, port)
        if unit.owner == game.human or port.owner == game.human then return "coin" end
    end,
    blockadeStarted = function(game, unit, ship)
        if unit.owner == game.human or ship.owner == game.human then return "blockade" end
    end,
    requestReceived = function() return "request" end,
    refused = function() return "refused" end
}

function Cues.resolve(game, name, ...)
    local rule = RULES[name]
    if not rule or not game.human then return nil end
    return rule(game, ...)
end

return Cues
