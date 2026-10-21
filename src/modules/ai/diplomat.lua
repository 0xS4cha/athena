local Config = require("src.config.game")
local Diplomacy = require("src.modules.game.systems.diplomacy")

local Diplomat = {}

local function considerRequests(game, player)
    for id in pairs(player.allianceRequests) do
        local from = game.players[id]
        if from and from.alive then
            local relation = player:relation(from)
            local strong = from.troops > player.troops * 0.5
            local accept = relation >= -10
                and from.traitorUntil <= game.tick
                and Diplomacy.allianceCount(player) < Config.maxAllies
                and (strong or relation > 25)
                and game.rng:random() < 0.75
            game:pushIntent({ type = "allianceReply", player = player.id, from = from.id, accept = accept })
            return true
        end
    end
    return false
end

local function considerPacts(game, player)
    for id in pairs(player.pactRequests) do
        local from = game.players[id]
        if from and from.alive then
            local relation = player:relation(from)
            local accept = relation >= -30
                and from.traitorUntil <= game.tick
                and (from.troops > player.troops * 0.6 or relation > 10)
                and game.rng:random() < 0.8
            game:pushIntent({ type = "pactReply", player = player.id, from = from.id, accept = accept })
            return true
        end
    end
    return false
end

local function seekPact(game, player, ctx)
    if game.rng:random() > 0.1 then return false end
    for _, other in ipairs(ctx.neighbors) do
        if not other:isBot() and player:canAttack(other) and not other.pactRequests[player.id]
            and other.troops > player.troops * 0.9 and player:relation(other) >= -20
            and other.traitorUntil <= game.tick then
            game:pushIntent({ type = "pactRequest", player = player.id, target = other.id })
            return true
        end
    end
    return false
end

local function maybeEndPact(game, player, ctx)
    if game.rng:random() > 0.03 then return false end
    for _, other in ipairs(ctx.neighbors) do
        local pact = player.pacts[other.id]
        if pact and not pact.endsTick and other.troops < player.troops * 0.4 then
            game:pushIntent({ type = "pactEnd", player = player.id, target = other.id })
            return true
        end
    end
    return false
end

local function seekAlliance(game, player, ctx)
    if Diplomacy.allianceCount(player) >= Config.maxAllies or game.rng:random() > 0.12 then return false end
    for _, other in ipairs(ctx.neighbors) do
        if not other:isBot() and not player:isAlliedWith(other) and not other.allianceRequests[player.id]
            and player:relation(other) >= 0 and (player:relation(other) > 20 or other.troops > player.troops * 0.8)
            and other.traitorUntil <= game.tick then
            game:pushIntent({ type = "allianceRequest", player = player.id, target = other.id })
            return true
        end
    end
    return false
end

local function maybeBetray(game, player, ctx)
    if ctx.neutral or game.rng:random() > 0.04 then return false end
    local hostile = false
    local weakestAlly
    for _, other in ipairs(ctx.neighbors) do
        if player:isAlliedWith(other) then
            if other.troops < player.troops * 0.4 and (not weakestAlly or other.troops < weakestAlly.troops) then
                weakestAlly = other
            end
        else
            hostile = true
        end
    end
    if hostile or not weakestAlly then return false end
    game:pushIntent({ type = "allianceBreak", player = player.id, target = weakestAlly.id })
    return true
end

local function supportAllies(game, player)
    if player:population() < player.maxPopulation * 0.75 or game.rng:random() > 0.1 then return false end
    for id in pairs(player.allies) do
        local ally = game.players[id]
        if ally and ally.alive and ally.lastAttacker and ally.troops < player.troops * 0.5 then
            game:pushIntent({ type = "donate", player = player.id, target = ally.id, kind = "troops", ratio = 0.1 })
            return true
        end
    end
    return false
end

local function react(game, player)
    local attacker = player.lastAttacker and game.players[player.lastAttacker]
    if attacker and attacker == game.human and game.rng:random() < 0.15 then
        game:pushIntent({ type = "emoji", player = player.id, target = attacker.id, icon = "Skull.png" })
    end
    player.lastAttacker = nil
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and player:relation(other) < -60 and not player.embargo[other.id] and game.rng:random() < 0.2 then
            game:pushIntent({ type = "embargo", player = player.id, target = other.id, enabled = true })
            break
        end
    end
end

function Diplomat.behavior(game, player, ctx)
    react(game, player)
    if considerRequests(game, player) then return false end
    if considerPacts(game, player) then return false end
    if maybeBetray(game, player, ctx) then return true end
    if maybeEndPact(game, player, ctx) then return false end
    if supportAllies(game, player) then return false end
    if seekAlliance(game, player, ctx) then return false end
    seekPact(game, player, ctx)
    return false
end

return Diplomat
