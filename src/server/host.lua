local Class = require("src.core.class")
local Server = require("src.server.server")
local Room = require("src.server.room")
local Config = require("src.net.config")

local Host = Class()

function Host:init(options)
    options = options or {}
    self.server = Server({ address = options.address, port = options.port, maxPeers = options.maxPeers })
    self.rooms = {}
    self.nextRoomId = 1
    self.pingAt = 0
    self:bind()
end

function Host:Start()
    return self.server:Start()
end

function Host:Stop()
    self.server:Stop()
end

function Host:Think(dt)
    self.server:Think(dt)
end

function Host:roomList()
    local list = {}
    for _, room in pairs(self.rooms) do
        if room.state == "lobby" then
            list[#list + 1] = room:Summary()
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Host:closeExpired(room)
    if room:Expired(love.timer.getTime()) then
        self.rooms[room.id] = nil
        Logger:info("server", "Room closed", room.id)
    end
end

function Host:leaveRoom(client)
    local room = client.room
    if not room then return end
    room:Remove(client)
    self:closeExpired(room)
end

function Host:joinRoom(client, room, password)
    self:leaveRoom(client)
    local ok, err = room:Add(client, password)
    if not ok then
        client:Send("error", { message = err })
    end
    return ok
end

function Host:bind()
    local server = self.server

    server:On("hello", function(client, data)
        data = type(data) == "table" and data or {}
        if data.version ~= Config.version then
            client:Send("error", { message = "Version mismatch: server is v" .. Config.version, fatal = true })
            client:Disconnect()
            return
        end
        local name = type(data.name) == "string" and data.name:sub(1, 24) or ""
        client.name = name ~= "" and name or "Player"
        client:Send("welcome", { id = client.id })
    end)

    server:On("ping", function(client, data)
        client:Send("pong", data)
    end)

    server:On("rooms", function(client)
        client:Send("rooms", { rooms = self:roomList() })
    end)

    server:On("create", function(client, data)
        if not client.name then return end
        local room = Room(self.nextRoomId, client, data)
        self.nextRoomId = self.nextRoomId + 1
        self.rooms[room.id] = room
        Logger:info("server", "Room created", room.id, room.name)
        if self:joinRoom(client, room) and type(data) == "table" and data.autostart then
            local ok, err = room:Start(client)
            if not ok then
                client:Send("error", { message = err })
            end
        end
    end)

    server:On("join", function(client, data)
        if not client.name then return end
        local room = type(data) == "table" and self.rooms[tonumber(data.id)]
        if not room then
            client:Send("error", { message = "Room not found" })
            return
        end
        self:joinRoom(client, room, data.password)
    end)

    server:On("ready", function(client, data)
        if client.room and type(data) == "table" then
            client.room:SetReady(client, data.ready)
        end
    end)

    server:On("profile", function(client, data)
        if client.room then
            local ok, err = client.room:Profile(client, data)
            if not ok and err then
                client:Send("error", { message = err })
            end
        end
    end)

    server:On("kick", function(client, data)
        if client.room and type(data) == "table" then
            local ok, err = client.room:Kick(client, data.id)
            if not ok then
                client:Send("error", { message = err })
            end
        end
    end)

    server:On("leave", function(client)
        self:leaveRoom(client)
    end)

    server:On("rejoin", function(client, data)
        if not client.name or type(data) ~= "table" then return end
        local room = self.rooms[tonumber(data.room)]
        if not room then
            client:Send("error", { message = "This game no longer exists", session = false })
            return
        end
        self:leaveRoom(client)
        local ok, err = room:Rejoin(client, data.token, data.lastTick)
        if not ok then
            client:Send("error", { message = err, session = false })
        end
    end)

    server:On("resync", function(client)
        if client.room then
            client.room:Resync(client)
        end
    end)

    server:On("catchup", function(client, data)
        if client.room and type(data) == "table" then
            client.room:Catchup(client, data.lastTick)
        end
    end)

    server:On("settings", function(client, data)
        local room = client.room
        if not room then return end
        local ok, err = room:Configure(client, data)
        if not ok then
            client:Send("error", { message = err })
        end
    end)

    server:On("start", function(client)
        local room = client.room
        if not room then return end
        local ok, err = room:Start(client)
        if not ok then
            client:Send("error", { message = err })
        end
    end)

    server:On("intent", function(client, data)
        if client.room then
            client.room:Queue(client, data)
        end
    end)

    server:On("chat", function(client, data)
        if client.room then
            client.room:Chat(client, data)
        end
    end)

    server:On("control", function(client, data)
        if client.room then
            client.room:Control(client, data)
        end
    end)

    server:On("update", function(_, dt)
        local now = love.timer.getTime()
        local pings = now - self.pingAt >= Config.pingInterval
        if pings then self.pingAt = now end
        for _, room in pairs(self.rooms) do
            room:Update(dt)
            if pings then room:BroadcastPings() end
            self:closeExpired(room)
        end
    end)

    server:On("disconnect", function(client)
        self:leaveRoom(client)
    end)
end

return Host
