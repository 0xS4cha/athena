local Config = require("src.config.game")
local Format = require("src.core.format")

local Loans = {}

local GOOD = { 0.3, 0.85, 0.45, 1 }
local BAD = { 0.95, 0.35, 0.3, 1 }
local INFO = { 0.55, 0.75, 1, 1 }
local GOLD = { 1, 0.82, 0.25, 1 }

function Loans.init(game)
    game.loans = {}
    game.loanSerial = 0
end

function Loans.remaining(loan)
    return loan.due - loan.paid
end

function Loans.owedBy(game, borrower)
    local list = {}
    for _, loan in ipairs(game.loans) do
        if loan.borrower == borrower then
            list[#list + 1] = loan
        end
    end
    return list
end

function Loans.between(game, lender, borrower)
    for _, loan in ipairs(game.loans) do
        if loan.lender == lender and loan.borrower == borrower then
            return loan
        end
    end
    return nil
end

function Loans.involving(game, player)
    local list = {}
    for _, loan in ipairs(game.loans) do
        if loan.lender == player or loan.borrower == player then
            list[#list + 1] = loan
        end
    end
    return list
end

function Loans.canRequest(game, borrower, lender, amount)
    if borrower == lender or not lender.alive or not borrower.alive or lender:isBot() then
        return false, "Unavailable"
    end
    if borrower.embargo[lender.id] or lender.embargo[borrower.id] then
        return false, "Embargo"
    end
    if lender.loanRequests[borrower.id] or borrower.loanOffers[lender.id] then
        return false, "Pending"
    end
    if Loans.between(game, lender, borrower) then
        return false, "Already owed"
    end
    if #Loans.owedBy(game, borrower) >= Config.maxLoans then
        return false, "Too many loans"
    end
    if lender.gold < amount then
        return false, "Too poor"
    end
    return true
end

local function describe(amount, rate)
    local due = math.floor(amount * (1 + rate))
    return string.format("%s gold, repay %s within %s", Format.number(amount), Format.number(due), Format.time(Config.loanTicks, Config.tickRate))
end

local function clearRequest(game, lender, borrower)
    local request = lender.loanRequests[borrower.id]
    lender.loanRequests[borrower.id] = nil
    if request and request.event then
        game:removeEvent(request.event)
    end
    return request
end

local function clearOffer(game, borrower, lender)
    local offer = borrower.loanOffers[lender.id]
    borrower.loanOffers[lender.id] = nil
    if offer and offer.event then
        game:removeEvent(offer.event)
    end
    return offer
end

function Loans.request(game, borrower, lender, amount)
    if not Loans.canRequest(game, borrower, lender, amount) then return end
    local request = { amount = amount, expires = game.tick + Config.loanRequestTicks }
    lender.loanRequests[borrower.id] = request
    game:notify(borrower, string.format("Loan of %s gold requested from %s.", Format.number(amount), lender.name), { color = INFO, minor = true })
    if lender == game.human then
        local function reply(rate)
            return function() game:submit({ type = "loanReply", player = lender.id, from = borrower.id, rate = rate }) end
        end
        local actions = { { label = "Lend", color = { 0.15, 0.6, 0.3, 0.9 }, run = reply(0) } }
        for _, rate in ipairs(Config.loanRates) do
            actions[#actions + 1] = { label = string.format("+%d%%", math.floor(rate * 100 + 0.5)), color = { 0.75, 0.55, 0.1, 0.9 }, run = reply(rate) }
        end
        actions[#actions + 1] = { label = "Refuse", color = { 0.7, 0.2, 0.2, 0.9 }, run = reply(nil) }
        request.event = game:addEvent(string.format("%s asks to borrow %s gold.", borrower.name, Format.number(amount)), {
            color = GOLD,
            duration = Config.loanRequestTicks,
            actions = actions
        })
    end
end

function Loans.grant(game, lender, borrower, amount, rate)
    if not lender.alive or not borrower.alive then return end
    if lender.gold < amount then
        game:notify(borrower, lender.name .. " no longer has the gold to lend you.", { color = BAD })
        game:notify(lender, "You no longer have the gold for " .. borrower.name .. "'s loan.", { color = BAD })
        return
    end
    lender.gold = lender.gold - amount
    borrower.gold = borrower.gold + amount
    game.loanSerial = game.loanSerial + 1
    local loan = {
        id = game.loanSerial,
        lender = lender,
        borrower = borrower,
        principal = amount,
        rate = rate,
        due = math.floor(amount * (1 + rate)),
        paid = 0,
        start = game.tick,
        deadline = game.tick + Config.loanTicks
    }
    game.loans[#game.loans + 1] = loan
    lender:changeRelation(borrower, 5)
    borrower:changeRelation(lender, rate == 0 and 25 or 10)
    game:notify(borrower, string.format("%s lent you %s.", lender.name, describe(amount, rate)), { color = GOOD })
    game:notify(lender, string.format("You lent %s gold to %s, %s due.", Format.number(amount), borrower.name, Format.number(loan.due)), { color = GOOD, minor = true })
    return loan
end

function Loans.reply(game, lender, borrower, rate)
    local request = clearRequest(game, lender, borrower)
    if not request then return end
    if not rate then
        borrower:changeRelation(lender, -5)
        game:notify(borrower, lender.name .. " refused to lend you gold.", { color = BAD })
        return
    end
    if rate == 0 then
        Loans.grant(game, lender, borrower, request.amount, 0)
        return
    end
    local offer = { amount = request.amount, rate = rate, expires = game.tick + Config.loanRequestTicks }
    borrower.loanOffers[lender.id] = offer
    game:notify(lender, string.format("Loan offer sent to %s at %d%% interest.", borrower.name, math.floor(rate * 100 + 0.5)), { color = INFO, minor = true })
    if borrower == game.human then
        offer.event = game:addEvent(string.format("%s offers %s (%d%% interest).", lender.name, describe(request.amount, rate), math.floor(rate * 100 + 0.5)), {
            color = GOLD,
            duration = Config.loanRequestTicks,
            actions = {
                { label = "Accept", color = { 0.15, 0.6, 0.3, 0.9 }, run = function() game:submit({ type = "loanAnswer", player = borrower.id, from = lender.id, accept = true }) end },
                { label = "Decline", color = { 0.7, 0.2, 0.2, 0.9 }, run = function() game:submit({ type = "loanAnswer", player = borrower.id, from = lender.id, accept = false }) end }
            }
        })
    end
end

function Loans.answer(game, borrower, lender, accept)
    local offer = clearOffer(game, borrower, lender)
    if not offer then return end
    if accept then
        Loans.grant(game, lender, borrower, offer.amount, offer.rate)
    else
        game:notify(lender, borrower.name .. " declined your loan terms.", { color = INFO })
    end
end

local function close(game, loan)
    for k, other in ipairs(game.loans) do
        if other == loan then
            table.remove(game.loans, k)
            return
        end
    end
end

function Loans.pay(game, loan, amount)
    amount = math.min(amount, Loans.remaining(loan), loan.borrower.gold)
    if amount <= 0 then return 0 end
    loan.borrower.gold = loan.borrower.gold - amount
    loan.lender.gold = loan.lender.gold + amount
    loan.paid = loan.paid + amount
    if Loans.remaining(loan) <= 0 then
        close(game, loan)
        loan.lender:changeRelation(loan.borrower, 15)
        game:notify(loan.borrower, "You repaid your loan to " .. loan.lender.name .. ".", { color = GOOD, minor = true })
        game:notify(loan.lender, loan.borrower.name .. " repaid their loan in full.", { color = GOOD })
    end
    return amount
end

function Loans.default(game, loan)
    close(game, loan)
    local borrower, lender = loan.borrower, loan.lender
    borrower.traitorUntil = game.tick + Config.traitorTicks
    lender:changeRelation(borrower, -60)
    for _, other in ipairs(game.players) do
        if other ~= borrower and other ~= lender and other.alive then
            other:changeRelation(borrower, -10)
        end
    end
    local left = Format.number(Loans.remaining(loan))
    game:notify(lender, string.format("%s defaulted on %s gold!", borrower.name, left), { color = BAD, duration = 300 })
    game:notify(borrower, string.format("You defaulted on your loan to %s. You are marked as a traitor.", lender.name), { color = BAD, duration = 300 })
    if borrower ~= game.human and lender ~= game.human then
        game:addEvent(borrower.name .. " defaulted on a loan from " .. lender.name .. ".", { color = { 0.95, 0.6, 0.3, 1 }, minor = true })
    end
end

function Loans.step(game)
    if game.phase ~= "playing" or game.tick % Config.loanInterval ~= 0 then return end
    local tick = game.tick
    local installments = Config.loanTicks / Config.loanInterval
    for k = #game.loans, 1, -1 do
        local loan = game.loans[k]
        if not loan.lender.alive or not loan.borrower.alive then
            table.remove(game.loans, k)
        elseif tick >= loan.deadline then
            Loans.pay(game, loan, Loans.remaining(loan))
            if Loans.remaining(loan) > 0 then
                Loans.default(game, loan)
            end
        else
            Loans.pay(game, loan, loan.due / installments)
        end
    end
    for _, player in ipairs(game.players) do
        for id, request in pairs(player.loanRequests) do
            if request.expires <= tick then
                player.loanRequests[id] = nil
            end
        end
        for id, offer in pairs(player.loanOffers) do
            if offer.expires <= tick then
                player.loanOffers[id] = nil
            end
        end
    end
end

function Loans.eliminated(game, player)
    player.loanRequests = {}
    player.loanOffers = {}
end

local function pair(game, intent, key)
    return game.players[intent.player], game.players[intent[key]]
end

Loans.intents = {
    loanRequest = function(game, intent)
        local borrower, lender = pair(game, intent, "target")
        if borrower and lender then Loans.request(game, borrower, lender, intent.amount) end
    end,
    loanReply = function(game, intent)
        local lender, borrower = pair(game, intent, "from")
        if lender and borrower then Loans.reply(game, lender, borrower, intent.rate) end
    end,
    loanAnswer = function(game, intent)
        local borrower, lender = pair(game, intent, "from")
        if borrower and lender then Loans.answer(game, borrower, lender, intent.accept) end
    end,
    loanRepay = function(game, intent)
        local borrower, lender = pair(game, intent, "target")
        local loan = borrower and lender and Loans.between(game, lender, borrower)
        if loan then Loans.pay(game, loan, Loans.remaining(loan)) end
    end
}

return Loans
