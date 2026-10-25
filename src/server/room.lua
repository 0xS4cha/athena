local Class = require("src.core.class")
local UUID = require("src.core.uuid")
local Protocol = require("src.net.protocol")
local Config = require("src.net.config")
local GameConfig = require("src.config.game")
local Intents = require("src.net.intents")
local Snapshot = require("src.net.snapshot")
local Game = require("src.modules.game.game")
local Text = require("src.core.text")

local Room = Class()

local DIFFICULTIES = { easy = true, medium = true, hard = true }
local DEFAULT_MAP = GameConfig.defaultMap
local COLORS = #require("src.modules.player.palette").choices

local function password(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value:sub(1, 24)
end
local RESYNC_COOLDOWN = 5

local function sanitize(settings)
    settings = type(settings) == "table" and settings or {}
    local bots = tonumber(settings.bots) or 0
    local map = type(settings.map) == "string" and settings.map:match("^assets/maps/[%w_%-]+/$")
    if map and not love.filesystem.getInfo(map .. "map.bin") then
        map = nil
    end
    return {
        map = map or DEFAULT_MAP,
        bots = math.max(0, math.min(400, math.floor(bots))),
        nations = settings.nations ~= false,
        difficulty = DIFFICULTIES[settings.difficulty] and settings.difficulty or "medium",
        autoplay = settings.autoplay == true,
        tutorial = settings.tutorial == true
    }
end

function Room:init(id, host, settings)
    self.id = id
    self.name = type(settings) == "table" and type(settings.name) == "string" and settings.name:sub(1, 32) or (host.name .. "'s game")
    self.settings = sanitize(settings)
    self.password = type(settings) == "table" and password(settings.password) or nil
    self.host = host
    self.members = {}
    self.slots = {}
    self.state = "lobby"
    self.seed = nil
    self.game = nil
    self.pending = {}
    self.commands = {}
    self.frames = {}
    self.snapshot = nil
    self.paused = false
    self.speedIndex = 1
    self.accumulator = 0
    self.emptySince = nil
    self.chat = {}
end

function Room:Summary()
    return {
        id = self.id,
        name = self.name,
        state = self.state,
        map = self.settings.map,
        players = #self.members,
        max = Config.maxRoomPlayers,
        locked = self.password ~= nil
    }
end

function Room:Info()
    local players = {}
    for _, client in ipairs(self.members) do
        players[#players + 1] = { id = client.id, name = client.name, ready = client.ready == true, color = client.color, flag = client.flag }
    end
    return {
        id = self.id,
        name = self.name,
        state = self.state,
        host = self.host and self.host.id,
        settings = self.settings,
        players = players,
        max = Config.maxRoomPlayers,
        locked = self.password ~= nil
    }
end

function Room:BroadcastPings()
    if #self.members == 0 then return end
    local pings = {}
    for _, client in ipairs(self.members) do
        pings[#pings + 1] = { id = client.id, slot = client.slot, ping = client:Ping() }
    end
    self:Broadcast("pings", { pings = pings })
end

function Room:Tick()
    return self.game and self.game.tick or 0
end

function Room:Broadcast(kind, data)
    local raw = Protocol.Encode(kind, data)
    for _, client in ipairs(self.members) do
        client:SendRaw(raw)
    end
end

function Room:attach(client)
    self.members[#self.members + 1] = client
    client.room = self
    self.emptySince = nil
    client:Send("chatlog", { messages = self.chat })
end

function Room:Chat(client, data)
    if type(data) ~= "table" then return end
    local text = Text.clean(data.text, Config.chatLength)
    if not text or text == "" then return end
    local now = love.timer.getTime()
    local recent = {}
    for _, at in ipairs(client.chatTimes or {}) do
        if now - at < Config.chatWindow then recent[#recent + 1] = at end
    end
    client.chatTimes = recent
    if #recent >= Config.chatBurst then
        client:Send("error", { message = "You are sending messages too fast" })
        return
    end
    recent[#recent + 1] = now
    local sender = self.game and client.slot and self.game.players[client.slot]
    local allies = data.scope == "allies" and sender ~= nil
    local message = {
        id = client.id,
        slot = sender and client.slot or nil,
        name = client.name,
        color = client.color,
        text = text,
        scope = allies and "allies" or "all"
    }
    if not allies then
        self.chat[#self.chat + 1] = message
        if #self.chat > Config.chatHistory then
            table.remove(self.chat, 1)
        end
        self:Broadcast("chat", message)
        return
    end
    local raw = Protocol.Encode("chat", message)
    for _, member in ipairs(self.members) do
        local player = member.slot and self.game.players[member.slot]
        if player and sender:isFriendly(player) then
            member:SendRaw(raw)
        end
    end
end

function Room:Add(client, given)
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    if #self.members >= Config.maxRoomPlayers then
        return false, "Room is full"
    end
    if self.password and given ~= self.password and client ~= self.host then
        return false, "Wrong password"
    end
    client.ready = false
    if client.color and self:colorTaken(client.color, client) then
        client.color = nil
    end
    self:attach(client)
    self:Broadcast("room", self:Info())
    return true
end

function Room:colorTaken(color, except)
    for _, member in ipairs(self.members) do
        if member ~= except and member.color == color then return true end
    end
    return false
end

function Room:Profile(client, data)
    if self.state ~= "lobby" or type(data) ~= "table" then return false end
    local color = tonumber(data.color)
    if color then
        color = math.floor(color)
        if color < 1 or color > COLORS then
            color = nil
        elseif self:colorTaken(color, client) then
            return false, "This color is already taken"
        end
    end
    local flag = type(data.flag) == "string" and data.flag:lower():sub(1, 32) or ""
    client.color = color
    client.flag = flag:match("^[%w%-]+$") and flag or nil
    self:Broadcast("room", self:Info())
    return true
end

function Room:SetReady(client, ready)
    if self.state ~= "lobby" then return end
    client.ready = ready == true
    self:Broadcast("room", self:Info())
end

function Room:Kick(client, id)
    if client ~= self.host then
        return false, "Only the host can kick players"
    end
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    for _, member in ipairs(self.members) do
        if member.id == id and member ~= client then
            self:Remove(member)
            member:Send("kicked", { room = self.id })
            Logger:info("room", string.format("Room %s host kicked %s", self.id, tostring(member.name)))
            return true
        end
    end
    return false, "Player not found"
end

function Room:Remove(client)
    for k, member in ipairs(self.members) do
        if member == client then
            table.remove(self.members, k)
            break
        end
    end
    client.room = nil
    client.synced = false
    if self.host == client then
        self.host = self.members[1]
    end
    if #self.members == 0 then
        self.emptySince = love.timer.getTime()
    end
    if self.state == "lobby" then
        self:Broadcast("room", self:Info())
    elseif client.slot then
        self.slots[client.slot].client = nil
        if self.state == "playing" then
            self.pending[#self.pending + 1] = { type = "disconnect", player = client.slot }
        end
        if self.paused and #self.members == 0 then
            self.paused = false
        end
    end
    client.slot = nil
end

function Room:Expired(now)
    if #self.members > 0 then return false end
    if self.state == "lobby" then return true end
    local limit = #self.slots <= 1 and Config.soloEmptySeconds or Config.emptyRoomSeconds
    return self.state == "ended" or now - (self.emptySince or now) > limit
end

function Room:Configure(client, settings)
    if client ~= self.host then
        return false, "Only the host can change the settings"
    end
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    self.settings = sanitize(settings)
    self:Broadcast("room", self:Info())
    return true
end

function Room:players()
    local players = {}
    for slot, entry in ipairs(self.slots) do
        players[slot] = { name = entry.name, color = entry.color, flag = entry.flag }
    end
    return players
end

function Room:controls()
    return { paused = self.paused, speed = self.speedIndex, solo = #self.slots == 1 }
end

function Room:startMessage(client, snapshot)
    local entry = self.slots[client.slot]
    return {
        room = self.id,
        seed = self.seed,
        settings = self.settings,
        players = self:players(),
        slot = client.slot,
        token = entry.token,
        hashTicks = Config.hashTicks,
        controls = self:controls(),
        tick = snapshot and snapshot.tick or 0,
        snapshot = snapshot and snapshot.data or nil
    }
end

function Room:latestSnapshot()
    local tick = self:Tick()
    local cached = self.snapshot
    if cached and tick - cached.tick < Config.snapshotTicks and self.frames[cached.tick % Config.frameHistory] then
        return cached
    end
    local started = love.timer.getTime()
    local data = Snapshot.encode(self.game)
    self.snapshot = { tick = tick, data = data }
    Logger:info("room", string.format("Room %s snapshot at tick %d: %d bytes in %.1f ms", self.id, tick, #data, (love.timer.getTime() - started) * 1000))
    return self.snapshot
end

function Room:hasFrames(from)
    local tick = self:Tick()
    if from > tick then return false end
    if tick - from > Config.frameHistory then return false end
    for t = from, tick - 1 do
        local entry = self.frames[t % Config.frameHistory]
        if not entry or entry.tick ~= t then return false end
    end
    return true
end

function Room:sendFrames(client, from)
    for t = from, self:Tick() - 1 do
        client:SendRaw(self.frames[t % Config.frameHistory].raw)
    end
end

function Room:sendStart(client, withSnapshot)
    local snapshot = withSnapshot and self:Tick() > 0 and self:latestSnapshot() or nil
    client:Send("start", self:startMessage(client, snapshot))
    self:sendFrames(client, snapshot and snapshot.tick or 0)
    client.synced = true
end

function Room:Start(client)
    if client ~= self.host then
        return false, "Only the host can start the game"
    end
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    for _, member in ipairs(self.members) do
        if member ~= self.host and not member.ready then
            return false, "Waiting for every player to be ready"
        end
    end
    self.seed = math.random(1, 2147483646)
    for slot, member in ipairs(self.members) do
        member.slot = slot
        self.slots[slot] = { name = member.name, color = member.color, flag = member.flag, token = UUID.getUUID(), client = member }
    end
    local ok, game = pcall(Game, {
        map = self.settings.map,
        bots = self.settings.bots,
        nations = self.settings.nations,
        difficulty = self.settings.difficulty,
        autoplay = self.settings.autoplay,
        tutorial = self.settings.tutorial,
        seed = self.seed,
        humans = self:players(),
        headless = true,
        authority = true
    })
    if not ok then
        Logger:error("room", "Failed to create game: " .. tostring(game))
        self.slots = {}
        return false, "The server could not load this map"
    end
    self.game = game
    game.commandSink = function(intent)
        self.commands[#self.commands + 1] = intent
    end
    self.state = "playing"
    for _, member in ipairs(self.members) do
        self:sendStart(member, false)
    end
    Logger:info("room", string.format("Room %s started with %d players (seed %d)", self.id, #self.slots, self.seed))
    return true
end

function Room:Rejoin(client, token, lastTick)
    if self.state == "lobby" then
        return false, "This game has not started"
    end
    local slot
    for k, entry in ipairs(self.slots) do
        if entry.token == token then slot = k end
    end
    if not slot then
        return false, "You are not part of this game"
    end
    local previous = self.slots[slot].client
    if previous then
        self:Remove(previous)
        previous:Disconnect()
    end
    self:attach(client)
    client.slot = slot
    self.slots[slot].client = client
    if self.state == "playing" then
        self.pending[#self.pending + 1] = { type = "reconnect", player = slot }
    end
    lastTick = tonumber(lastTick)
    if lastTick and self:Tick() - lastTick <= Config.catchUpTicks and self:hasFrames(lastTick + 1) then
        client:Send("resume", { room = self.id, slot = slot, token = self.slots[slot].token, tick = lastTick + 1, controls = self:controls() })
        self:sendFrames(client, lastTick + 1)
        client.synced = true
        Logger:info("room", string.format("Slot %d resumed room %s from tick %d (%d frames)", slot, self.id, lastTick + 1, self:Tick() - lastTick - 1))
    else
        self:sendStart(client, true)
        Logger:info("room", string.format("Slot %d rejoined room %s at tick %d with a snapshot", slot, self.id, self:Tick()))
    end
    return true
end

function Room:Resync(client)
    if self.state == "lobby" or not client.slot then return end
    local now = love.timer.getTime()
    if client.resyncAt and now - client.resyncAt < RESYNC_COOLDOWN then return end
    client.resyncAt = now
    local snapshot = self:latestSnapshot()
    Logger:info("room", string.format("Resyncing slot %d in room %s from tick %d", client.slot, self.id, snapshot.tick))
    client:Send("sync", { tick = snapshot.tick, snapshot = snapshot.data })
    self:sendFrames(client, snapshot.tick)
end

function Room:Catchup(client, lastTick)
    if self.state == "lobby" or not client.slot then return end
    lastTick = tonumber(lastTick)
    if not lastTick then return end
    if self:Tick() - lastTick <= Config.catchUpTicks and self:hasFrames(lastTick + 1) then
        self:sendFrames(client, lastTick + 1)
    else
        self:Resync(client)
    end
end

function Room:Queue(client, raw)
    if self.state ~= "playing" or not client.slot then return end
    local seq = type(raw) == "table" and tonumber(raw.seq) or nil
    client.tickIntents = (client.tickIntents or 0) + 1
    if client.tickIntents > Config.maxIntentsPerTick then
        client:Send("reject", { seq = seq, reason = "Too many actions" })
        return
    end
    local intent, reason = Intents.sanitize(self.game, client.slot, raw)
    if not intent then
        client:Send("reject", { seq = seq, reason = reason })
        return
    end
    intent.seq = seq
    self.pending[#self.pending + 1] = intent
end

function Room:Control(client, data)
    if self.state ~= "playing" or not client.slot or type(data) ~= "table" then return end
    if #self.slots ~= 1 then
        client:Send("error", { message = "Pause and speed are only available in solo games" })
        return
    end
    if data.paused ~= nil then
        self.paused = data.paused == true
    end
    local speed = tonumber(data.speed)
    if speed and GameConfig.speeds[speed] then
        self.speedIndex = speed
    end
    self:Broadcast("control", self:controls())
end

function Room:advance()
    local game = self.game
    local tick = game.tick
    local commands = self.commands
    for _, intent in ipairs(self.pending) do
        commands[#commands + 1] = intent
    end
    self.commands = {}
    self.pending = {}
    for _, intent in ipairs(commands) do
        game:pushIntent(intent)
    end
    game:step()
    local frame = { t = tick, c = commands }
    if game.tick % Config.hashTicks == 0 then
        frame.h = game:checksum()
    end
    local raw = Protocol.Encode("frame", frame)
    self.frames[tick % Config.frameHistory] = { tick = tick, raw = raw }
    for _, client in ipairs(self.members) do
        if client.synced then
            client:SendRaw(raw)
        end
    end
    if game.phase == "ended" then
        self.state = "ended"
        self:Broadcast("ended", { tick = game.tick, winner = game.winner and game.winner.id })
        Logger:info("room", string.format("Room %s finished at tick %d", self.id, game.tick))
    end
end

function Room:Update(dt)
    if self.state ~= "playing" or self.paused then
        self.accumulator = 0
        for _, member in ipairs(self.members) do
            member.tickIntents = 0
        end
        return
    end
    local speed = #self.slots == 1 and GameConfig.speeds[self.speedIndex] or 1
    local stepTime = 1 / Config.tickRate
    self.accumulator = math.min(self.accumulator + dt * speed, stepTime * Config.maxFramesPerTick)
    while self.accumulator >= stepTime and self.state == "playing" do
        self.accumulator = self.accumulator - stepTime
        for _, member in ipairs(self.members) do
            member.tickIntents = 0
        end
        local ok, err = xpcall(self.advance, debug.traceback, self)
        if not ok then
            Logger:error("room", "Simulation error in room " .. self.id .. ": " .. tostring(err))
            self.state = "ended"
            self:Broadcast("error", { message = "The server simulation crashed" })
        end
    end
end

return Room
