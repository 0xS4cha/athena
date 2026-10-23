local Host = require("src.server.host")
local Palette = require("src.modules.player.palette")
local T = require("tests.helpers")

local PORT = 6822

local function connect(names)
    local host = Host({ address = "127.0.0.1", port = PORT })
    T.expect(host:Start(), "server failed to bind")
    local clients = {}
    for k, name in ipairs(names) do clients[k] = T.client(name, PORT) end
    T.waitFor(host, clients, function()
        for _, client in ipairs(clients) do if not client.id then return false end end
        return true
    end, "clients never got welcomed")
    return host, clients
end

return {
    {
        name = "password, colors, kick and ready checks",
        run = function()
            local host, clients = connect({ "A", "B", "C" })
            local a, b, c = clients[1], clients[2], clients[3]
            a:send("create", { map = T.MAP, bots = 5, password = "secret" })
            T.waitFor(host, clients, function() return a.roomInfo ~= nil end, "room not created")
            local id = a.roomInfo.id
            a:send("profile", { color = 3, flag = "fr" })
            b:send("rooms")
            T.waitFor(host, clients, function() return b.rooms ~= nil end, "no room list")
            T.expect(b.rooms[1].locked, "room should be locked")

            b:send("join", { id = id })
            T.waitFor(host, clients, function() return b.error ~= nil end, "no error for a missing password")
            T.equal(b.error, "Wrong password", "join without password")
            b.error = nil
            b:send("join", { id = id, password = "secret" })
            T.waitFor(host, clients, function() return b.roomInfo ~= nil end, "join with password failed")

            b:send("profile", { color = 3 })
            T.waitFor(host, clients, function() return b.error ~= nil end, "taken color accepted")
            T.equal(b.error, "This color is already taken", "taken color")
            b:send("profile", { color = 5, flag = "jp" })

            c:send("join", { id = id, password = "secret" })
            T.waitFor(host, clients, function() return a.roomInfo and #a.roomInfo.players == 3 end, "third player did not join")
            a:send("kick", { id = c.id })
            T.waitFor(host, clients, function() return c.kicked end, "kick not delivered")

            a.error = nil
            a:send("start")
            T.waitFor(host, clients, function() return a.error ~= nil end, "started without ready players")
            T.equal(a.error, "Waiting for every player to be ready", "start before ready")
            b:send("ready", { ready = true })
            T.waitFor(host, clients, function() return a.roomInfo.players[2] and a.roomInfo.players[2].ready end, "ready not broadcast")
            a:send("start")
            T.waitFor(host, clients, function() return b.game ~= nil end, "game did not start")

            local players = b.game.players
            T.expect(players[1].color == Palette.choices[3], "host color in game")
            T.expect(players[2].color == Palette.choices[5], "guest color in game")
            T.equal(players[1].flag, "fr", "host flag")
            T.equal(players[2].flag, "jp", "guest flag")
            host:Stop()
        end
    }
}
