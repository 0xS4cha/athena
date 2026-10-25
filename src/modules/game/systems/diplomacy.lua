local Config = require("src.config.game")
local Format = require("src.core.format")
local Attack = require("src.modules.game.systems.attack")

local Diplomacy = {}

local GOOD = { 0.3, 0.85, 0.45, 1 }
local BAD = { 0.95, 0.35, 0.3, 1 }
local INFO = { 0.55, 0.75, 1, 1 }

function Diplomacy.allianceCount(player)
    local n = 0
    for _ in pairs(player.allies) do n = n + 1 end
    return n
end

function Diplomacy.form(game, a, b)
    Diplomacy.dissolvePact(game, a, b)
    local expires = game.tick + Config.allianceTicks
    a.allies[b.id] = expires
    b.allies[a.id] = expires
    a.allianceRequests[b.id] = nil
    b.allianceRequests[a.id] = nil
    a:changeRelation(b, 30)
    b:changeRelation(a, 30)
    for _, attack in ipairs(game.attacks) do
        if (attack.attacker == a and attack.target == b) or (attack.attacker == b and attack.target == a) then
            Attack.finish(game, attack)
        end
    end
    game:notify(a, "You are now allied with " .. b.name .. ".", { color = GOOD })
    game:notify(b, "You are now allied with " .. a.name .. ".", { color = GOOD })
    game:emit("allianceFormed", a, b)
end

function Diplomacy.dissolve(game, a, b)
    a.allies[b.id] = nil
    b.allies[a.id] = nil
end

function Diplomacy.betray(game, traitor, victim)
    if not traitor:isAlliedWith(victim) then return end
    Diplomacy.dissolve(game, traitor, victim)
    traitor.traitorUntil = game.tick + Config.traitorTicks
    victim:changeRelation(traitor, -80)
    for _, other in ipairs(game.players) do
        if other ~= traitor and other ~= victim and other.alive then
            other:changeRelation(traitor, -15)
        end
    end
    game:notify(victim, traitor.name .. " betrayed you and broke your alliance!", { color = BAD, duration = 300 })
    if traitor ~= game.human and victim ~= game.human and not traitor:isBot() then
        game:addEvent(traitor.name .. " betrayed " .. victim.name .. ".", { color = { 0.95, 0.6, 0.3, 1 }, minor = true })
    end
    game:notify(traitor, "You broke your alliance with " .. victim.name .. ". You are marked as a traitor.", { color = BAD })
    game:emit("allianceBroken", traitor, victim)
end

function Diplomacy.request(game, from, to)
    if from == to or not to.alive or from:isAlliedWith(to) or to:isBot() then return end
    if from.allianceRequests[to.id] then
        Diplomacy.reply(game, from, to, true)
        return
    end
    if to.allianceRequests[from.id] then return end
    to.allianceRequests[from.id] = game.tick + Config.allianceRequestTicks
    game:notify(from, "Alliance request sent to " .. to.name .. ".", { color = INFO, minor = true })
    if to == game.human then
        local event = game:addEvent(from.name .. " requests an alliance.", {
            color = INFO,
            duration = Config.allianceRequestTicks,
            actions = {
                { label = "Accept", color = { 0.15, 0.6, 0.3, 0.9 }, run = function() game:submit({ type = "allianceReply", player = to.id, from = from.id, accept = true }) end },
                { label = "Reject", color = { 0.7, 0.2, 0.2, 0.9 }, run = function() game:submit({ type = "allianceReply", player = to.id, from = from.id, accept = false }) end }
            }
        })
        to.requestEvents[from.id] = event
    end
end

function Diplomacy.reply(game, player, from, accept)
    if not player.allianceRequests[from.id] then return end
    player.allianceRequests[from.id] = nil
    local event = player.requestEvents[from.id]
    if event then
        game:removeEvent(event)
        player.requestEvents[from.id] = nil
    end
    if accept and from.alive and player.alive then
        Diplomacy.form(game, player, from)
    else
        from:changeRelation(player, -10)
        game:notify(from, player.name .. " rejected your alliance request.", { color = BAD })
    end
end

local function endHostilities(game, a, b)
    for _, attack in ipairs(game.attacks) do
        if (attack.attacker == a and attack.target == b) or (attack.attacker == b and attack.target == a) then
            Attack.finish(game, attack)
        end
    end
end

