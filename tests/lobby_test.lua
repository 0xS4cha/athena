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
    },
    {
        name = "chat history, sanitizing, rate limit and ally messages",
        run = function()
            local host, clients = connect({ "A", "B", "C" })
            local a, b, c = clients[1], clients[2], clients[3]
            local function count(client) return #(client.chats or {}) end
            local function last(client) return client.chats[#client.chats] end

            a:send("create", { map = T.MAP, bots = 5 })
            T.waitFor(host, clients, function() return a.roomInfo ~= nil end, "room not created")
            local id = a.roomInfo.id
            a:send("chat", { text = "hello" })
            T.waitFor(host, clients, function() return count(a) == 1 end, "chat not echoed to the sender")
            T.equal(last(a).name, "A", "sender name")

            b:send("join", { id = id })
            c:send("join", { id = id })
            T.waitFor(host, clients, function() return b.chatlog ~= nil and c.chatlog ~= nil end, "no chat history on join")
            T.equal(#b.chatlog, 1, "history size")
            T.equal(b.chatlog[1].text, "hello", "history text")

            b:send("chat", { text = "  hi\nthere  " })
            T.waitFor(host, clients, function() return count(c) == 1 end, "chat not broadcast")
            T.equal(last(c).text, "hi there", "control characters and spaces")
            b:send("chat", { text = "bad \255 byte" })
            b:send("chat", { text = "   " })
            b:send("chat", { text = string.rep("é", 300) })
            T.waitFor(host, clients, function() return count(c) == 2 end, "long message not delivered")
            T.equal(last(c).text, string.rep("é", 160), "message trimmed to 160 characters")

            for k = 1, 3 do b:send("chat", { text = "spam " .. k }) end
            T.waitFor(host, clients, function() return count(c) == 5 end, "burst refused too early")
            b.error = nil
            b:send("chat", { text = "one too many" })
            T.waitFor(host, clients, function() return b.error ~= nil end, "rate limit not enforced")
            T.equal(b.error, "You are sending messages too fast", "rate limit error")
            T.equal(count(c), 5, "rate limited message delivered")

            b:send("ready", { ready = true })
            c:send("ready", { ready = true })
            T.waitFor(host, clients, function()
                local players = a.roomInfo.players
                return players[2] and players[2].ready and players[3] and players[3].ready
            end, "players not ready")
            a:send("start")
            T.waitFor(host, clients, function() return b.game ~= nil and c.game ~= nil end, "game did not start")

            local before = { count(a), count(b), count(c) }
            a:send("chat", { text = "alone", scope = "allies" })
            T.waitFor(host, clients, function() return count(a) == before[1] + 1 end, "ally message not echoed")
            T.equal(last(a).scope, "allies", "ally scope")
            T.settle(host, clients)
            T.equal(count(b), before[2], "ally message leaked without alliance")

            local game = host.rooms[id].game
            local pa, pb = game.players[a.slot], game.players[b.slot]
            pa.allies[pb.id] = true
            pb.allies[pa.id] = true
            a:send("chat", { text = "attack north", scope = "allies" })
            T.waitFor(host, clients, function() return count(b) == before[2] + 1 end, "ally message not delivered")
            T.equal(last(b).text, "attack north", "ally message text")
            T.settle(host, clients)
            T.equal(count(c), before[3], "ally message leaked to a non ally")
            host:Stop()
        end
    }
}
