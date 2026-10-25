local Personality = require("src.modules.ai.personality")
local Negotiator = require("src.modules.ai.negotiator")
local Loans = require("src.modules.game.systems.loans")
local T = require("tests.helpers")

local ALWAYS = { random = function() return 0 end }

local function scenario()
    local game = T.game({ bots = 0, nations = true, humans = { { name = "A" } } })
    for _ = 1, 160 do game:step() end
    local nations = {}
    for _, player in ipairs(game.players) do
        if player:isNation() and player.alive then nations[#nations + 1] = player end
    end
    local commands = {}
    game.commandSink = function(intent) commands[#commands + 1] = intent end
    game.aiRng = ALWAYS
    return game, nations, commands
end

local function find(commands, kind)
    for _, intent in ipairs(commands) do
        if intent.type == kind then return intent end
    end
end

return {
    {
        name = "nations get the same personality on every machine",
        run = function()
            local a = T.game({ bots = 0, seed = 1234 })
            local b = T.game({ bots = 0, seed = 1234, authority = false })
            local seen = {}
            for id, player in ipairs(a.players) do
                if player:isNation() then
                    T.expect(Personality.byId[player.personality], "nation without personality")
                    T.equal(b.players[id].personality, player.personality, "personality of " .. player.name)
                    seen[player.personality] = true
                end
            end
            local kinds = 0
            for _ in pairs(seen) do kinds = kinds + 1 end
            T.expect(kinds >= 3, "several personalities on one map")
            T.equal(Personality.of(a.players[1]).id, "balanced", "humans play balanced when the AI takes over")
        end
    },
    {
        name = "AI lenders help allies and refuse traitors and insolvent borrowers",
        run = function()
            local game, nations = scenario()
            local lender, borrower = nations[1], nations[2]
            lender.gold, borrower.income = 10000000, 2000
            lender.allies[borrower.id] = game.tick + 1000
            borrower.allies[lender.id] = game.tick + 1000
            local rate = Negotiator.lendingRate(game, lender, borrower, 500000)
            T.expect(rate == 0 or rate == 0.1, "cheap loan for an ally")
            borrower.income = 0
            T.equal(Negotiator.lendingRate(game, lender, borrower, 500000), nil, "insolvent borrower")
            borrower.income = 2000
            borrower.traitorUntil = game.tick + 100
            T.equal(Negotiator.lendingRate(game, lender, borrower, 500000), nil, "traitor borrower")
        end
    },
    {
        name = "AI at war accepts pacts that secure its flank",
        run = function()
            local game, nations, commands = scenario()
            local player, foe, neighbor = nations[1], nations[2], nations[3]
            player.troops, neighbor.troops = 100000, 50000
            table.insert(game.attacks, { attacker = player, target = foe, troops = 1000 })
            player.pactRequests[neighbor.id] = game.tick + 300
            T.expect(Negotiator.considerPacts(game, player), "pact request considered")
            local reply = T.expect(find(commands, "pactReply"), "pact reply sent")
            T.equal(reply.accept, true, "flank pact accepted")
            table.remove(game.attacks)
        end
    },
    {
        name = "AI gives notice on a pact before attacking a weak partner",
        run = function()
            local game, nations, commands = scenario()
            local player, partner = nations[1], nations[2]
            player.troops, player.maxPopulation, partner.troops = 1000000, 1500000, 1000
            player.pacts[partner.id] = { expires = game.tick + 6000 }
            partner.pacts[player.id] = { expires = game.tick + 6000 }
            T.expect(Negotiator.maybeEndPact(game, player, { neighbors = { partner } }), "pact ended")
            T.equal(find(commands, "pactEnd").target, partner.id, "pact end target")
            T.equal(Negotiator.plannedTarget(game, player), partner.id, "attack planned after the notice")
        end
    },
    {
        name = "AI borrows for its plans and repays before the deadline",
        run = function()
            local game, nations, commands = scenario()
            local borrower, lender = nations[1], nations[2]
            borrower.personality = "merchant"
            borrower.gold, borrower.income, borrower.crowded = 0, 2000, false
            lender.gold = 100000000
            game.tick = 2000
            T.expect(Negotiator.seekLoan(game, borrower, { neighbors = {} }), "loan requested")
            local request = find(commands, "loanRequest")
            T.expect(request.amount >= 125000, "loan covers the next city")
            local loan = Loans.grant(game, lender, borrower, 100000, 0.1)
            borrower.gold = 1000000
            loan.deadline = game.tick + 100
            T.expect(Negotiator.manageDebt(game, borrower), "debt managed")
            T.equal(find(commands, "loanRepay").target, lender.id, "loan repaid early")
        end
    }
}
