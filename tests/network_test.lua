local Host = require("src.server.host")
local T = require("tests.helpers")

local PORT = 6821

local function start(players)
    local host = Host({ address = "127.0.0.1", port = PORT })
    T.expect(host:Start(), "server failed to bind")
    local clients = {}
    for k = 1, players do clients[k] = T.client(string.char(64 + k), PORT) end
    T.waitFor(host, clients, function()
        for _, client in ipairs(clients) do if not client.id then return false end end
        return true
    end, "clients never got welcomed")
    clients[1]:send("create", { map = T.MAP, bots = 20, nations = true, difficulty = "hard" })
    T.waitFor(host, clients, function() return clients[1].roomInfo ~= nil end, "room not created")
    for k = 2, players do clients[k]:send("join", { id = clients[1].roomInfo.id }) end
    for k = 2, players do clients[k]:send("ready", { ready = true }) end
    T.waitFor(host, clients, function() return #clients[1].roomInfo.players == players and (players == 1 or clients[1].roomInfo.players[players].ready) end, "players did not join")
    clients[1]:send("start")
    T.waitFor(host, clients, function()
        for _, client in ipairs(clients) do if not client.game then return false end end
        return true
    end, "game did not start")
    local room = host.rooms[clients[1].roomInfo.id]
    return host, room, clients
end

return {
    {
        name = "clients follow the authoritative frames without desync",
        run = function()
            local host, room, clients = start(2)
            T.advance(host, room, clients, 300)
            for _, client in ipairs(clients) do
                T.equal(client.game.tick, room.game.tick, client.name .. " tick")
                T.expect(client.checks >= 29, client.name .. " verified too few hashes")
                T.equal(client.desyncs, 0, client.name .. " desyncs")
            end
            host:Stop()
        end
    },
    {
        name = "rejected intents are answered and tampered fields are ignored",
        run = function()
            local host, room, clients = start(1)
            T.advance(host, room, clients, 200)
            local a = clients[1]
            a:send("intent", { type = "spawn", tile = 0, seq = 1 })
            a:send("intent", { type = "attack", target = 0, ratio = 0.5, troops = 1e12, seq = 2 })
            T.advance(host, room, clients, 3)
            T.equal(a.rejected and a.rejected.seq, 1, "rejected sequence")
            local applied
            for _, message in ipairs(a.messages) do
                if message.kind == "frame" then
                    for _, intent in ipairs(message.data.c) do
                        if intent.seq == 2 then applied = intent end
                    end
                end
            end
            T.expect(applied, "the attack never came back in a frame")
            T.equal(applied.troops, nil, "troops field forwarded")
            T.equal(applied.player, a.slot, "attack player")
            host:Stop()
        end
    },
    {
        name = "a short disconnection is caught up with a burst of frames",
        run = function()
            local host, room, clients = start(2)
            local a, b = clients[1], clients[2]
            T.advance(host, room, clients, 150)
            local game = b.game
            b:disconnect()
            T.advance(host, room, { a }, 40)
            b.onWelcome = function(client) client:send("rejoin", { room = client.room, token = client.token, lastTick = client:lastContiguous() }) end
            b:reconnect()
            T.waitFor(host, clients, function() return b.resumed ~= nil end, "no resume message")
            T.advance(host, room, clients, 30)
            T.expect(b.game == game, "the client rebuilt its game")
            T.equal(b.game.tick, room.game.tick, "resumed tick")
            T.equal(b.desyncs, 0, "desyncs after resume")
            host:Stop()
        end
    },
    {
        name = "a resync or a rejoin without local state uses a snapshot",
        run = function()
            local host, room, clients = start(2)
            local a, b = clients[1], clients[2]
            T.advance(host, room, clients, 220)
            b:send("resync")
            T.waitFor(host, clients, function() return (b.snapshots or 0) == 1 end, "no snapshot for the resync")
            T.expect(b.snapshotOk, "resync snapshot checksum")
            local c = T.client("C", PORT)
            c.onWelcome = function(client) client:send("rejoin", { room = a.room, token = a.token }) end
            clients[#clients + 1] = c
            T.waitFor(host, clients, function() return c.game ~= nil and (c.snapshots or 0) == 1 end, "no snapshot for the rejoin")
            T.expect(c.snapshotOk, "rejoin snapshot checksum")
            T.advance(host, room, clients, 120)
            T.equal(c.game.tick, room.game.tick, "rejoined tick")
            T.equal(b.desyncs + c.desyncs, 0, "desyncs after snapshots")
            host:Stop()
        end
    }
}
