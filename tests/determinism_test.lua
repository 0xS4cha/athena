local Codec = require("src.net.codec")
local Snapshot = require("src.net.snapshot")
local T = require("tests.helpers")

local TICKS = 700
local SNAPSHOTS = { [250] = true, [500] = true }

return {
    {
        name = "server, client and snapshot-restored clients stay in sync",
        run = function()
            local server = T.game({ authority = true, autoplay = true })
            local queue = {}
            server.commandSink = function(intent) queue[#queue + 1] = intent end
            local client = T.game({ authority = false, localSlot = 1 })
            local restored = {}
            local function advance(game, commands)
                for _, intent in ipairs(commands) do game:pushIntent(intent) end
                game:step()
            end
            local commandCount = 0
            for _ = 1, TICKS do
                local commands = queue
                queue = {}
                commandCount = commandCount + #commands
                local wire = Codec.decode(Codec.encode(commands))
                advance(server, commands)
                advance(client, wire)
                for _, game in ipairs(restored) do advance(game, wire) end
                local expected = server:checksum()
                T.equal(client:checksum(), expected, "client checksum at tick " .. server.tick)
                for k, game in ipairs(restored) do
                    T.equal(game:checksum(), expected, "restored client " .. k .. " checksum at tick " .. server.tick)
                end
                if SNAPSHOTS[server.tick] then
                    local game = T.game({ authority = false, localSlot = 2 })
                    local tick, checksum = T.applySnapshot(game, Snapshot.encode(server))
                    T.equal(tick, server.tick, "snapshot tick")
                    T.equal(game:checksum(), checksum, "checksum right after restore")
                    restored[#restored + 1] = game
                end
            end
            T.expect(commandCount > 0, "the server AI issued no command")
            T.equal(#restored, 2, "restored clients")
        end
    },
    {
        name = "the AI only runs on the authority",
        run = function()
            local client = T.game({ authority = false, autoplay = true })
            local issued = 0
            client.commandSink = function() issued = issued + 1 end
            for _ = 1, 400 do client:step() end
            T.equal(issued, 0, "commands issued by a client")
        end
    },
    {
        name = "snapshots rebuild borders and keep the stats history",
        run = function()
            local server = T.game({ authority = true, autoplay = true })
            for _ = 1, 400 do server:step() end
            local game = T.game({ authority = false, localSlot = 1 })
            T.applySnapshot(game, Snapshot.encode(server))
            for id, player in ipairs(server.players) do
                local count, expected = 0, 0
                for _ in pairs(game.players[id].borders) do count = count + 1 end
                for _ in pairs(player.borders) do expected = expected + 1 end
                T.equal(count, expected, "border tiles of player " .. id)
            end
            T.equal(#game.history.ticks, #server.history.ticks, "history samples")
        end
    }
}
