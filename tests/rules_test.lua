local Rules = require("src.modules.game.rules")
local Intents = require("src.net.intents")
local Codec = require("src.net.codec")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")
local Economy = require("src.modules.game.systems.economy")
local Spawn = require("src.modules.game.systems.spawn")
local Negotiator = require("src.modules.ai.negotiator")
local Coalitions = require("src.modules.game.systems.coalitions")
local Host = require("src.server.host")
local Config = require("src.config.game")
local T = require("tests.helpers")

local PORT = 6824

local function started(rules, options)
    local base = { bots = 0, nations = false, rules = rules, humans = { { name = "A" }, { name = "B" } } }
    for k, v in pairs(options or {}) do base[k] = v end
    local game = T.game(base)
    game.spawnTicksLeft = 1
    game:step()
    return game
end

return {
    {
        name = "rules are sanitized, presets win over raw values and the text form round-trips",
        run = function()
            T.equal(Rules.sanitize(nil).mode, "classic", "default mode")
            T.equal(Rules.sanitize({ mode = "unknown" }).mode, "classic", "unknown mode")
            T.equal(Rules.sanitize({ mode = "classic", winRatio = 0.5 }).winRatio, 0.8, "a preset ignores raw values")
            local blitz = Rules.sanitize({ mode = "blitz" })
            T.equal(blitz.winRatio, 0.6, "blitz ratio")
            T.equal(blitz.timeLimit, 20, "blitz limit")
            local custom = Rules.sanitize({ mode = "custom", winRatio = 0.123, startGold = 5000000, nukes = "no", income = 1e9 })
            T.equal(custom.winRatio, 0.8, "a value outside the list falls back")
            T.equal(custom.startGold, 5000000, "a listed value is kept")
            T.equal(custom.nukes, true, "a wrong type falls back")
            T.equal(custom.income, 1, "an absurd income falls back")
            T.equal(Rules.encode(Rules.decode(Rules.encode(custom))), Rules.encode(custom), "round trip")
            T.equal(Rules.decode("garbage;;=").mode, "classic", "garbage")
            T.equal(Rules.set(Rules.sanitize(nil), "nukes", false).mode, "conventional", "matches a preset")
            T.equal(Rules.set(Rules.sanitize(nil), "income", 2).mode, "custom", "goes custom")
            T.equal(Rules.set(Rules.set(Rules.sanitize(nil), "income", 2), "income", 1).mode, "classic", "back to classic")
        end
    },
    {
        name = "starting resources, spawn time and income follow the rules",
        run = function()
            local waiting = T.game({ bots = 0, nations = false, rules = { mode = "blitz" } })
            T.equal(waiting.spawnTicksTotal, 5 * Config.tickRate, "spawn time")
            local tile = waiting.map:findNear(waiting.map.width / 2, waiting.map.height / 2, 300, function(i) return waiting.map:isLand(i) end)
            Spawn.place(waiting, waiting.players[1], tile)
            T.equal(waiting.players[1].troops, Config.startTroops * 5, "troops")
            T.equal(waiting.players[1].workers, Config.startWorkers * 5, "workers")
            T.equal(waiting.players[1].gold, 1000000, "gold")
            local game = started({ mode = "blitz" })
            local classic = started(nil)
            local a, c = game.players[1], classic.players[1]
            local plain = T.game({ bots = 0, nations = false })
            Spawn.place(plain, plain.players[1], tile)
            T.equal(plain.players[1].gold, 0, "classic gold")
            local rate = Economy.goldRate(game, a)
            a.workers, a.tiles = c.workers, c.tiles
            a.administration = c.administration
            T.expect(math.abs(Economy.goldRate(game, a) - Economy.goldRate(classic, c) * 2) < 1e-9, "income")
            T.expect(rate > 0, "earns gold")
        end
    },
    {
        name = "the tutorial ignores the rules",
        run = function()
            local game = T.game({ bots = 0, nations = false, tutorial = true, rules = { mode = "blitz" } })
            T.equal(game.rules.mode, "classic", "classic rules")
        end
    },
    {
        name = "a game without nukes refuses silos, SAMs and launches, for the server and the AI",
        run = function()
            local game = started({ mode = "conventional" })
            local a = game.players[1]
            a.gold = 1e9
            local tile = next(a.borders)
            local ok, reason = Units.check(game, a, "silo", tile)
            T.expect(not ok and reason == "Nukes are disabled", "no silo")
            T.expect(not Units.check(game, a, "sam", tile), "no sam")
            local _, refused = Intents.sanitize(game, 1, { type = "build", unit = "silo", tile = tile })
            T.equal(refused, "Nukes are disabled", "the server refuses")
            _, reason = Nukes.check(game, a, "atom", tile)
            T.equal(reason, "Nukes are disabled", "no launch")
            T.expect(not Units.allowed(game, "silo") and Units.allowed(game, "city"), "only nuclear buildings are removed")

            local ai = T.game({ map = T.MAP, bots = 5, nations = true, rules = { mode = "conventional" }, authority = true, autoplay = true })
            for _, player in ipairs(ai.players) do if not player:isBot() then player.gold = 1e8 end end
            for _ = 1, 1000 do ai:step() end
            ai.tick = 4000
            for _, player in ipairs(ai.players) do
                T.equal(player:unitCount("silo"), 0, player.name .. " built no silo")
                if player:isNation() and player.alive then
                    T.expect(Negotiator.goal(ai, player, {}) ~= "silo", player.name .. " does not save for a silo")
                end
            end
        end
    },
    {
        name = "a game without diplomacy refuses alliances, pacts and coalitions",
        run = function()
            local game = started({ mode = "anarchy" })
            local a, b = game.players[1], game.players[2]
            local _, reason = Intents.sanitize(game, 1, { type = "allianceRequest", target = 2 })
            T.equal(reason, "Diplomacy is disabled", "alliance")
            _, reason = Intents.sanitize(game, 1, { type = "pactRequest", target = 2 })
            T.equal(reason, "Diplomacy is disabled", "pact")
            local ok
            ok, reason = Coalitions.canFound(game, a, "defense", b)
            T.expect(not ok and reason == "Diplomacy is disabled", "coalition")
            game:pushIntent({ type = "allianceRequest", player = 1, target = 2 })
            game:pushIntent({ type = "allianceReply", player = 2, from = 1, accept = true })
            game:step()
            T.expect(not a:isAlliedWith(b), "no alliance through the simulation")
        end
    },
    {
        name = "the win ratio and the time limit end the game",
        run = function()
            local game = started({ mode = "custom", winRatio = 0.5 })
            local a = game.players[1]
            local land, map = game.map.landCount, game.map
            local goal = math.floor(land * 0.5) + 2
            for i = 0, map.size - 1 do
                if a.tiles >= goal then break end
                if map:isLand(i) and map.owner[i] == 0 then game:setOwner(i, a.id) end
            end
            T.expect(a.tiles / land < Config.winRatio, "below the classic goal")
            for _ = 1, 20 do game:step() end
            T.equal(game.phase, "ended", "ended by the ratio")
            T.equal(game.winner, a, "winner")

            local timed = started({ mode = "custom", timeLimit = 10 })
            local b = timed.players[2]
            for i = 0, timed.map.size - 1 do
                if b.tiles >= 500 then break end
                if timed.map:isLand(i) and timed.map.owner[i] == 0 then timed:setOwner(i, b.id) end
            end
            timed.startedTick = timed.tick - 10 * 60 * Config.tickRate + 5
            for _ = 1, 20 do timed:step() end
            T.equal(timed.phase, "ended", "ended by the clock")
            T.equal(timed.winner, b, "the largest empire wins")
        end
    },
    {
        name = "the time limit makes the largest team win",
        run = function()
            local game = started({ mode = "custom", timeLimit = 10 }, { teams = 2, humans = { { name = "A", team = 1 }, { name = "B", team = 2 } } })
            local b = game.players[2]
            for i = 0, game.map.size - 1 do
                if b.tiles >= 500 then break end
                if game.map:isLand(i) and game.map.owner[i] == 0 then game:setOwner(i, b.id) end
            end
            game.startedTick = game.tick - 10 * 60 * Config.tickRate
            for _ = 1, 20 do game:step() end
            T.equal(game.winningTeam, 2, "largest team")
        end
    },
    {
        name = "the room sanitizes the rules and clients stay in sync with them",
        run = function()
            local host = Host({ address = "127.0.0.1", port = PORT })
            T.expect(host:Start(), "server failed to bind")
            local a, b = T.client("A", PORT), T.client("B", PORT)
            local clients = { a, b }
            T.waitFor(host, clients, function() return a.id and b.id end, "no welcome")
            a:send("create", { map = T.MAP, bots = 5, rules = { mode = "custom", startGold = 7, startArmy = 5 } })
            T.waitFor(host, clients, function() return a.roomInfo end, "no room")
            T.equal(a.roomInfo.settings.rules.startGold, 0, "an invalid value is dropped")
            T.equal(a.roomInfo.settings.rules.startArmy, 5, "a valid value is kept")
            b:send("join", { id = a.roomInfo.id })
            T.waitFor(host, clients, function() return #a.roomInfo.players == 2 end, "no join")
            T.equal(b.roomInfo.settings.rules.startArmy, 5, "the guest sees the rules")
            b:send("settings", { rules = { mode = "blitz" } })
            T.waitFor(host, clients, function() return b.error end, "guest edit refused")
            a:send("settings", { map = T.MAP, bots = 5, rules = { mode = "blitz" } })
            T.waitFor(host, clients, function() return b.roomInfo.settings.rules.mode == "blitz" end, "host edit not shared")
            b:send("ready", { ready = true })
            T.waitFor(host, clients, function() return a.roomInfo.players[2].ready end, "not ready")
            a:send("start")
            T.waitFor(host, clients, function() return a.game and b.game end, "no game")
            T.equal(b.game.rules.mode, "blitz", "client rules")
            local room = host.rooms[a.roomInfo.id]
            T.advance(host, room, clients, 120)
            T.equal(a.desyncs + b.desyncs, 0, "no desync")
            T.expect(a.checks > 0, "hashes were compared")
            host:Stop()
        end
    },
    {
        name = "rules survive the network codec",
        run = function()
            local rules = Rules.sanitize({ mode = "blitz" })
            local wire = Codec.decode(Codec.encode(rules))
            T.equal(Rules.encode(Rules.sanitize(wire)), Rules.encode(rules), "rules survive the codec")
        end
    }
}
