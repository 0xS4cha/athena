local Class = require("src.core.class")
local UUID = require("src.core.uuid")
local Protocol = require("net.protocol")
local Config = require("net.config")

local Room = Class()

local DIFFICULTIES = { easy = true, medium = true, hard = true }
local SERVER_INTENTS = { disconnect = true, reconnect = true }

local DEFAULT_MAP = "assets/maps/world/"

local function sanitize(settings)
    settings = type(settings) == "table" and settings or {}
    local bots = tonumber(settings.bots) or 0
    local map = type(settings.map) == "string" and settings.map:match("^assets/maps/[%w_%-]+/$")
    return {
        map = map or DEFAULT_MAP,
        bots = math.max(0, math.min(400, math.floor(bots))),
        nations = settings.nations ~= false,
        difficulty = DIFFICULTIES[settings.difficulty] and settings.difficulty or "medium"
    }
end

function Room:init(id, host, settings)
    self.id = id
    self.name = type(settings) == "table" and type(settings.name) == "string" and settings.name:sub(1, 32) or (host.name .. "'s game")
    self.settings = sanitize(settings)
    self.host = host
    self.members = {}
    self.slots = {}
    self.state = "lobby"
    self.seed = nil
    self.tick = 0
    self.pending = {}
    self.history = {}
    self.reference = {}
    self.reports = {}
    self.finished = {}
    self.emptySince = nil
end

function Room:Summary()
    return {
        id = self.id,
        name = self.name,
        state = self.state,
        map = self.settings.map,
        players = #self.members,
        max = Config.maxRoomPlayers
    }
end

