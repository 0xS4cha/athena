local Codec = require("src.net.codec")
local Intents = require("src.net.intents")
local Snapshot = require("src.net.snapshot")
local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local T = require("tests.helpers")

local function started(options)
    local base = { bots = 0, nations = false, humans = { { name = "A" }, { name = "B" }, { name = "C" } } }
    for k, v in pairs(options or {}) do base[k] = v end
    local game = T.game(base)
    local map = game.map
    local spots = {}
    for k = 1, #base.humans do
        spots[k] = map:findNear(map.width * k / (#base.humans + 1), map.height / 2, 300, function(i) return map:isLand(i) and map.owner[i] == 0 end)
        game:pushIntent({ type = "spawn", player = k, tile = spots[k] })
    end
    for _ = 1, 160 do game:step() end
    return game, spots
end

local function ownedBy(game, id)
    local count = 0
    for i = 0, game.map.size - 1 do
        if game.map.owner[i] == id then count = count + 1 end
    end
    return count
end

return {
    {
        name = "surrendering frees the land, the buildings, the attacks and the ships",
        run = function()
            local game = started()
            local a, b = game.players[1], game.players[2]
            T.expect(a.alive and a.tiles > 0, "the player has land")
            local capital = a.capital
            T.expect(capital, "the player has a capital")
            game:pushIntent({ type = "attack", player = 1, target = 0, ratio = 0.5 })
            game:step()
            T.equal(#Attack.outgoing(game, a), 1, "attack launched")
            local tile = next(a.borders)
            local ship = Units.add(game, a, "warship", tile)

            game:pushIntent({ type = "surrender", player = 1 })
            game:step()
            T.expect(not a.alive, "the player is out")
            T.expect(a.surrendered, "the surrender is remembered")
            T.equal(a.tiles, 0, "tile counter")
            T.equal(ownedBy(game, a.id), 0, "no tile left on the map")
            T.expect(capital.dead, "the capital is gone")
            T.expect(ship.dead, "the ships are gone")
            T.equal(#Attack.outgoing(game, a), 0, "no attack left")
            T.expect(b.alive, "the others keep playing")
            T.equal(game.phase, "playing", "the game goes on")
        end
    },
    {
        name = "the server only accepts a surrender from a living player during the game",
        run = function()
            local waiting = T.game({ bots = 0, nations = false })
            local _, reason = Intents.sanitize(waiting, 1, { type = "surrender" })
            T.equal(reason, "Not now", "during the spawn phase")

            local game = started()
            local intent = T.expect(Intents.sanitize(game, 2, { type = "surrender", player = 1 }))
            T.equal(intent.player, 2, "only the sender can surrender")
            game:pushIntent(intent)
            game:step()
            T.expect(not game.players[2].alive and game.players[1].alive, "the sender surrendered")
            _, reason = Intents.sanitize(game, 2, { type = "surrender" })
            T.equal(reason, "Not now", "already out")
        end
    },
    {
        name = "the last player standing wins when the others surrender",
        run = function()
            local game = started()
            local winner = game.players[3]
            game:pushIntent({ type = "surrender", player = 1 })
            game:pushIntent({ type = "surrender", player = 2 })
            for _ = 1, 20 do game:step() end
            T.equal(game.phase, "ended", "the game is over")
            T.equal(game.winner, winner, "the survivor wins")
        end
    },
    {
        name = "a team goes on when one member surrenders",
        run = function()
            local game = started({ teams = 2, humans = { { name = "A", team = 1 }, { name = "B", team = 1 }, { name = "C", team = 2 } } })
            game:pushIntent({ type = "surrender", player = 1 })
            for _ = 1, 20 do game:step() end
            T.equal(game.phase, "playing", "the teammate still fights")
            game:pushIntent({ type = "surrender", player = 2 })
            for _ = 1, 20 do game:step() end
            T.equal(game.phase, "ended", "the team fell")
            T.equal(game.winningTeam, 2, "the other team wins")
        end
    },
    {
        name = "a surrender stays deterministic and survives a snapshot",
        run = function()
            local humans = { { name = "A" }, { name = "B" }, { name = "C" } }
            local server = T.game({ bots = 10, nations = true, humans = humans, authority = true })
            local client = T.game({ bots = 10, nations = true, humans = humans, authority = false })
            local queue = {}
            server.commandSink = function(intent) queue[#queue + 1] = intent end
            for _ = 1, 400 do
                if server.tick == 250 then queue[#queue + 1] = { type = "surrender", player = 1 } end
                local commands = queue
                queue = {}
                local wire = Codec.decode(Codec.encode(commands))
                for _, intent in ipairs(commands) do server:pushIntent(intent) end
                for _, intent in ipairs(wire) do client:pushIntent(intent) end
                server:step()
                client:step()
                T.equal(client:checksum(), server:checksum(), "state at tick " .. server.tick)
            end
            T.expect(server.players[1].surrendered, "the surrender was applied")
            local restored = T.game({ bots = 10, nations = true, humans = humans, authority = false })
            T.applySnapshot(restored, Snapshot.encode(server))
            T.expect(restored.players[1].surrendered, "the snapshot keeps the surrender")
        end
    }
}
