local Config = require("src.config.game")
local Diplomacy = require("src.modules.game.systems.diplomacy")
local Personality = require("src.modules.ai.personality")
local Negotiator = require("src.modules.ai.negotiator")

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
                and game.aiRng:random() < math.min(0.95, 0.75 * Personality.of(player).diplomacy)
            game:command({ type = "allianceReply", player = player.id, from = from.id, accept = accept })
            return true
        end
    end
    return false
end

local function seekAlliance(game, player, ctx)
    if Diplomacy.allianceCount(player) >= Config.maxAllies or game.aiRng:random() > 0.12 * Personality.of(player).diplomacy then return false end
    for _, other in ipairs(ctx.neighbors) do
        if not other:isBot() and not player:isAlliedWith(other) and not other.allianceRequests[player.id]
            and player:relation(other) >= 0 and (player:relation(other) > 20 or other.troops > player.troops * 0.8)
            and other.traitorUntil <= game.tick then
            game:command({ type = "allianceRequest", player = player.id, target = other.id })
            return true
        end
    end
    return false
end

local function maybeBetray(game, player, ctx)
    local loyalty = Personality.of(player).loyalty
    if ctx.neutral or game.aiRng:random() > 0.04 * (2 - loyalty) * (2 - loyalty) then return false end
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
    game:command({ type = "allianceBreak", player = player.id, target = weakestAlly.id })
    return true
end

local function supportAllies(game, player)
    if player:population() < player.maxPopulation * 0.75 or game.aiRng:random() > 0.1 * Personality.of(player).loyalty then return false end
    for id in pairs(player.allies) do
        local ally = game.players[id]
        if ally and ally.alive and ally.lastAttacker and ally.troops < player.troops * 0.5 then
            game:command({ type = "donate", player = player.id, target = ally.id, kind = "troops", ratio = 0.1 })
            return true
        end
    end
    return false
end

local function react(game, player)
    local attacker = player.lastAttacker and game.players[player.lastAttacker]
    if attacker and attacker:isHuman() and game.aiRng:random() < 0.15 then
        game:command({ type = "emoji", player = player.id, target = attacker.id, icon = "Skull.png" })
    end
    player.lastAttacker = nil
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and player:relation(other) < -60 and not player.embargo[other.id] and game.aiRng:random() < 0.2 then
            game:command({ type = "embargo", player = player.id, target = other.id, enabled = true })
            break
        end
    end
end

function Diplomat.behavior(game, player, ctx)
    react(game, player)
    if considerRequests(game, player) then return false end
    if Negotiator.considerPacts(game, player) then return false end
    if Negotiator.considerLoans(game, player) then return false end
    if Negotiator.manageDebt(game, player) then return false end
    if maybeBetray(game, player, ctx) then return true end
    if Negotiator.maybeEndPact(game, player, ctx) then return false end
    if supportAllies(game, player) then return false end
    if seekAlliance(game, player, ctx) then return false end
    if Negotiator.seekLoan(game, player, ctx) then return false end
    Negotiator.seekPact(game, player, ctx)
    return false
end

return Diplomat
