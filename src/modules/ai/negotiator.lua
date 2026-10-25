local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Loans = require("src.modules.game.systems.loans")
local Units = require("src.modules.game.systems.units")
local Personality = require("src.modules.ai.personality")

local Negotiator = {}

local PLAN_TICKS = 900
local REPAY_MARGIN = 900

function Negotiator.memory(player)
    player.aiMemory = player.aiMemory or {}
    return player.aiMemory
end

function Negotiator.enemies(game, player)
    local set = {}
    for _, attack in ipairs(Attack.incoming(game, player)) do
        if not attack.attacker:isBot() then set[attack.attacker.id] = attack.attacker end
    end
    for _, attack in ipairs(Attack.outgoing(game, player)) do
        if attack.target and not attack.target:isBot() then set[attack.target.id] = attack.target end
    end
    return set
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local function attacksAlly(game, player, other)
    for _, attack in ipairs(Attack.outgoing(game, other)) do
        if attack.target and player:isAlliedWith(attack.target) then return true end
    end
    return false
end

local function threatens(player, other)
    return player:canAttack(other) and other.troops > player.troops * 1.2 and player:relation(other) < 20
end

function Negotiator.plannedTarget(game, player)
    local memory = Negotiator.memory(player)
    if memory.plannedTarget and game.tick < (memory.plannedUntil or 0) then
        return memory.plannedTarget
    end
    memory.plannedTarget = nil
    return nil
end

function Negotiator.considerPacts(game, player)
    local traits = Personality.of(player)
    local enemies = Negotiator.enemies(game, player)
    for id in pairs(player.pactRequests) do
        local from = game.players[id]
        if from and from.alive then
            local relation = player:relation(from)
            local busy = count(enemies) > 0 and not enemies[from.id]
            local wanted = (busy and from.troops > player.troops * 0.4)
                or from.troops > player.troops * 0.6 / traits.caution
                or relation > 10
            local refused = from.traitorUntil > game.tick
                or relation < -40
                or attacksAlly(game, player, from)
                or Negotiator.plannedTarget(game, player) == from.id
                or (traits.aggression > 1 and not busy and from.troops < player.troops * 0.35)
            local accept = wanted and not refused and game.aiRng:random() < math.min(0.95, 0.8 * traits.diplomacy)
            game:command({ type = "pactReply", player = player.id, from = from.id, accept = accept })
            return true
        end
    end
    return false
end

function Negotiator.seekPact(game, player, ctx)
    local traits = Personality.of(player)
    local enemies = Negotiator.enemies(game, player)
    local atWar = count(enemies) > 0
    local chance = atWar and 0.35 or 0.08 * traits.caution
    if game.aiRng:random() > chance * traits.diplomacy then return false end
    for _, other in ipairs(ctx.neighbors) do
        if not other:isBot() and not enemies[other.id] and player:canAttack(other)
            and not other.pactRequests[player.id] and other.traitorUntil <= game.tick
            and player:relation(other) >= -30 and Negotiator.plannedTarget(game, player) ~= other.id then
            local flank = atWar and other.troops > player.troops * 0.5
            local scared = other.troops > player.troops * 1.2 / traits.caution
            if flank or scared then
                game:command({ type = "pactRequest", player = player.id, target = other.id })
                return true
            end
        end
    end
    return false
end

function Negotiator.maybeEndPact(game, player, ctx)
    local traits = Personality.of(player)
    if game.aiRng:random() > 0.05 * traits.aggression then return false end
    if count(Negotiator.enemies(game, player)) > 0 or player.troops < player.maxPopulation * 0.5 then return false end
    for _, other in ipairs(ctx.neighbors) do
        local pact = player.pacts[other.id]
        if pact and not pact.endsTick then
            local weak = other.troops < player.troops * 0.5 * traits.aggression
            local busy = #Attack.incoming(game, other) > 0 and traits.opportunism > 1
            if weak or busy then
                local memory = Negotiator.memory(player)
                memory.plannedTarget = other.id
                memory.plannedUntil = game.tick + Config.pactNoticeTicks + PLAN_TICKS
                game:command({ type = "pactEnd", player = player.id, target = other.id })
                return true
            end
        end
    end
    return false
end

local function debt(game, player)
    local total = 0
    for _, loan in ipairs(Loans.owedBy(game, player)) do
        total = total + Loans.remaining(loan)
    end
    return total
end

local function fightsMyFoes(game, player, borrower, enemies)
    for id, foe in pairs(Negotiator.enemies(game, borrower)) do
        if enemies[id] or threatens(player, foe) then return true end
    end
    return false
end

