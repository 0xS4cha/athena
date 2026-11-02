local Config = require("src.config.game")
local Teams = require("src.modules.game.systems.teams")
local Diplomacy = require("src.modules.game.systems.diplomacy")
local Coalitions = require("src.modules.game.systems.coalitions")
local Nukes = require("src.modules.game.systems.nukes")
local Victory = require("src.modules.game.systems.victory")
local Intents = require("src.net.intents")
local Snapshot = require("src.net.snapshot")
local Host = require("src.server.host")
local T = require("tests.helpers")

local function duel(options)
    local base = {
        bots = 0, nations = false, teams = 2,
        humans = { { name = "A", team = 1 }, { name = "B", team = 1 }, { name = "C", team = 2 }, { name = "D", team = 2 } }
    }
    for k, v in pairs(options or {}) do base[k] = v end
    local game = T.game(base)
    for _ = 1, 160 do game:step() end
    return game, game.players[1], game.players[2], game.players[3], game.players[4]
end

return {
    {
        name = "teams keep the chosen sides, balance the nations and leave the tribes out",
        run = function()
            local game = T.game({ bots = 10, teams = 2, humans = { { name = "A", team = 2 }, { name = "B" } } })
            T.equal(game.players[1].team, 2, "chosen team")
            T.equal(game.players[2].team, 1, "the undecided player fills the smallest team")
            local sizes = { 0, 0 }
            for _, player in ipairs(game.players) do
                if player:isBot() then
                    T.equal(player.team, nil, "tribes have no team")
                elseif player.alive then
                    sizes[player.team] = sizes[player.team] + 1
                end
            end
            T.expect(sizes[1] > 1, "the first team has nations")
            T.expect(math.abs(sizes[1] - sizes[2]) <= 1, "teams are balanced")
        end
    },
    {
        name = "free for all games have no team at all",
        run = function()
            local game = T.game({ bots = 0, teams = 5 })
            T.equal(game.teamCount, 0, "an invalid mode is ignored")
            for _, player in ipairs(game.players) do
                T.equal(player.team, nil, "no team")
            end
            T.equal(T.game({ bots = 0, nations = false, teams = 2, tutorial = true }).teamCount, 0, "no team in the tutorial")
        end
    },
    {
        name = "teammates stay allied for the whole game and cannot betray each other",
        run = function()
            local game, a, b, c = duel()
            T.expect(a:isAlliedWith(b), "teammates are allied")
            T.expect(not a:isAlliedWith(c), "enemies are not allied")
            T.expect(not a:canAttack(b), "teammates cannot attack each other")
            a.allies[b.id] = game.tick
            b.allies[a.id] = game.tick
            for _ = 1, 20 do game:step() end
            T.expect(a:isAlliedWith(b), "the alliance is renewed")
            Diplomacy.betray(game, a, b)
            T.expect(a:isAlliedWith(b), "no betrayal")
            T.equal(a.traitorUntil, -1, "not a traitor")
            local _, reason = Intents.sanitize(game, a.id, { type = "allianceBreak", target = b.id })
            T.equal(reason, "Teammate", "break refused by the server")
        end
    },
    {
        name = "teams are fixed: no alliance, pact or coalition across them",
        run = function()
            local game, a, _, c = duel()
            Diplomacy.request(game, a, c)
            T.equal(c.allianceRequests[a.id], nil, "no alliance request")
            Diplomacy.requestPact(game, a, c)
            T.equal(c.pactRequests[a.id], nil, "no pact request")
            local _, reason = Intents.sanitize(game, a.id, { type = "allianceRequest", target = c.id })
            T.equal(reason, "Teams are fixed", "alliance refused by the server")
            _, reason = Intents.sanitize(game, a.id, { type = "pactRequest", target = c.id })
            T.equal(reason, "Teams are fixed", "pact refused by the server")
            _, reason = Coalitions.canFound(game, a, "war", c)
            T.equal(reason, "Team game", "no coalition")
        end
    },
    {
        name = "nukes cannot target a teammate",
        run = function()
            local game, a, b, c = duel()
            a.unitCounts.silo = 1
            local silo = { kind = "silo", owner = a, buildLeft = 0, cooldown = 0, x = 0, y = 0 }
            game.units[#game.units + 1] = silo
            a.gold = Config.nukes.atom.cost
            local _, reason = Nukes.check(game, a, "atom", b.spawnTile)
            T.equal(reason, "Teammate", "teammate")
            T.equal(select(2, Nukes.check(game, a, "atom", c.spawnTile)) ~= "Teammate", true, "enemy")
        end
    },
    {
        name = "a team wins with the combined land of its members",
        run = function()
            local game, a, b, c = duel({ localSlot = 2 })
            local land = game.map.landCount
            local standings = Teams.standings(game)
            T.equal(standings[1].tiles, a.tiles + b.tiles, "combined land")
            local count, goal = 0, math.floor(land * Config.winRatio) + 2
            for tile = 0, game.map.size - 1 do
                if game.map:isLand(tile) and game.map.owner[tile] == 0 then
                    game:setOwner(tile, count % 2 == 0 and a.id or b.id)
                    count = count + 1
                    if count >= goal then break end
                end
            end
            T.expect(a.tiles / land < Config.winRatio, "no single player reached the goal")
            for _ = 1, Config.victoryCheckTicks + 1 do game:step() end
            T.equal(game.phase, "ended", "the game ended")
            T.equal(game.winningTeam, 1, "winning team")
            T.expect(Victory.won(game, b), "every member wins")
            T.expect(not Victory.won(game, c), "the enemies lose")
        end
    },
    {
        name = "the last team standing wins even if tribes remain",
        run = function()
            local game, a, _, c, d = duel({ bots = 5 })
            game:eliminate(c)
            game:eliminate(d)
            for _ = 1, Config.victoryCheckTicks + 1 do game:step() end
            T.equal(game.phase, "ended", "the game ended")
            T.equal(game.winningTeam, 1, "winning team")
            T.equal(game.winner.team, a.team, "the winner belongs to the team")
        end
    },
    {
        name = "team games stay deterministic through the AI and snapshots",
        run = function()
            local server = T.game({ authority = true, autoplay = true, teams = 3, bots = 10, seed = 7 })
            local client = T.game({ authority = false, localSlot = 1, teams = 3, bots = 10, seed = 7 })
            T.equal(server.teamCount, 3, "team count")
            local commands = {}
            server.commandSink = function(intent) commands[#commands + 1] = intent end
            for _ = 1, 500 do
                local batch = commands
                commands = {}
                for _, intent in ipairs(batch) do
                    server:pushIntent(intent)
                    client:pushIntent(intent)
                end
                server:step()
                client:step()
            end
            T.equal(client:checksum(), server:checksum(), "client checksum")
            for _, player in ipairs(server.players) do
                T.equal(client.players[player.id].team, player.team, "same team on the client")
                for _, other in ipairs(server.players) do
                    if player:isTeammate(other) and player.alive and other.alive then
                        T.expect(player:isAlliedWith(other), "teammates stay allied under AI control")
                    end
                end
            end
            local restored = T.game({ authority = false, localSlot = 2, teams = 3, bots = 10, seed = 7 })
            local _, expected = T.applySnapshot(restored, Snapshot.encode(server))
            T.equal(restored:checksum(), expected, "snapshot checksum")
            T.equal(restored.teamCount, 3, "team count after a snapshot")
            T.equal(restored.players[1].team, server.players[1].team, "team after a snapshot")
        end
    },
    {
        name = "the lobby sets the mode and lets players pick a side",
        run = function()
            local host = Host({ address = "127.0.0.1", port = 6878 })
            T.expect(host:Start(), "server failed to bind")
            local a, b = T.client("A", 6878), T.client("B", 6878)
            local clients = { a, b }
            T.waitFor(host, clients, function() return a.id and b.id end, "clients never got welcomed")
            a:send("create", { map = T.MAP, bots = 0, nations = false, teams = 2 })
            T.waitFor(host, clients, function() return a.roomInfo ~= nil end, "room not created")
            T.equal(a.roomInfo.settings.teams, 2, "team mode")
            b:send("join", { id = a.roomInfo.id })
            T.waitFor(host, clients, function() return #a.roomInfo.players == 2 end, "no join")

            a:send("profile", { team = 2 })
            b:send("profile", { team = 9 })
            T.waitFor(host, clients, function() return a.roomInfo.players[1].team == 2 end, "team not picked")
            T.equal(a.roomInfo.players[2].team, nil, "an invalid team is ignored")

            a:send("settings", { map = T.MAP, bots = 0, nations = false, teams = 7 })
            T.waitFor(host, clients, function() return a.roomInfo.settings.teams == 0 end, "invalid mode kept")
            T.equal(a.roomInfo.players[1].team, nil, "picks are cleared when the mode shrinks")

            a:send("settings", { map = T.MAP, bots = 0, nations = false, teams = 2 })
            T.waitFor(host, clients, function() return a.roomInfo.settings.teams == 2 end, "mode not restored")
            a:send("profile", { team = 2 })
            T.waitFor(host, clients, function() return a.roomInfo.players[1].team == 2 end, "team not picked again")
            b:send("ready", { ready = true })
            T.waitFor(host, clients, function() return a.roomInfo.players[2].ready end, "not ready")
            a:send("start")
            T.waitFor(host, clients, function() return a.game ~= nil and b.game ~= nil end, "game did not start")
            T.equal(a.game.players[1].team, 2, "picked team in game")
            T.equal(b.game.players[2].team, 1, "the other player fills the other team")
            T.equal(b.game.players[1].team, 2, "same teams on every client")
            host:Stop()
        end
    }
}
