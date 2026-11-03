local Config = require("src.config.game")
local Data = require("src.config.research")

local Research = {}

local GOOD = { 0.3, 0.85, 0.45, 1 }
local INFO = { 0.55, 0.75, 1, 1 }

function Research.enabled(game)
    return game.rules.research > 0
end

function Research.available(game, id)
    local tech = Data.byId[id]
    return tech ~= nil and Research.enabled(game) and (not tech.needsNukes or game.rules.nukes)
end

function Research.durationTicks(id)
    return Data.tiers[Data.byId[id].tier].seconds * Config.tickRate
end

local function friendsKnow(game, player, id)
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and other.research.known[id] and (player:isAlliedWith(other) or player:isTeammate(other)) then
            return true
        end
    end
    return false
end

local function commonKnowledge(game, id)
    local total, known = 0, 0
    for _, other in ipairs(game.players) do
        if other.alive and not other:isBot() then
            total = total + 1
            if other.research.known[id] then known = known + 1 end
        end
    end
    return total > 1 and known / total >= Data.commonShare
end

function Research.discounts(game, player, id)
    return friendsKnow(game, player, id), commonKnowledge(game, id)
end

function Research.cost(game, player, id)
    local locked = player.research.costs[id]
    if locked then return locked end
    local tier = Data.tiers[Data.byId[id].tier]
    local cost = math.max(tier.baseCost, math.max(0, player.income or 0) * Config.tickRate * tier.incomeSeconds)
    local friend, common = Research.discounts(game, player, id)
    if friend then cost = cost * (1 - Data.friendDiscount) end
    if common then cost = cost * (1 - Data.commonDiscount) end
    return math.floor(cost)
end

local function inQueue(player, id)
    for k, queued in ipairs(player.research.queue) do
        if queued == id then return k end
    end
    return nil
end

local function satisfied(player, id, allowQueued)
    local state = player.research
    local function has(other)
        return state.known[other] or (allowQueued and inQueue(player, other) ~= nil)
    end
    local tech = Data.byId[id]
    for _, other in ipairs(tech.requires or {}) do
        if not has(other) then return false end
    end
    if tech.requiresAny then
        for _, other in ipairs(tech.requiresAny) do
            if has(other) then return true end
        end
        return false
    end
    return true
end

local function excludedBy(player, id)
    local group = Data.byId[id].group
    if not group then return nil end
    for _, tech in ipairs(Data.list) do
        if tech.group == group and tech.id ~= id and (player.research.known[tech.id] or inQueue(player, tech.id)) then
            return tech
        end
    end
    return nil
end

function Research.canQueue(game, player, id)
    if not Research.enabled(game) then return false, "Research is disabled" end
    if not Research.available(game, id) then return false, "Nukes are disabled" end
    if not player.alive or player:isBot() then return false, "Not now" end
    if player.research.known[id] then return false, "Already researched" end
    if inQueue(player, id) then return false, "Already queued" end
    if #player.research.queue >= Data.maxQueue then return false, "The queue is full" end
    if excludedBy(player, id) then return false, "Excluded by your doctrine" end
    if not satisfied(player, id, true) then return false, "Prerequisite missing" end
    return true
end

function Research.status(game, player, id)
    if not Research.available(game, id) then return "disabled" end
    local state = player.research
    if state.known[id] then return "known" end
    local position = inQueue(player, id)
    if position == 1 then return "active" end
    if position then return "queued", position end
    if excludedBy(player, id) then return "excluded" end
    if satisfied(player, id, true) then return "available" end
    return "locked"
end