function Diplomacy.formPact(game, a, b)
    local expires = game.tick + Config.pactTicks
    a.pacts[b.id] = { expires = expires }
    b.pacts[a.id] = { expires = expires }
    a.pactRequests[b.id] = nil
    b.pactRequests[a.id] = nil
    a:changeRelation(b, 15)
    b:changeRelation(a, 15)
    endHostilities(game, a, b)
    game:notify(a, "Non-aggression pact signed with " .. b.name .. ".", { color = GOOD })
    game:notify(b, "Non-aggression pact signed with " .. a.name .. ".", { color = GOOD })
end

function Diplomacy.dissolvePact(game, a, b)
    a.pacts[b.id] = nil
    b.pacts[a.id] = nil
end

function Diplomacy.requestPact(game, from, to)
    if from == to or not to.alive or to:isBot() or from:isAlliedWith(to) or from:hasPact(to) then return end
    if from.pactRequests[to.id] then
        Diplomacy.replyPact(game, from, to, true)
        return
    end
    if to.pactRequests[from.id] then return end
    to.pactRequests[from.id] = game.tick + Config.pactRequestTicks
    game:notify(from, "Non-aggression pact proposed to " .. to.name .. ".", { color = INFO, minor = true })
    if to == game.human then
        to.pactEvents[from.id] = game:addEvent(from.name .. " proposes a non-aggression pact.", {
            color = INFO,
            duration = Config.pactRequestTicks,
            actions = {
                { label = "Accept", color = { 0.15, 0.6, 0.3, 0.9 }, run = function() game:submit({ type = "pactReply", player = to.id, from = from.id, accept = true }) end },
                { label = "Reject", color = { 0.7, 0.2, 0.2, 0.9 }, run = function() game:submit({ type = "pactReply", player = to.id, from = from.id, accept = false }) end }
            }
        })
    end
end

function Diplomacy.replyPact(game, player, from, accept)
    if not player.pactRequests[from.id] then return end
    player.pactRequests[from.id] = nil
    local event = player.pactEvents[from.id]
    if event then
        game:removeEvent(event)
        player.pactEvents[from.id] = nil
    end
    if accept and from.alive and player.alive and not player:isAlliedWith(from) then
        Diplomacy.formPact(game, player, from)
    else
        from:changeRelation(player, -5)
        game:notify(from, player.name .. " rejected your non-aggression pact.", { color = BAD })
    end
end

function Diplomacy.endPact(game, player, other)
    local pact = player.pacts[other.id]
    if not pact or pact.endsTick then return end
    local ends = game.tick + Config.pactNoticeTicks
    pact.endsTick = ends
    other.pacts[player.id].endsTick = ends
    other:changeRelation(player, -15)
    local seconds = math.floor(Config.pactNoticeTicks / Config.tickRate)
    game:notify(other, string.format("%s will end your non-aggression pact in %ds.", player.name, seconds), { color = BAD, duration = Config.pactNoticeTicks })
    game:notify(player, string.format("Your pact with %s ends in %ds.", other.name, seconds), { color = INFO, minor = true })
end

function Diplomacy.breakPact(game, traitor, victim)
    if not traitor:hasPact(victim) then return end
    Diplomacy.dissolvePact(game, traitor, victim)
    traitor.traitorUntil = game.tick + Config.traitorTicks
    victim:changeRelation(traitor, -60)
    game:notify(victim, traitor.name .. " violated your non-aggression pact!", { color = BAD, duration = 300 })
    game:notify(traitor, "You violated your pact with " .. victim.name .. ". You are marked as a traitor.", { color = BAD })
end

function Diplomacy.donate(game, from, to, kind, ratio)
    if not from:isAlliedWith(to) or not to.alive then return end
    if kind == "troops" then
        local amount = math.floor(from.troops * ratio)
        if amount < 1 then return end
        from.troops = from.troops - amount
        to.troops = to.troops + amount
        game:notify(to, string.format("%s sent you %s troops.", from.name, Format.number(amount)), { color = GOOD })
        game:notify(from, string.format("You sent %s troops to %s.", Format.number(amount), to.name), { color = INFO, minor = true })
    else
        local amount = math.floor(from.gold * ratio)
        if amount < 1 then return end
        from.gold = from.gold - amount
        to.gold = to.gold + amount
        game:notify(to, string.format("%s sent you %s gold.", from.name, Format.number(amount)), { color = GOOD })
        game:notify(from, string.format("You sent %s gold to %s.", Format.number(amount), to.name), { color = INFO, minor = true })
    end
    to:changeRelation(from, 20)
end

