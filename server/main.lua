package.path = love.filesystem.getSourceBaseDirectory() .. "/?.lua;" .. package.path

require("src.core.logger")
local ArgParser = require("src.core.args")
local Server = require("net.server")
local Room = require("net.room")
local Config = require("net.config")

local server
local rooms = {}
local nextRoomId = 1

local function roomList()
    local list = {}
    for _, room in pairs(rooms) do
        if room.state == "lobby" then
            list[#list + 1] = room:Summary()
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function closeExpired(room)
    if room:Expired(love.timer.getTime()) then
        rooms[room.id] = nil
        Logger:info("server", "Room closed", room.id)
    end
end

local function leaveRoom(client)
    local room = client.room
    if not room then return end
    room:Remove(client)
    closeExpired(room)
end

local function joinRoom(client, room)
    leaveRoom(client)
    local ok, err = room:Add(client)
    if not ok then
        client:Send("error", { message = err })
    end
    return ok
end

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("port", { default = Config.port, type = "value" })
    parser:add_argument("peers", { default = Config.maxPeers, type = "value" })
    local flags = parser:parse(args)

    math.randomseed(os.time())
    server = Server({ port = flags.port, maxPeers = flags.peers })

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
        client:Send("rooms", { rooms = roomList() })
    end)

    server:On("create", function(client, data)
        if not client.name then return end
        local room = Room(nextRoomId, client, data)
        nextRoomId = nextRoomId + 1
        rooms[room.id] = room
        Logger:info("server", "Room created", room.id, room.name)
        joinRoom(client, room)
    end)

    server:On("join", function(client, data)
        if not client.name then return end
        local room = type(data) == "table" and rooms[tonumber(data.id)]
        if not room then
            client:Send("error", { message = "Room not found" })
            return
        end
        joinRoom(client, room)
    end)

    server:On("leave", function(client)
        leaveRoom(client)
    end)

    server:On("rejoin", function(client, data)
        if not client.name or type(data) ~= "table" then return end
        local room = rooms[tonumber(data.room)]
        if not room then
            client:Send("error", { message = "This game no longer exists", session = false })
            return
        end
        leaveRoom(client)
        local ok, err = room:Rejoin(client, data.token)
        if not ok then
            client:Send("error", { message = err, session = false })
        end
    end)

    server:On("resync", function(client)
        if client.room then
            client.room:Resync(client)
        end
    end)

    server:On("finished", function(client)
        if client.room then
            client.room:Finish(client)
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

    server:On("hash", function(client, data)
        if client.room then
            client.room:Hash(client, data)
        end
    end)

    server:On("tick", function()
        for _, room in pairs(rooms) do
            room:Step()
            closeExpired(room)
        end
    end)

    server:On("disconnect", function(client)
        leaveRoom(client)
    end)

    server:Start()
end

function love.update(dt)
    server:Think(dt)
    love.timer.sleep(0.001)
end

function love.quit()
    if server then
        server:Stop()
    end
end
