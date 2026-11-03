local Host = require("src.server.host")
local T = require("tests.helpers")

local PORT = 6823

local function finishedGame()
    local host = Host({ address = "127.0.0.1", port = PORT })
    T.expect(host:Start(), "server failed to bind")
    local a, b = T.client("A", PORT), T.client("B", PORT)
    local clients = { a, b }
    T.waitFor(host, clients, function() return a.id and b.id end, "clients never got welcomed")
    a:send("create", { map = T.MAP, bots = 0, nations = false })
    T.waitFor(host, clients, function() return a.roomInfo ~= nil end, "room not created")
    local id = a.roomInfo.id
    local room = host.rooms[id]
    b:send("join", { id = id })
    T.waitFor(host, clients, function() return a.roomInfo and #a.roomInfo.players == 2 end, "join failed")
    b:send("ready", { ready = true })
    T.waitFor(host, clients, function() return a.roomInfo.players[2].ready end, "not ready")
    a:send("start")
    T.waitFor(host, clients, function() return a.game and b.game end, "game not started")
    T.advance(host, room, clients, 170)
    a:send("intent", { type = "surrender", seq = 1 })
    for _ = 1, 200 do
        T.pump(host, clients, 0.1)
        love.timer.sleep(0.001)
        if room.state == "ended" then break end
    end
    T.equal(room.state, "ended", "room state")
    T.settle(host, clients)
    return host, room, a, b, clients
end

return {
    {
        name = "a rematch starts a fresh game once everyone in the room agrees",
        run = function()
            local host, room, a, b, clients = finishedGame()
            local first = a.started.seed
            local firstGame = room.game
            a:send("rematch", { vote = true })
            T.waitFor(host, clients, function() return b.rematch and b.rematch.votes == 1 end, "vote not shared")
            T.equal(b.rematch.total, 2, "voters")
            T.equal(room.state, "ended", "one vote is not enough")

            a:send("rematch", { vote = false })
            T.waitFor(host, clients, function() return b.rematch.votes == 0 end, "vote not cancelled")
            a:send("rematch", { vote = true })
            b:send("rematch", { vote = true })
            T.waitFor(host, clients, function() return room.state == "playing" end, "no rematch")
            T.settle(host, clients)
            T.expect(room.game ~= firstGame, "a new game")
            T.expect(a.started.seed ~= first, "a new seed")
            T.equal(a.started.seed, b.started.seed, "same seed for everyone")
            T.equal(a.game.tick, 0, "the clients start over")
            T.advance(host, room, clients, 30)
            T.equal(a.desyncs + b.desyncs, 0, "no desync in the rematch")
            T.expect(a.game.tick > 0 and a.game:checksum() == room.game:checksum(), "the clients follow the new game")
            host:Stop()
        end
    },
    {
        name = "a rematch starts when the last player who has not voted leaves",
        run = function()
            local host, room, a, b, clients = finishedGame()
            a:send("rematch", { vote = true })
            T.waitFor(host, clients, function() return a.rematch and a.rematch.votes == 1 end, "vote not counted")
            b:send("leave")
            T.waitFor(host, clients, function() return room.state == "playing" end, "no rematch")
            T.equal(#room.slots, 1, "only the voter plays")
            host:Stop()
        end
    },
    {
        name = "a rematch is refused while the game is running",
        run = function()
            local host = Host({ address = "127.0.0.1", port = PORT })
            T.expect(host:Start(), "server failed to bind")
            local a = T.client("A", PORT)
            local clients = { a }
            T.waitFor(host, clients, function() return a.id end, "client never got welcomed")
            a:send("create", { map = T.MAP, bots = 0, nations = false, autostart = true })
            T.waitFor(host, clients, function() return a.game end, "game not started")
            a:send("rematch", { vote = true })
            T.waitFor(host, clients, function() return a.error end, "no refusal")
            T.equal(a.error, "The game is not over", "refusal")
            host:Stop()
        end
    }
}
