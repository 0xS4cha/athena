local Config = require("src.config.game")
local Hash = require("src.core.hash")
local Diplomacy = require("src.modules.game.systems.diplomacy")
local Palette = require("src.modules.player.palette")

local Coalitions = {}

local GOOD = { 0.3, 0.85, 0.45, 1 }
local BAD = { 0.95, 0.35, 0.3, 1 }
local INFO = { 0.55, 0.75, 1, 1 }
local NEWS = { 1, 0.75, 0.3, 1 }

local PREFIXES = { "Northern", "Iron", "Silver", "Grand", "Free", "Eternal", "Crimson", "Azure", "Golden", "Last", "United", "Sacred" }
local SUFFIXES = { "League", "Entente", "Concord", "Covenant", "Accord", "Union", "Compact", "Front" }

function Coalitions.init(game)
    game.coalitions = {}
    game.coalitionSerial = 0
    game.coalitionModifier = Coalitions.attackModifier
end

function Coalitions.get(game, id)
    if not id then return nil end
    for _, coalition in ipairs(game.coalitions) do
        if coalition.id == id then return coalition end
    end
    return nil
end

function Coalitions.of(game, player)
    return Coalitions.get(game, player.coalition)
end

function Coalitions.color(coalition)
    return Palette.color(coalition.id * 7 + 3)
end