function Room:Snapshot()
    local players = {}
    for _, client in ipairs(self.members) do
        players[#players + 1] = { id = client.id, name = client.name }
    end
    return {
        id = self.id,
        name = self.name,
        state = self.state,
        host = self.host and self.host.id,
        settings = self.settings,
        players = players,
        max = Config.maxRoomPlayers
    }
end

function Room:Broadcast(kind, data, except)
    local raw = Protocol.Encode(kind, data)
    for _, client in ipairs(self.members) do
        if client ~= except then
            client.peer:send(raw, 0, "reliable")
        end
    end
end

function Room:attach(client)
    self.members[#self.members + 1] = client
    client.room = self
    self.emptySince = nil
end

function Room:Add(client)
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    if #self.members >= Config.maxRoomPlayers then
        return false, "Room is full"
    end
    self:attach(client)
    self:Broadcast("room", self:Snapshot())
    return true
end

function Room:Remove(client)
    for k, member in ipairs(self.members) do
        if member == client then
            table.remove(self.members, k)
            break
        end
    end
    client.room = nil
    self.finished[client] = nil
    if self.host == client then
        self.host = self.members[1]
    end
    if #self.members == 0 then
        self.emptySince = love.timer.getTime()
    end
    if self.state == "lobby" then
        self:Broadcast("room", self:Snapshot())
    elseif client.slot then
        self.slots[client.slot].client = nil
        if self.state == "playing" then
            self.pending[#self.pending + 1] = { type = "disconnect", player = client.slot }
        end
    end
    client.slot = nil
    for tick in pairs(self.reports) do
        self:decide(tick)
    end
end

function Room:Expired(now)
    if #self.members > 0 then return false end
    return self.state == "lobby" or now - (self.emptySince or now) > Config.emptyRoomSeconds
end

function Room:Configure(client, settings)
    if client ~= self.host then
        return false, "Only the host can change the settings"
    end
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    self.settings = sanitize(settings)
    self:Broadcast("room", self:Snapshot())
    return true
end

function Room:players()
    local players = {}
    for slot, entry in ipairs(self.slots) do
        players[slot] = { name = entry.name }
    end
    return players
end

function Room:Sync(client)
    local entry = self.slots[client.slot]
    client:Send("start", {
        room = self.id,
        seed = self.seed,
        settings = self.settings,
        players = self:players(),
        slot = client.slot,
        token = entry.token,
        hashTicks = Config.hashTicks,
        tick = self.tick,
        history = self.history
    })
end

function Room:Start(client)
    if client ~= self.host then
        return false, "Only the host can start the game"
    end
    if self.state ~= "lobby" then
        return false, "Game already started"
    end
    self.state = "playing"
    self.seed = math.random(1, 2147483646)
    self.tick = 0
    self.pending = {}
    for slot, member in ipairs(self.members) do
        member.slot = slot
        self.slots[slot] = { name = member.name, token = UUID.getUUID(), client = member }
    end
    for _, member in ipairs(self.members) do
        self:Sync(member)
    end
    Logger:info("room", string.format("Room %s started with %d players (seed %d)", self.id, #self.slots, self.seed))
    return true
end

function Room:Rejoin(client, token)
    if self.state ~= "playing" then
        return false, "This game is over"
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
    self.pending[#self.pending + 1] = { type = "reconnect", player = slot }
    self:Sync(client)
    Logger:info("room", string.format("Slot %d rejoined room %s at tick %d", slot, self.id, self.tick))
    return true
end

function Room:Resync(client)
    if self.state == "lobby" or not client.slot then return end
    Logger:info("room", string.format("Resyncing slot %d in room %s", client.slot, self.id))
    self:Sync(client)
end

function Room:Queue(client, intent)
    if self.state ~= "playing" or not client.slot then return end
    if type(intent) ~= "table" or type(intent.type) ~= "string" or SERVER_INTENTS[intent.type] then return end
    client.turnIntents = (client.turnIntents or 0) + 1
    if client.turnIntents > Config.maxIntentsPerTurn then return end
    intent.player = client.slot
    self.pending[#self.pending + 1] = intent
end

function Room:Step()
    if self.state ~= "playing" or #self.members == 0 then return end
    self:Broadcast("turn", { tick = self.tick, intents = self.pending })
    if #self.pending > 0 then
        self.history[#self.history + 1] = { tick = self.tick, intents = self.pending }
    end
    self.pending = {}
    self.tick = self.tick + 1
    for _, member in ipairs(self.members) do
        member.turnIntents = 0
    end
end

function Room:decide(tick)
    local reports = self.reports[tick]
    local count, votes = 0, {}
    for _, hash in pairs(reports) do
        count = count + 1
        votes[hash] = (votes[hash] or 0) + 1
    end
    for _, member in ipairs(self.members) do
        if member.slot and not reports[member.slot] then return end
    end
    self.reports[tick] = nil
    local winner
    for hash, n in pairs(votes) do
        if n * 2 > count then winner = hash end
    end
    if winner then
        self.reference[tick] = winner
        Logger:trace("room", string.format("Room %s in sync at tick %d", self.id, tick))
    end
    for _, member in ipairs(self.members) do
        if member.slot and reports[member.slot] ~= winner then
            Logger:warn("room", string.format("Slot %d desynced in room %s at tick %d", member.slot, self.id, tick))
            member:Send("desync", { tick = tick })
        end
    end
end

function Room:Hash(client, data)
    if self.state == "lobby" or not client.slot or type(data) ~= "table" then return end
    local tick, hash = tonumber(data.tick), tonumber(data.hash)
    if not tick or not hash or tick > self.tick then return end
    local reference = self.reference[tick]
    if reference then
        if reference ~= hash then
            Logger:warn("room", string.format("Slot %d desynced in room %s at tick %d", client.slot, self.id, tick))
            client:Send("desync", { tick = tick })
        end
        return
    end
    self.reports[tick] = self.reports[tick] or {}
    self.reports[tick][client.slot] = hash
    self:decide(tick)
end

function Room:Finish(client)
    if self.state ~= "playing" or not client.slot then return end
    self.finished[client] = true
    for _, member in ipairs(self.members) do
        if not self.finished[member] then return end
    end
    self.state = "ended"
    Logger:info("room", string.format("Room %s finished at tick %d", self.id, self.tick))
end

return Room