function Research.path(game, player, id)
    local path, seen = {}, {}
    local function visit(current)
        if seen[current] or player.research.known[current] or inQueue(player, current) then return true end
        if not Research.available(game, current) or excludedBy(player, current) then return false end
        seen[current] = true
        local tech = Data.byId[current]
        for _, other in ipairs(tech.requires or {}) do
            if not visit(other) then return false end
        end
        if tech.requiresAny and not satisfied(player, current, true) then
            local done = false
            for _, other in ipairs(tech.requiresAny) do
                if visit(other) then
                    done = true
                    break
                end
            end
            if not done then return false end
        end
        path[#path + 1] = current
        return true
    end
    if not visit(id) then return {} end
    return path
end

function Research.canPlan(game, player, id)
    if not Research.enabled(game) then return false, "Research is disabled" end
    if not Research.available(game, id) then return false, "Nukes are disabled" end
    if not player.alive or player:isBot() then return false, "Not now" end
    if player.research.known[id] then return false, "Already researched" end
    if inQueue(player, id) then return false, "Already queued" end
    if excludedBy(player, id) then return false, "Excluded by your doctrine" end
    local path = Research.path(game, player, id)
    if #path == 0 then return false, "Excluded by your doctrine" end
    if #path > Data.maxQueue - #player.research.queue then return false, "The queue is full" end
    return true
end

function Research.plan(game, player, id, first)
    if not Research.canPlan(game, player, id) then return false end
    local path = Research.path(game, player, id)
    for _, step in ipairs(path) do
        Research.enqueue(game, player, step, first and #path == 1)
    end
    return true
end

local function sweepQueue(player)
    local state = player.research
    local kept = {}
    state.queue, kept = kept, state.queue
    for _, id in ipairs(kept) do
        if satisfied(player, id, true) then
            state.queue[#state.queue + 1] = id
        end
    end
end

function Research.enqueue(game, player, id, first)
    if not Research.canQueue(game, player, id) then return false end
    local state = player.research
    if first and satisfied(player, id, false) then
        table.insert(state.queue, 1, id)
    else
        state.queue[#state.queue + 1] = id
    end
    return true
end

function Research.cancel(player, id)
    local position = inQueue(player, id)
    if not position then return false end
    table.remove(player.research.queue, position)
    sweepQueue(player)
    return true
end

function Research.rebuild(player)
    local bonus = {}
    for _, tech in ipairs(Data.list) do
        if player.research.known[tech.id] then
            for key, value in pairs(tech.effects) do
                bonus[key] = (bonus[key] or 0) + value
            end
        end
    end
    player.techBonus = bonus
    player.supplyTick = nil
end

function Research.complete(game, player, id)
    local state = player.research
    local tech = Data.byId[id]
    state.known[id] = true
    state.count = state.count + 1
    state.progress[id] = nil
    state.costs[id] = nil
    local position = inQueue(player, id)
    if position then table.remove(state.queue, position) end
    sweepQueue(player)
    Research.rebuild(player)
    game:emit("researchCompleted", player, id)
    if player == game.human then
        game:addEvent("Research complete: " .. tech.label .. ".", { color = GOOD })
    elseif tech.group and not player:isBot() then
        game:addEvent(player.name .. " adopted " .. tech.label .. ".", { color = INFO, minor = true })
    end
end

function Research.nextIndex(player)
    for k, id in ipairs(player.research.queue) do
        if satisfied(player, id, false) then return k, id end
    end
    return nil
end

function Research.nextReady(player, id)
    return satisfied(player, id, false)
end

local function stepPlayer(game, player)
    local state = player.research
    local _, id = Research.nextIndex(player)
    if not id then
        state.stalled = nil
        return
    end
    if player.capitalLostUntil and player.capitalLostUntil > game.tick then
        state.stalled = "capital"
        return
    end
    if not state.costs[id] then
        state.costs[id] = Research.cost(game, player, id)
    end
    local duration = Research.durationTicks(id)
    local speed = game.rules.research
    local payment = state.costs[id] / duration * speed
    local budget = player.gold >= state.costs[id] and payment or math.min(player.gold, math.max(0, player.income or 0) * Data.fundingShare)
    if budget <= 0 then
        state.stalled = "gold"
        return
    end
    local share = math.min(1, budget / payment)
    state.stalled = share < 1 and "slow" or nil
    player.gold = player.gold - payment * share
    state.progress[id] = (state.progress[id] or 0) + speed * share
    if state.progress[id] >= duration then
        Research.complete(game, player, id)
    end
end

function Research.step(game)
    if game.phase ~= "playing" or not Research.enabled(game) then return end
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and #player.research.queue > 0 then
            stepPlayer(game, player)
        end
    end
end

function Research.progress(player, id)
    return math.min(1, (player.research.progress[id] or 0) / Research.durationTicks(id))
end

function Research.unitRemoved(game, unit)
    local by = unit.capturedBy
    if unit.kind ~= "capital" or not by or by:isBot() or not Research.enabled(game) then return end
    for _, tech in ipairs(Data.list) do
        local id = tech.id
        if unit.owner.research.known[id] and not by.research.known[id] and Research.available(game, id)
            and not excludedBy(by, id) and satisfied(by, id, false) then
            local duration = Research.durationTicks(id)
            local state = by.research
            if (state.progress[id] or 0) < duration * Data.stolenProgress then
                state.progress[id] = math.floor(duration * Data.stolenProgress)
                state.costs[id] = state.costs[id] or Research.cost(game, by, id)
                game:notify(by, string.format("Plans captured from %s: %s is half researched.", unit.owner.name, tech.label), { color = GOOD })
                game:notify(unit.owner, string.format("%s captured your plans for %s.", by.name, tech.label), { color = { 0.95, 0.35, 0.3, 1 }, minor = true })
                return
            end
        end
    end
end

Research.intents = {
    researchQueue = function(game, intent)
        local player = game.players[intent.player]
        if player then Research.plan(game, player, intent.tech, intent.first == true) end
    end,
    researchCancel = function(game, intent)
        local player = game.players[intent.player]
        if player then Research.cancel(player, intent.tech) end
    end
}

return Research