function Coalitions.against(game, target)
    local list = {}
    for _, coalition in ipairs(game.coalitions) do
        if coalition.target == target then
            list[#list + 1] = coalition
        end
    end
    return list
end

function Coalitions.share(game, player)
    return player.tiles / math.max(1, game.map.landCount)
end

function Coalitions.isLeader(game, player)
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and other.tiles > player.tiles then return false end
    end
    return true
end

function Coalitions.canTarget(game, target)
    if not target or not target.alive or target:isBot() then return false, "Unavailable" end
    if Coalitions.share(game, target) < Config.coalitionMinShare and not Coalitions.isLeader(game, target) then
        return false, "Not dominant"
    end
    return true
end

function Coalitions.canFound(game, founder, kind, other)
    if game.phase ~= "playing" or not founder.alive then return false, "Not now" end
    if founder.coalition then return false, "Already in a coalition" end
    if not other or other == founder or not other.alive or other:isBot() then return false, "Unavailable" end
    if kind == "war" then
        if founder:isAlliedWith(other) then return false, "Allied" end
        return Coalitions.canTarget(game, other)
    end
    if other.coalition then return false, "Already in a coalition" end
    return true
end

function Coalitions.canJoin(game, coalition, player)
    if not player.alive or player:isBot() then return false, "Unavailable" end
    if player.coalition then return false, "Already in a coalition" end
    if #coalition.members >= Config.coalitionMaxMembers then return false, "Coalition full" end
    if coalition.target and (coalition.target == player or player:isAlliedWith(coalition.target)) then
        return false, "Allied with the target"
    end
    return true
end

function Coalitions.canInvite(game, inviter, invitee)
    local coalition = Coalitions.of(game, inviter)
    if not coalition then return false, "No coalition" end
    if coalition.leader ~= inviter then return false, "Only the leader invites" end
    if invitee.coalitionInvites[coalition.id] then return false, "Pending" end
    return Coalitions.canJoin(game, coalition, invitee)
end

local function taken(game, text)
    for _, coalition in ipairs(game.coalitions) do
        if coalition.name == text then return true end
    end
    return false
end

local function name(game, id)
    local h = Hash.combine(Hash.combine(math.floor(game.seed) % 4294967296, id), 0xc0a1)
    local text
    for salt = 0, #PREFIXES * #SUFFIXES do
        local k = h + salt
        text = "The " .. PREFIXES[k % #PREFIXES + 1] .. " " .. SUFFIXES[math.floor(k / #PREFIXES) % #SUFFIXES + 1]
        if not taken(game, text) then break end
    end
    return text
end

local function tell(game, coalition, text, color, except)
    for _, member in ipairs(coalition.members) do
        if member ~= except then
            game:notify(member, text, { color = color })
        end
    end
end

local function bind(game, player, coalition)
    for _, member in ipairs(coalition.members) do
        if member ~= player then
            if player:isAlliedWith(member) then
                player.allies[member.id] = game.tick + Config.allianceTicks
                member.allies[player.id] = game.tick + Config.allianceTicks
            else
                Diplomacy.form(game, player, member)
            end
        end
    end
    local target = coalition.target
    if target and player:hasPact(target) then
        Diplomacy.endPact(game, player, target)
    end
end

local function release(game, player, coalition)
    for _, member in ipairs(coalition.members) do
        if member ~= player and player:isAlliedWith(member) then
            player.allies[member.id] = game.tick + Config.allianceTicks
            member.allies[player.id] = game.tick + Config.allianceTicks
        end
    end
end

function Coalitions.found(game, founder, kind, other)
    if not Coalitions.canFound(game, founder, kind, other) then return nil end
    game.coalitionSerial = game.coalitionSerial + 1
    local coalition = {
        id = game.coalitionSerial,
        name = name(game, game.coalitionSerial),
        kind = kind,
        leader = founder,
        members = { founder },
        target = kind == "war" and other or nil,
        founded = game.tick
    }
    game.coalitions[#game.coalitions + 1] = coalition
    founder.coalition = coalition.id
    founder.coalitionInvites = {}
    if kind == "war" then
        if founder:hasPact(other) then
            Diplomacy.endPact(game, founder, other)
        end
        other:changeRelation(founder, -20)
        game:notify(founder, string.format("You founded %s against %s.", coalition.name, other.name), { color = GOOD })
        game:notify(other, string.format("%s founded %s against you!", founder.name, coalition.name), { color = BAD, duration = 300 })
        if founder ~= game.human and other ~= game.human then
            game:addEvent(string.format("%s founded %s against %s.", founder.name, coalition.name, other.name), { color = NEWS })
        end
    else
        game:notify(founder, string.format("You founded %s, a defensive coalition.", coalition.name), { color = GOOD })
        Coalitions.invite(game, founder, other)
    end
    game:emit("coalitionFounded", coalition)
    return coalition
end

function Coalitions.invite(game, inviter, invitee)
    if not Coalitions.canInvite(game, inviter, invitee) then return end
    local coalition = Coalitions.of(game, inviter)
    invitee.coalitionInvites[coalition.id] = game.tick + Config.coalitionInviteTicks
    game:notify(inviter, string.format("%s invited to %s.", invitee.name, coalition.name), { color = INFO, minor = true })
    if invitee == game.human then
        local goal = coalition.target and ("against " .. coalition.target.name) or "for mutual defense"
        invitee.coalitionEvents[coalition.id] = game:addEvent(string.format("%s invites you to %s, %s.", inviter.name, coalition.name, goal), {
            color = NEWS,
            duration = Config.coalitionInviteTicks,
            actions = {
                { label = "Join", color = { 0.15, 0.6, 0.3, 0.9 }, run = function() game:submit({ type = "coalitionReply", player = invitee.id, coalition = coalition.id, accept = true }) end },
                { label = "Decline", color = { 0.7, 0.2, 0.2, 0.9 }, run = function() game:submit({ type = "coalitionReply", player = invitee.id, coalition = coalition.id, accept = false }) end }
            }
        })
    end
end

local function clearInvite(game, player, id)
    player.coalitionInvites[id] = nil
    local event = player.coalitionEvents[id]
    if event then
        game:removeEvent(event)
        player.coalitionEvents[id] = nil
    end
end

function Coalitions.join(game, player, coalition)
    if not Coalitions.canJoin(game, coalition, player) then return false end
    for id in pairs(player.coalitionInvites) do
        clearInvite(game, player, id)
    end
    bind(game, player, coalition)
    coalition.members[#coalition.members + 1] = player
    player.coalition = coalition.id
    tell(game, coalition, string.format("%s joined %s.", player.name, coalition.name), GOOD, player)
    game:notify(player, string.format("You joined %s.", coalition.name), { color = GOOD })
    if coalition.target then
        coalition.target:changeRelation(player, -20)
        game:notify(coalition.target, string.format("%s joined %s against you.", player.name, coalition.name), { color = BAD })
    end
    return true
end

function Coalitions.reply(game, player, id, accept)
    if not player.coalitionInvites[id] then return end
    clearInvite(game, player, id)
    local coalition = Coalitions.get(game, id)
    if not coalition then return end
    if accept then
        Coalitions.join(game, player, coalition)
    else
        coalition.leader:changeRelation(player, -5)
        game:notify(coalition.leader, string.format("%s declined to join %s.", player.name, coalition.name), { color = INFO })
    end
end

function Coalitions.disband(game, coalition, text, color)
    for _, member in ipairs(coalition.members) do
        release(game, member, coalition)
        member.coalition = nil
    end
    for k, other in ipairs(game.coalitions) do
        if other == coalition then
            table.remove(game.coalitions, k)
            break
        end
    end
    for _, player in ipairs(game.players) do
        if player.coalitionInvites[coalition.id] then
            clearInvite(game, player, coalition.id)
        end
    end
    tell(game, coalition, text, color or INFO)
    if coalition.target then
        game:notify(coalition.target, text, { color = color or INFO })
    end
end

function Coalitions.remove(game, player, deserted)
    local coalition = Coalitions.of(game, player)
    if not coalition then return end
    for k, member in ipairs(coalition.members) do
        if member == player then
            table.remove(coalition.members, k)
            break
        end
    end
    player.coalition = nil
    local atWar = coalition.target ~= nil and coalition.target.alive
    if deserted and atWar then
        for _, member in ipairs(coalition.members) do
            Diplomacy.dissolve(game, player, member)
            member:changeRelation(player, -40)
        end
        player.traitorUntil = game.tick + Config.traitorTicks
        game:notify(player, string.format("You deserted %s during the war. You are marked as a traitor.", coalition.name), { color = BAD })
        tell(game, coalition, string.format("%s deserted %s!", player.name, coalition.name), BAD)
    else
        release(game, player, coalition)
        if deserted then
            game:notify(player, string.format("You left %s.", coalition.name), { color = INFO })
        end
        tell(game, coalition, string.format("%s left %s.", player.name, coalition.name), INFO)
    end
    if #coalition.members < 2 and (coalition.kind == "defense" or #coalition.members == 0) then
        Coalitions.disband(game, coalition, coalition.name .. " has been dissolved.")
        return
    end
    if coalition.leader == player then
        coalition.leader = coalition.members[1]
        game:notify(coalition.leader, string.format("You now lead %s.", coalition.name), { color = INFO })
    end
end

function Coalitions.attackModifier(game, attacker, target)
    local modifier = 1
    local own = attacker and Coalitions.get(game, attacker.coalition)
    if own and own.target == target and #own.members >= 2 then
        modifier = modifier * (1 - Config.coalitionAttackBonus)
    end
    for _, coalition in ipairs(game.coalitions) do
        if coalition.target == target and #coalition.members >= 2 then
            modifier = modifier * (1 + Config.coalitionTargetDefense)
            break
        end
    end
    local defended = Coalitions.get(game, target.coalition)
    if defended and defended.kind == "defense" and (not attacker or attacker.coalition ~= defended.id) then
        modifier = modifier * (1 + Config.coalitionDefenseBonus)
    end
    return modifier
end

local function pending(game, coalition)
    for _, player in ipairs(game.players) do
        if player.coalitionInvites[coalition.id] then return true end
    end
    return false
end

local function involves(coalition, player)
    if not player then return false end
    if coalition.target == player then return true end
    for _, member in ipairs(coalition.members) do
        if member == player then return true end
    end
    return false
end

function Coalitions.step(game)
    if game.phase ~= "playing" or game.tick % 10 ~= 0 then return end
    for k = #game.coalitions, 1, -1 do
        local coalition = game.coalitions[k]
        local target = coalition.target
        local broken = target and (not target.alive
            or (Coalitions.share(game, target) < Config.coalitionDissolveShare and not Coalitions.isLeader(game, target)))
        if broken then
            for _, member in ipairs(coalition.members) do
                for _, other in ipairs(coalition.members) do
                    if other ~= member then member:changeRelation(other, 10) end
                end
            end
            local text = string.format("%s broke the power of %s and has been dissolved.", coalition.name, target.name)
            if not involves(coalition, game.human) then
                game:addEvent(text, { color = NEWS, minor = true })
            end
            Coalitions.disband(game, coalition, text, GOOD)
        elseif #coalition.members < 2 and game.tick - coalition.founded > Config.coalitionLonelyTicks and not pending(game, coalition) then
            Coalitions.disband(game, coalition, coalition.name .. " found no members and has been dissolved.")
        end
    end
    for _, player in ipairs(game.players) do
        for id, expires in pairs(player.coalitionInvites) do
            if expires <= game.tick then
                player.coalitionInvites[id] = nil
                player.coalitionEvents[id] = nil
            end
        end
    end
end

function Coalitions.allianceBroken(game, traitor, victim)
    if traitor.coalition and traitor.coalition == victim.coalition then
        Coalitions.remove(game, traitor, true)
    end
end

function Coalitions.eliminated(game, player)
    player.coalitionInvites = {}
    if player.coalition then
        Coalitions.remove(game, player, false)
    end
end

Coalitions.intents = {
    coalitionFound = function(game, intent)
        local founder, other = game.players[intent.player], game.players[intent.target]
        if founder and other then Coalitions.found(game, founder, intent.kind, other) end
    end,
    coalitionInvite = function(game, intent)
        local inviter, invitee = game.players[intent.player], game.players[intent.target]
        if inviter and invitee then Coalitions.invite(game, inviter, invitee) end
    end,
    coalitionReply = function(game, intent)
        local player = game.players[intent.player]
        if player then Coalitions.reply(game, player, intent.coalition, intent.accept) end
    end,
    coalitionLeave = function(game, intent)
        local player = game.players[intent.player]
        if player then Coalitions.remove(game, player, true) end
    end
}

return Coalitions
