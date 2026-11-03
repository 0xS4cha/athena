local Config = require("src.config.game")
local Data = require("src.config.research")
local Codec = require("src.net.codec")
local Intents = require("src.net.intents")
local Snapshot = require("src.net.snapshot")
local Research = require("src.modules.game.systems.research")
local Economy = require("src.modules.game.systems.economy")
local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")
local Researcher = require("src.modules.ai.researcher")
local Tree = require("src.modules.hud.components.research")
local T = require("tests.helpers")

local CAPS = {
    income = 0.12, tradeGold = 0.31, buildCost = -0.13, conquest = -0.12, defense = 0.15,
    attackSpeed = 0.21, navalHealth = 0.21, navalDamage = 0.16, nukeCost = -0.16, adminRange = 16
}

local function started(options)
    local base = { bots = 0, nations = false, humans = { { name = "A" }, { name = "B" } } }
    for k, v in pairs(options or {}) do base[k] = v end
    local game = T.game(base)
    game.spawnTicksLeft = 1
    game:step()
    return game, game.players[1], game.players[2]
end

local function learn(player, ...)
    for _, id in ipairs({ ... }) do
        player.research.known[id] = true
        player.research.count = player.research.count + 1
    end
    Research.rebuild(player)
end

local function run(game, ticks)
    for _ = 1, ticks do game:step() end
end

local function bestSum(key)
    local groups, total = {}, 0
    for _, tech in ipairs(Data.list) do
        local value = tech.effects[key] or 0
        local helps = (Data.effects[key].lowerIsBetter and value < 0) or (not Data.effects[key].lowerIsBetter and value > 0)
        if helps then
            if tech.group then
                groups[tech.group] = value
            else
                total = total + value
            end
        end
    end
    for _, value in pairs(groups) do total = total + value end
    return total
end

