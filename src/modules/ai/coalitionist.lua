local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Coalitions = require("src.modules.game.systems.coalitions")
local Personality = require("src.modules.ai.personality")

local Coalitionist = {}

local function dominant(game, player)
    local best
    for _, other in ipairs(game.players) do
        if other ~= player and not player:isAlliedWith(other) and Coalitions.canTarget(game, other)
            and (not best or other.tiles > best.tiles) then
            best = other
        end
    end
    return best
end

local function wantsWar(game, player, target)
    local traits = Personality.of(player)
    local relation = player:relation(target)
    if relation >= 20 or player:isAlliedWith(target) then return false end
    return relation < -20
        or Coalitions.share(game, target) >= 0.2
        or target.troops > player.troops * 1.5
        or (traits.opportunism > 1 and #Attack.incoming(game, target) > 0)
end

local function threatened(game, player)
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and not other:isBot() and player:canAttack(other)
            and other.troops > player.troops * 1.5 and Attack.sharesBorder(game, player, other.id) then
            return other
        end
    end
    return nil
end

function Coalitionist.considerInvites(game, player)
    for id in pairs(player.coalitionInvites) do
        local coalition = Coalitions.get(game, id)
        if coalition then
            local traits = Personality.of(player)
            local accept
            if coalition.target then
                accept = wantsWar(game, player, coalition.target)
            else
                local relation = player:relation(coalition.leader)
                accept = relation >= -10 and (threatened(game, player) ~= nil or relation > 20)
            end
            accept = accept and Coalitions.canJoin(game, coalition, player) and game.aiRng:random() < math.min(0.95, 0.7 * traits.diplomacy)
            game:command({ type = "coalitionReply", player = player.id, coalition = coalition.id, accept = accept == true })
            return true
        end
    end
    return false
end

local function candidateScore(game, player, coalition, other)
    if other == player or other:isBot() or not Coalitions.canJoin(game, coalition, other) or other.coalitionInvites[coalition.id] then
        return nil
    end
    local score = player:relation(other)
    local target = coalition.target
    if target then
        score = score - other:relation(target)
        if Attack.sharesBorder(game, other, target.id) then score = score + 30 end
    elseif player:isAlliedWith(other) then
        score = score + 30
    end
    if score < 0 then return nil end
    return score
end

function Coalitionist.lead(game, player)
    local coalition = Coalitions.of(game, player)
    if not coalition or coalition.leader ~= player or #coalition.members >= Config.coalitionMaxMembers then return false end
    if game.aiRng:random() > 0.4 then return false end
    local best, bestScore
    for _, other in ipairs(game.players) do
        if other.alive then
            local score = candidateScore(game, player, coalition, other)
            if score and (not bestScore or score > bestScore) then
                best, bestScore = other, score
            end
        end
    end
    if not best then return false end
    game:command({ type = "coalitionInvite", player = player.id, target = best.id })
    return true
end

function Coalitionist.found(game, player)
    if player.coalition then return false end
    local traits = Personality.of(player)
    if game.aiRng:random() > 0.04 * traits.diplomacy then return false end
    local target = dominant(game, player)
    if target and #Coalitions.against(game, target) == 0 and wantsWar(game, player, target) then
        game:command({ type = "coalitionFound", player = player.id, kind = "war", target = target.id })
        return true
    end
    local threat = traits.caution >= 1 and threatened(game, player)
    if not threat then return false end
    for _, other in ipairs(game.players) do
        if other ~= player and other ~= threat and other.alive and not other:isBot() and not other.coalition
            and player:relation(other) >= 0 and not other:isAlliedWith(threat) and Attack.sharesBorder(game, other, threat.id) then
            game:command({ type = "coalitionFound", player = player.id, kind = "defense", target = other.id })
            return true
        end
    end
    return false
end

function Coalitionist.maybeLeave(game, player)
    local coalition = Coalitions.of(game, player)
    if not coalition or coalition.kind ~= "defense" or coalition.leader == player then return false end
    if player:relation(coalition.leader) > -40 or game.aiRng:random() > 0.2 then return false end
    game:command({ type = "coalitionLeave", player = player.id })
    return true
end

function Coalitionist.isTarget(game, player, other)
    local coalition = Coalitions.of(game, player)
    return coalition ~= nil and coalition.target == other and #coalition.members >= 2
end

return Coalitionist