function Diplomacy.step(game)
    if game.phase ~= "playing" or game.tick % 10 ~= 0 then return end
    local tick = game.tick
    for _, player in ipairs(game.players) do
        for id, expires in pairs(player.allies) do
            local other = game.players[id]
            if expires <= tick and player.coalition and player.coalition == other.coalition then
                player.allies[id] = tick + Config.allianceTicks
            elseif expires <= tick then
                Diplomacy.dissolve(game, player, other)
                game:notify(player, "Your alliance with " .. other.name .. " has expired.", { color = INFO })
                game:notify(other, "Your alliance with " .. player.name .. " has expired.", { color = INFO })
            end
        end
        for id, expires in pairs(player.allianceRequests) do
            if expires <= tick then
                player.allianceRequests[id] = nil
                player.requestEvents[id] = nil
            end
        end
        for id, pact in pairs(player.pacts) do
            local other = game.players[id]
            if (pact.endsTick or pact.expires) <= tick and other.id > player.id then
                Diplomacy.dissolvePact(game, player, other)
                local text = pact.endsTick and "Your non-aggression pact with %s has ended." or "Your non-aggression pact with %s has expired."
                game:notify(player, string.format(text, other.name), { color = INFO })
                game:notify(other, string.format(text, player.name), { color = INFO })
            end
        end
        for id, expires in pairs(player.pactRequests) do
            if expires <= tick then
                player.pactRequests[id] = nil
                player.pactEvents[id] = nil
            end
        end
        if player.emoji and player.emoji.untilTick <= tick then
            player.emoji = nil
        end
        if tick % 100 == 0 then
            for id, value in pairs(player.relations) do
                player.relations[id] = value * 0.97
            end
        end
    end
end

function Diplomacy.nukeLaunched(game, nuke, player, target)
    if player:isAlliedWith(target) then
        Diplomacy.betray(game, player, target)
    elseif player:hasPact(target) then
        Diplomacy.breakPact(game, player, target)
    end
end

function Diplomacy.eliminated(game, player)
    for id in pairs(player.allies) do
        local other = game.players[id]
        if other then other.allies[player.id] = nil end
    end
    player.allies = {}
    player.allianceRequests = {}
    for id in pairs(player.pacts) do
        local other = game.players[id]
        if other then other.pacts[player.id] = nil end
    end
    player.pacts = {}
    player.pactRequests = {}
end

local function pair(game, intent)
    return game.players[intent.player], game.players[intent.target]
end

Diplomacy.intents = {
    allianceRequest = function(game, intent)
        local a, b = pair(game, intent)
        if a and b and a.alive then Diplomacy.request(game, a, b) end
    end,
    allianceReply = function(game, intent)
        local player, from = game.players[intent.player], game.players[intent.from]
        if player and from then Diplomacy.reply(game, player, from, intent.accept) end
    end,
    pactRequest = function(game, intent)
        local a, b = pair(game, intent)
        if a and b and a.alive then Diplomacy.requestPact(game, a, b) end
    end,
    pactReply = function(game, intent)
        local player, from = game.players[intent.player], game.players[intent.from]
        if player and from then Diplomacy.replyPact(game, player, from, intent.accept) end
    end,
    pactEnd = function(game, intent)
        local a, b = pair(game, intent)
        if a and b then Diplomacy.endPact(game, a, b) end
    end,
    allianceBreak = function(game, intent)
        local a, b = pair(game, intent)
        if a and b then Diplomacy.betray(game, a, b) end
    end,
    embargo = function(game, intent)
        local a, b = pair(game, intent)
        if not a or not b then return end
        a.embargo[b.id] = intent.enabled or nil
        if intent.enabled then
            b:changeRelation(a, -15)
            game:notify(b, a.name .. " placed an embargo on you.", { color = BAD })
        end
    end,
    donate = function(game, intent)
        local a, b = pair(game, intent)
        if a and b then Diplomacy.donate(game, a, b, intent.kind, intent.ratio or a.attackRatio) end
    end,
    setTarget = function(game, intent)
        local player = game.players[intent.player]
        if not player then return end
        local target = intent.target and game.players[intent.target] or nil
        player.target = target and target.id or nil
        if target then
            for id in pairs(player.allies) do
                game:notify(game.players[id], player.name .. " asks you to attack " .. target.name .. ".", { color = { 1, 0.75, 0.3, 1 } })
            end
            target:changeRelation(player, -10)
        end
    end,
    emoji = function(game, intent)
        local a, b = pair(game, intent)
        if not a or not b or not b.alive then return end
        b.emoji = { icon = intent.icon, from = a.id, untilTick = game.tick + Config.emojiTicks }
        if b == game.human then
            game:addEvent(a.name .. " sent you an emoji.", { color = INFO, duration = Config.emojiTicks, minor = true })
        end
    end
}

return Diplomacy