return {
    {
        name = "the catalog is a sound tree with one exclusive doctrine per branch",
        run = function()
            local groups = {}
            for _, tech in ipairs(Data.list) do
                T.expect(Data.tiers[tech.tier], tech.id .. " has a tier")
                for _, parent in ipairs(tech.requires or tech.requiresAny or {}) do
                    T.expect(Data.byId[parent], tech.id .. " requires a known technology")
                    T.equal(Data.byId[parent].tier, tech.tier - 1, tech.id .. " follows the previous tier")
                    T.equal(Data.byId[parent].branch, tech.branch, tech.id .. " stays in its branch")
                end
                for key in pairs(tech.effects) do
                    T.expect(Data.effects[key], tech.id .. " has a described effect: " .. key)
                end
                if tech.group then
                    groups[tech.group] = (groups[tech.group] or 0) + 1
                end
                T.expect(#Tree.effectLines(tech) > 0, tech.id .. " shows its effects")
            end
            T.equal(#Data.branches, 4, "branches")
            for group, count in pairs(groups) do
                T.equal(count, 2, group .. " offers exactly two choices")
            end
        end
    },
    {
        name = "every doctrine has a real drawback",
        run = function()
            for _, tech in ipairs(Data.list) do
                if tech.group then
                    local good, bad = false, false
                    for _, line in ipairs(Tree.effectLines(tech)) do
                        if line.good then good = true else bad = true end
                    end
                    T.expect(good and bad, tech.id .. " trades a bonus for a drawback")
                end
            end
        end
    },
    {
        name = "the strongest possible bonuses stay below the balance caps",
        run = function()
            for key, cap in pairs(CAPS) do
                local best = bestSum(key)
                if cap < 0 then
                    T.expect(best >= cap, key .. " is within its cap: " .. best)
                else
                    T.expect(best <= cap, key .. " is within its cap: " .. best)
                end
            end
            local _, a = started()
            for _, tech in ipairs(Data.list) do
                if not tech.group or tech.id == "blitzkrieg" or tech.id == "freeMarket" then learn(a, tech.id) end
            end
            T.expect(a:tech("income") <= 0.12, "income on a full path")
            T.expect(a:tech("conquest") >= -0.12, "conquest on a full path")
        end
    },
    {
        name = "an economic technology takes minutes to pay for itself, even on a large empire",
        run = function()
            for _, income in ipairs({ 50, 500, 5000, 50000 }) do
                local game, a = started()
                a.income = income
                local cost = Research.cost(game, a, "taxation")
                local gainPerSecond = income * Config.tickRate * Data.byId.taxation.effects.income
                T.expect(cost / gainPerSecond >= 300, "taxation pays back in at least 5 minutes at income " .. income)
            end
        end
    },
    {
        name = "costs follow the income so that a large empire cannot buy everything",
        run = function()
            local game, a, b = started()
            a.income, b.income = 10, 20000
            T.equal(Research.cost(game, a, "taxation"), Data.tiers[1].baseCost, "base cost for a small empire")
            T.equal(Research.cost(game, b, "taxation"), 20000 * Config.tickRate * Data.tiers[1].incomeSeconds, "scaled for a large one")
        end
    },
    {
        name = "prerequisites, doctrines, the full queue and tribes are enforced by the server",
        run = function()
            local game, a = started({ bots = 2 })
            T.expect(not Research.canQueue(game, a, "ironclads"), "a single step needs its prerequisite")
            local _, reason = Intents.sanitize(game, 1, { type = "researchQueue", tech = "nothing" })
            T.expect(reason, "unknown technology")
            T.expect(Intents.sanitize(game, 1, { type = "researchQueue", tech = "taxation", player = 2 }).player == 1, "only for the sender")
            T.expect(Research.enqueue(game, a, "taxation"), "queued")
            T.expect(Research.enqueue(game, a, "tradeGuilds"), "a queued prerequisite counts")
            T.expect(Research.enqueue(game, a, "freeMarket"), "doctrine queued")
            T.expect(not Research.enqueue(game, a, "publicWorks"), "the other doctrine is excluded")
            T.equal(Research.status(game, a, "publicWorks"), "excluded", "excluded status")
            T.expect(not Research.enqueue(game, a, "taxation"), "no duplicate")
            T.expect(Research.enqueue(game, a, "drill"), "fourth")
            T.expect(Research.enqueue(game, a, "shipyards"), "fifth")
            T.expect(not Research.enqueue(game, a, "earlyWarning"), "the queue is full")
            T.expect(Research.cancel(a, "taxation"), "cancelled")
            T.equal(Research.status(game, a, "tradeGuilds"), "locked", "what depended on it leaves the queue")
            T.equal(Research.status(game, a, "freeMarket"), "locked", "in cascade")
            T.equal(#a.research.queue, 2, "the rest stays")
            local tribe
            for _, player in ipairs(game.players) do if player:isBot() then tribe = player end end
            T.expect(not Research.canQueue(game, tribe, "taxation"), "tribes do not research")
        end
    },
    {
        name = "a technology is paid over time, stalls without gold and applies when finished",
        run = function()
            local game, a = started()
            a.income = 0
            local cost = Research.cost(game, a, "taxation")
            a.gold = cost + 500000
            local rate = Economy.goldRate(game, a)
            T.expect(rate > 0, "earns gold")
            game:pushIntent({ type = "researchQueue", player = 1, tech = "taxation" })
            local before = a.gold
            game:step()
            T.expect(a.gold < before, "paying")
            T.expect(a.gold > before - cost * 0.05, "only a small share at a time")

            local keep = a.gold
            a.gold = 0
            local progress = a.research.progress.taxation
            a.income = 0
            Research.step(game)
            T.equal(a.research.stalled, "gold", "stalled")
            T.equal(a.research.progress.taxation, progress, "no progress without gold or income")

            a.gold, a.income = 10, 20
            Research.step(game)
            T.equal(a.research.stalled, "slow", "slowed down")
            T.equal(a.gold, 0, "pays half of the income, within its gold")
            T.expect(a.research.progress.taxation > progress and a.research.progress.taxation < progress + 1, "partial progress")
            a.gold = keep

            a.capitalLostUntil = game.tick + 100
            Research.step(game)
            T.equal(a.research.stalled, "capital", "paused without a capital")
            a.capitalLostUntil = nil

            for _ = 1, Research.durationTicks("taxation") do
                a.gold = math.max(a.gold, cost)
                Research.step(game)
                if a.research.known.taxation then break end
            end
            T.expect(a.research.known.taxation, "finished")
            T.equal(#a.research.queue, 0, "left the queue")
            T.equal(a:tech("income"), 0.05, "the bonus applies")
        end
    },
    {
        name = "low gold slows research and always leaves half of the income for buildings",
        run = function()
            local game, a = started()
            local cost = Research.cost(game, a, "taxation")
            Research.enqueue(game, a, "taxation")
            a.gold, a.income = 0, 40
            local spent, steps = 0, 0
            while not a.research.known.taxation and steps < 100000 do
                a.gold = math.min(a.gold + a.income, cost * 0.5)
                local before = a.gold
                Research.step(game)
                local paid = before - a.gold
                T.expect(paid <= a.income * Data.fundingShare + 1e-6, "never more than half of the income")
                spent = spent + paid
                steps = steps + 1
            end
            T.expect(a.research.known.taxation, "finishes in the end")
            T.expect(steps > Research.durationTicks("taxation"), "takes longer")
            T.expect(math.abs(spent - cost) < 1, "for the same price")
        end
    },
    {
        name = "the total paid equals the price, at both speeds",
        run = function()
            for _, speed in ipairs({ 1, 2 }) do
                local game, a = started({ rules = { mode = "custom", research = speed } })
                a.income = 0
                local cost = Research.cost(game, a, "drill")
                a.gold = cost * 3
                Research.enqueue(game, a, "drill")
                local before, steps = a.gold, 0
                while not a.research.known.drill do
                    Research.step(game)
                    steps = steps + 1
                end
                T.expect(math.abs(before - a.gold - cost) < 1, "paid the price at speed " .. speed)
                T.equal(steps, Research.durationTicks("drill") / speed, "duration at speed " .. speed)
            end
        end
    },
    {
        name = "allies and widespread knowledge make a technology cheaper",
        run = function()
            local game, a, b = started({ humans = { { name = "A" }, { name = "B" }, { name = "C" }, { name = "D" }, { name = "E" } } })
            a.income = 0
            local base = Research.cost(game, a, "drill")
            learn(b, "drill")
            T.equal(Research.cost(game, a, "drill"), base, "an enemy shares nothing")
            a.allies[b.id] = game.tick
            b.allies[a.id] = game.tick
            T.equal(Research.cost(game, a, "drill"), math.floor(base * 0.8), "an ally shares")
            learn(game.players[3], "drill")
            learn(game.players[4], "drill")
            T.equal(Research.cost(game, a, "drill"), math.floor(base * 0.8 * 0.85), "widespread as well")
            Research.enqueue(game, a, "drill")
            a.gold = base
            Research.step(game)
            local locked = Research.cost(game, a, "drill")
            a.allies[b.id], b.allies[a.id] = nil, nil
            T.equal(Research.cost(game, a, "drill"), locked, "the price is locked once started")
        end
    },
    {
        name = "bonuses reach the systems, and a player without technology is unchanged",
        run = function()
            local game, a, b = started({ bots = 2 })
            local tile = next(a.borders)
            local neutral = { attacker = a, troops = 10000, target = nil }
            local cost = Attack.cost(game, neutral, tile)
            T.expect(Attack.tilesPerTick(neutral) > 0, "speed")
            local speed = Attack.tilesPerTick({ attacker = a, troops = 10000 })
            local cityCost = Units.cost(game, a, "city")
            local rate = Economy.goldRate(game, a)
            local capacity = Economy.housingCapacity(a)
            local shipCost = Units.cost(game, a, "warship")
            local nuke = Nukes.cost(a, "atom")
            T.equal(nuke, Config.nukes.atom.cost, "no change without technology")
            T.equal(cityCost, Config.units.city.cost, "no change without technology")

            learn(a, "taxation", "urbanPlanning", "publicWorks", "drill", "forcedMarch", "blitzkrieg", "shipyards", "firstStrike")
            T.expect(math.abs(Attack.cost(game, neutral, tile) - cost * 0.92) < 1e-6, "conquest")
            T.expect(Attack.tilesPerTick({ attacker = a, troops = 10000 }) > speed, "attack speed")
            T.expect(math.abs(Units.cost(game, a, "city") - cityCost * 0.88) < 1e-6, "build cost")
            T.expect(math.abs(Economy.goldRate(game, a) - rate * 1.02) < 1e-6, "income with a doctrine drawback")
            T.expect(math.abs(Economy.housingCapacity(a) - capacity * 1.1) < 1e-6, "housing")
            T.expect(math.abs(Units.cost(game, a, "warship") - shipCost * 0.9) < 1e-6, "naval cost")
            T.expect(math.abs(Nukes.cost(a, "atom") - nuke * 0.85) < 1e-6, "nuke cost")

            local attack = { attacker = b, target = a, troops = 1000 }
            local tileOfA = next(a.borders)
            local weak = Attack.cost(game, attack, tileOfA)
            learn(a, "fortifications")
            T.expect(Attack.cost(game, attack, tileOfA) > weak, "defense makes the land harder to take")
        end
    },
    {
        name = "capturing a capital steals plans, once",
        run = function()
            local game, a, b = started()
            learn(a, "taxation")
            local capital = a.capital
            T.expect(capital, "capital")
            capital.capturedBy = b
            Research.unitRemoved(game, capital)
            T.equal(b.research.progress.taxation, Research.durationTicks("taxation") * Data.stolenProgress, "half researched")
            T.expect(b.research.costs.taxation, "the price is known")
            T.expect(not b.research.known.taxation, "not finished for free")
            Research.unitRemoved(game, capital)
            T.equal(b.research.progress.taxation, Research.durationTicks("taxation") * Data.stolenProgress, "no more on the same technology")
        end
    },
    {
        name = "the research rule removes the system, for the AI too",
        run = function()
            local game, a = started({ rules = { mode = "custom", research = 0 } })
            local _, reason = Intents.sanitize(game, 1, { type = "researchQueue", tech = "taxation" })
            T.equal(reason, "Research is disabled", "refused")
            game:pushIntent({ type = "researchQueue", player = 1, tech = "taxation" })
            game:step()
            T.equal(#a.research.queue, 0, "nothing queued")
            local conventional, c = started({ rules = { mode = "conventional" } })
            T.equal(Research.status(conventional, c, "firstStrike"), "disabled", "no nuclear research without nukes")
            T.equal(Research.status(conventional, c, "earlyWarning"), "available", "radars stay")
            T.expect(not Research.canQueue(conventional, c, "rapidReload"), "refused")
        end
    },
    {
        name = "the tree plans a whole path, cancels and refuses what cannot fit",
        run = function()
            local game, a = started()
            local plan = Tree.plan(game, a, "freeMarket", false)
            T.equal(#plan, 1, "one order, so the server validates it in one go")
            local accepted = T.expect(Intents.sanitize(game, 1, plan[1]), "the server accepts a locked technology with its path")
            game:pushIntent(accepted)
            game:step()
            T.equal(#a.research.queue, 3, "the whole path is queued in one tick")
            T.equal(a.research.queue[1], "taxation", "first")
            T.equal(a.research.queue[3], "freeMarket", "last")
            T.equal(Tree.plan(game, a, "freeMarket", false)[1].type, "researchCancel", "a second click cancels")
            T.equal(#Tree.plan(game, a, "publicWorks", false), 0, "excluded")
            T.expect(Tree.plan(game, a, "drill", true)[1].first, "shift researches first")
            local first = T.expect(Intents.sanitize(game, 1, Tree.plan(game, a, "drill", true)[1]))
            game:pushIntent(first)
            game:step()
            T.equal(a.research.queue[1], "drill", "researched first")
            T.equal(#Tree.plan(game, a, "veterans", false), 0, "too long for the queue")
            local _, reason = Intents.sanitize(game, 1, { type = "researchQueue", tech = "veterans" })
            T.equal(reason, "The queue is full", "the server refuses it too")
        end
    },
    {
        name = "no node overlaps another, on small and large screens",
        run = function()
            for _, size in ipairs({ { 1000, 600 }, { 1280, 720 }, { 1320, 780 } }) do
                local l = Tree.layout(0, 0, size[1], size[2])
                local rects = {}
                for _, tech in ipairs(Data.list) do
                    local x, y, w, h = Tree.nodeRect(l, tech)
                    T.expect(w > 60 and h > 30, "readable node")
                    T.expect(x >= 0 and x + w <= size[1] and y + h <= l.bottom, tech.id .. " fits")
                    for _, other in ipairs(rects) do
                        T.expect(x + w <= other.x or other.x + other.w <= x or y + h <= other.y or other.y + other.h <= y, tech.id .. " overlaps")
                    end
                    rects[#rects + 1] = { x = x, y = y, w = w, h = h }
                end
            end
        end
    },
    {
        name = "AI nations research by personality on hard and not on easy",
        run = function()
            local game = T.game({ bots = 0, nations = true, authority = true, difficulty = "hard" })
            local nation
            for _, player in ipairs(game.players) do
                if player:isNation() and player.alive then nation = player break end
            end
            nation.personality = "warlord"
            nation.income = 100
            local tech = Researcher.choose(game, nation)
            T.expect(tech and tech.tier == 1, "starts on the first tier")
            nation.gold = 1e7
            game.tick = Data.aiStartTicks
            local sent
            game.commandSink = function(intent) sent = intent end
            Researcher.think(game, nation)
            T.equal(sent and sent.type, "researchQueue", "queues a technology")

            local easy = T.game({ bots = 0, nations = true, authority = true, difficulty = "easy" })
            sent = nil
            easy.commandSink = function(intent) sent = intent end
            easy.tick = Data.aiStartTicks
            local other
            for _, player in ipairs(easy.players) do
                if player:isNation() and player.alive then other = player break end
            end
            other.income, other.gold = 100, 1e7
            Researcher.think(easy, other)
            T.equal(sent, nil, "easy nations do not research")

            game.tick = Data.aiStartTicks - 1
            sent = nil
            game.commandSink = function(intent) sent = intent end
            Researcher.think(game, nation)
            T.equal(sent, nil, "not before the opening is over")
        end
    },
    {
        name = "research stays deterministic through the AI and snapshots",
        run = function()
            local humans = { { name = "A" }, { name = "B" } }
            local server = T.game({ authority = true, autoplay = true, humans = humans, bots = 10 })
            local client = T.game({ authority = false, humans = humans, bots = 10 })
            local queue = {}
            server.commandSink = function(intent) queue[#queue + 1] = intent end
            local late
            for tick = 1, 500 do
                if tick == 170 then
                    server.players[1].gold = server.players[1].gold + 1e6
                    client.players[1].gold = client.players[1].gold + 1e6
                    queue[#queue + 1] = { type = "researchQueue", player = 1, tech = "taxation" }
                end
                local commands = queue
                queue = {}
                local wire = Codec.decode(Codec.encode(commands))
                for _, intent in ipairs(commands) do server:pushIntent(intent) end
                for _, intent in ipairs(wire) do client:pushIntent(intent) end
                server:step()
                client:step()
                if late then
                    for _, intent in ipairs(wire) do late:pushIntent(intent) end
                    late:step()
                    T.equal(late:checksum(), server:checksum(), "restored client at tick " .. server.tick)
                end
                T.equal(client:checksum(), server:checksum(), "tick " .. server.tick)
                if tick == 300 then
                    T.expect((server.players[1].research.progress.taxation or 0) > 0 or server.players[1].research.known.taxation, "researching")
                    late = T.game({ authority = false, humans = humans, bots = 10 })
                    T.applySnapshot(late, Snapshot.encode(server))
                end
            end
            T.equal(late.players[1].research.progress.taxation, server.players[1].research.progress.taxation, "progress restored")
        end
    }
}