function Negotiator.lendingRate(game, player, borrower, amount)
    local traits = Personality.of(player)
    local enemies = Negotiator.enemies(game, player)
    if borrower.traitorUntil > game.tick or enemies[borrower.id] or attacksAlly(game, player, borrower) then return nil end
    if player.gold < amount * (1 + math.max(0.3, 2 - traits.lending)) then return nil end
    local capacity = math.max(0, borrower.income) * Config.loanTicks
    local owed = debt(game, borrower) + amount * (1 + Config.loanRates[1])
    if capacity < owed * 0.3 then return nil end
    local risky = capacity < owed * 0.8
    local low, high = Config.loanRates[1], Config.loanRates[#Config.loanRates]
    if player:isAlliedWith(borrower) then
        if risky then return low end
        return game.aiRng:random() < 0.5 * traits.lending and 0 or low
    end
    if fightsMyFoes(game, player, borrower, enemies) then return low end
    if threatens(player, borrower) then return nil end
    local relation = player:relation(borrower)
    if player:hasPact(borrower) or relation >= 10 then
        return risky and high or low
    end
    if relation >= -20 and traits.lending >= 1 then return high end
    return nil
end

function Negotiator.goal(game, player, ctx)
    local traits = Personality.of(player)
    local atWar = count(Negotiator.enemies(game, player)) > 0
    if atWar and player:unitCount("barracks") < 2 then
        return "barracks", Units.cost(game, player, "barracks")
    end
    if game.tick > 3000 and player:unitCount("silo") == 0 and traits.nuclear > 1 then
        return "silo", Units.cost(game, player, "silo") * 1.5
    end
    if not player.crowded and traits.greed >= 1 then
        return "city", Units.cost(game, player, "city")
    end
    return nil
end

local function lenderScore(game, player, other, amount, enemies)
    if other == player or not other.alive or other:isBot() or enemies[other.id] or other.gold < amount * 3 then return nil end
    if not Loans.canRequest(game, player, other, amount) then return nil end
    local relation = player:relation(other)
    if relation < -10 then return nil end
    local score = relation
    if player:isAlliedWith(other) then score = score + 50 end
    if player:hasPact(other) then score = score + 20 end
    return score
end

function Negotiator.seekLoan(game, player, ctx)
    local traits = Personality.of(player)
    if game.tick < 1500 or #Loans.owedBy(game, player) >= Config.maxLoans then return false end
    local memory = Negotiator.memory(player)
    if memory.saving or game.aiRng:random() > 0.06 * traits.greed then return false end
    local kind, need = Negotiator.goal(game, player, ctx)
    if not kind then return false end
    local gap = need - player.gold
    if gap <= 0 then return false end
    local enemies = Negotiator.enemies(game, player)
    for _, amount in ipairs(Config.loanAmounts) do
        local affordable = math.max(0, player.income) * Config.loanTicks >= amount * (1 + Config.loanRates[#Config.loanRates]) * 1.2
        if amount >= gap and affordable then
            local best, bestScore
            for _, other in ipairs(game.players) do
                local score = lenderScore(game, player, other, amount, enemies)
                if score and (not bestScore or score > bestScore) then
                    best, bestScore = other, score
                end
            end
            if not best then return false end
            memory.loanGoal = kind
            memory.loanGoalUntil = game.tick + Config.loanRequestTicks * 2
            game:command({ type = "loanRequest", player = player.id, target = best.id, amount = amount })
            return true
        end
    end
    return false
end

function Negotiator.answerOffer(game, player, offer)
    local memory = Negotiator.memory(player)
    local left = offer.amount * (1 + offer.rate)
    local affordable = math.max(0, player.income) * Config.loanTicks >= left * 1.1
    local needed = game.tick < (memory.loanGoalUntil or 0) or count(Negotiator.enemies(game, player)) > 0
    return affordable and needed and offer.rate <= Config.loanRates[#Config.loanRates]
end

function Negotiator.considerLoans(game, player)
    for id, request in pairs(player.loanRequests) do
        local borrower = game.players[id]
        if borrower and borrower.alive then
            game:command({ type = "loanReply", player = player.id, from = borrower.id, rate = Negotiator.lendingRate(game, player, borrower, request.amount) })
            return true
        end
    end
    for id, offer in pairs(player.loanOffers) do
        local lender = game.players[id]
        if lender then
            game:command({ type = "loanAnswer", player = player.id, from = lender.id, accept = Negotiator.answerOffer(game, player, offer) })
            return true
        end
    end
    return false
end

function Negotiator.manageDebt(game, player)
    local memory = Negotiator.memory(player)
    local loans = Loans.owedBy(game, player)
    memory.saving = false
    if #loans == 0 then return false end
    for _, loan in ipairs(loans) do
        local left = Loans.remaining(loan)
        local ticks = loan.deadline - game.tick
        if player.gold >= left and (ticks < REPAY_MARGIN or player.gold > left * 4) then
            game:command({ type = "loanRepay", player = player.id, target = loan.lender.id })
            return true
        end
        if left > player.gold + math.max(0, player.income) * ticks * 0.9 then
            memory.saving = true
        end
    end
    return false
end

return Negotiator
