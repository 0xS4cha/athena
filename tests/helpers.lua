local enet = require("enet")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local Snapshot = require("src.net.snapshot")
local Palette = require("src.modules.player.palette")
local Game = require("src.modules.game.game")

local Helpers = {}

Helpers.MAP = "assets/maps/italia/"

function Helpers.expect(value, message)
    if not value then error(message or "expectation failed", 2) end
    return value
end

function Helpers.equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

function Helpers.game(options)
    local base = {
        map = Helpers.MAP, bots = 30, nations = true, difficulty = "hard", seed = 42,
        humans = { { name = "A" }, { name = "B" } }, headless = true
    }
    for k, v in pairs(options or {}) do base[k] = v end
    return Game(base)
end

function Helpers.colorFor(player)
    return Palette.color(player.id)
end

function Helpers.applySnapshot(game, data)
    return Snapshot.apply(game, data, Helpers.colorFor)
end

local Client = {}
Client.__index = Client

function Helpers.client(name, port)
    local client = setmetatable({ name = name, port = port, host = enet.host_create(), messages = {}, frames = {}, checks = 0, desyncs = 0 }, Client)
    client.peer = client.host:connect("127.0.0.1:" .. port, NetConfig.channels)
    return client
end

function Client:send(kind, data)
    self.peer:send(Protocol.Encode(kind, data), 0, "reliable")
end

function Client:reconnect()
    self.host = enet.host_create()
    self.peer = self.host:connect("127.0.0.1:" .. self.port, NetConfig.channels)
end

function Client:disconnect()
    self.peer:disconnect_now()
    self.host:flush()
end

function Client:build(data)
    local s = data.settings
    self.slot, self.token, self.room = data.slot, data.token, data.room
    self.game = Game({
        map = s.map, bots = s.bots, nations = s.nations, difficulty = s.difficulty, seed = data.seed,
        humans = data.players, localSlot = data.slot, authority = false, headless = true
    })
    self.frames = {}
    if data.snapshot then self:applySnapshot(data.tick, data.snapshot) end
end

function Client:applySnapshot(tick, data)
    local restored, expected = Helpers.applySnapshot(self.game, data)
    for t in pairs(self.frames) do
        if t < restored then self.frames[t] = nil end
    end
    self.snapshots = (self.snapshots or 0) + 1
    self.snapshotOk = self.game:checksum() == expected
end

function Client:handle(kind, data)
    self.messages[#self.messages + 1] = { kind = kind, data = data }
    if kind == "welcome" then
        self.id = data.id
        if self.onWelcome then self.onWelcome(self) end
    elseif kind == "room" then
        self.roomInfo = data
    elseif kind == "rooms" then
        self.rooms = data.rooms
    elseif kind == "error" then
        self.error = data.message
    elseif kind == "start" then
        self.started = data
        self:build(data)
    elseif kind == "resume" then
        self.resumed = data
    elseif kind == "sync" then
        self:applySnapshot(data.tick, data.snapshot)
    elseif kind == "frame" then
        self.frames[data.t] = data
    elseif kind == "reject" then
        self.rejected = data
    elseif kind == "kicked" then
        self.kicked = true
        self.roomInfo = nil
    end
end

function Client:poll()
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            self:send("hello", { name = self.name, version = NetConfig.version })
        elseif event.type == "receive" then
            local kind, data = Protocol.Decode(event.data)
            if kind then self:handle(kind, data or {}) end
        end
        event = self.host:service(0)
    end
end

function Client:simulate()
    local game = self.game
    if not game then return end
    while self.frames[game.tick] do
        local frame = self.frames[game.tick]
        self.frames[game.tick] = nil
        for _, intent in ipairs(frame.c) do
            game:pushIntent(intent)
        end
        game:step()
        if frame.h then
            self.checks = self.checks + 1
            if game:checksum() ~= frame.h then
                self.desyncs = self.desyncs + 1
            end
        end
    end
end

function Client:lastContiguous()
    local t = self.game.tick
    while self.frames[t] do t = t + 1 end
    return t - 1
end

function Helpers.pump(host, clients, dt, rounds)
    for _ = 1, rounds or 1 do
        host:Think(dt or 0)
        for _, client in ipairs(clients) do
            client:poll()
            client:simulate()
        end
    end
end

function Helpers.settle(host, clients, rounds)
    for _ = 1, rounds or 30 do
        Helpers.pump(host, clients, 0)
        love.timer.sleep(0.002)
    end
end

function Helpers.advance(host, room, clients, ticks)
    local target = room.game.tick + ticks
    local guard = 0
    while room.game.tick < target do
        Helpers.pump(host, clients, 1 / NetConfig.tickRate)
        guard = guard + 1
        if guard > ticks * 4 then error("server did not advance") end
    end
    Helpers.settle(host, clients, 20)
end

function Helpers.waitFor(host, clients, predicate, message)
    for _ = 1, 400 do
        if predicate() then return end
        Helpers.pump(host, clients, 0)
        love.timer.sleep(0.002)
    end
    error(message or "timed out", 2)
end

return Helpers
