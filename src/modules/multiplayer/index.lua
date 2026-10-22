local GM = require("src.core.index")
local enet = require("enet")
local json = require("libs.json")
local Protocol = require("server.net.protocol")
local NetConfig = require("server.net.config")
local Lockstep = require("src.modules.multiplayer.lockstep")

GM.Multiplayer = {}

GM.Modules:Register("Multiplayer", 90)

local ROOMS_REFRESH = 2
local RECONNECT_DELAY = 3
local MAX_RECONNECTS = 10
local MAX_RESYNCS = 3
local SESSION_FILE = "multiplayer_session.json"
local BAD = { 0.95, 0.35, 0.3, 1 }
local INFO = { 0.45, 0.75, 1, 1 }

function GM.Multiplayer:Initialize()
    self.host = nil
    self.peer = nil
    self.connected = false
    self.state = "offline"
    self.address = nil
    self.roomsTime = 0
    self.name = "Player"
    self.id = nil
    self.rooms = {}
    self.room = nil
    self.lockstep = nil
    self.error = nil
    self.handlers = {}
    self.session = self:loadSession()
    self.resyncs = 0
    self.reconnecting = false
    self.reconnectAt = nil
    self.reconnects = 0
    self.rejoining = false

    self:On("welcome", function(data)
        self.id = data.id
        self.state = "online"
        self.error = nil
        if self.rejoining then
            self.rejoining = false
            self:Rejoin()
        end
        self:ListRooms()
    end)
    self:On("rooms", function(data) self.rooms = data.rooms or {} end)
    self:On("room", function(data)
        self.room = data
        self.error = nil
    end)
    self:On("error", function(data)
        self.error = data.message
        Logger:warn("multiplayer", tostring(data.message))
        if data.session == false then
            self:clearSession()
            if self.reconnecting then
                self:stopReconnecting(tostring(data.message))
            end
        end
    end)
    self:On("start", function(data) self:startGame(data) end)
    self:On("turn", function(data)
        if self.lockstep then self.lockstep:receive(data) end
    end)
    self:On("desync", function(data)
        Logger:error("multiplayer", "Desync detected at tick " .. tostring(data.tick))
        if not self.lockstep then return end
        if self.resyncs < MAX_RESYNCS then
            self.resyncs = self.resyncs + 1
            self:notify("Desync detected at tick " .. tostring(data.tick) .. ". Resynchronizing...", INFO)
            self:Send("resync")
        else
            self:notify("Desync detected again: your game no longer matches the other players.")
        end
    end)

    self:setupAutoJoin(GM.Flags or {})
end

function GM.Multiplayer:setupAutoJoin(flags)
    if not flags.connect then return end
    self:On("welcome", function()
        if flags.room == "rejoin" then
            self:Rejoin()
        elseif flags.room and flags.room ~= "new" then
            self:JoinRoom(tonumber(flags.room))
        else
            self:CreateRoom({ map = flags.map, bots = flags.bots, nations = flags.nations ~= "off", difficulty = flags.difficulty })
        end
    end)
    self:On("room", function(data)
        if data.state == "lobby" and data.host == self.id and #(data.players or {}) >= (tonumber(flags.players) or 1) then
            self:StartGame()
        end
    end)
    self:Connect(flags.connect, flags.name)
end

function GM.Multiplayer:loadSession()
    local content = love.filesystem.getInfo(SESSION_FILE) and love.filesystem.read(SESSION_FILE)
    if not content then return nil end
    local ok, session = pcall(json.decode, content)
    if ok and type(session) == "table" and session.room and session.token then
        return session
    end
    return nil
end

function GM.Multiplayer:saveSession(session)
    self.session = session
    love.filesystem.write(SESSION_FILE, json.encode(session))
end

function GM.Multiplayer:clearSession()
    self.session = nil
    love.filesystem.remove(SESSION_FILE)
end

function GM.Multiplayer:CanRejoin()
    return self.session ~= nil and self.state == "online" and self.session.address == self.address
end

function GM.Multiplayer:On(kind, handler)
    self.handlers[kind] = self.handlers[kind] or {}
    table.insert(self.handlers[kind], handler)
end

function GM.Multiplayer:Connect(address, name)
    self:Disconnect()
    self.name = name or self.name
    self.address = address and address ~= "" and address or ("localhost:" .. NetConfig.port)
    if not self.address:find(":", 1, true) then
        self.address = self.address .. ":" .. NetConfig.port
    end
    self.error = nil
    self.host = enet.host_create()
    local ok, peer = pcall(self.host.connect, self.host, self.address, NetConfig.channels)
    if not ok or not peer then
        self.host = nil
        self.error = "Invalid server address"
        return false
    end
    self.peer = peer
    self.state = "connecting"
    return true
end

function GM.Multiplayer:Disconnect()
    if self.peer then
        self.peer:disconnect_now()
        self.host:flush()
    end
    self.host = nil
    self.peer = nil
    self.connected = false
    self.state = "offline"
    self.id = nil
    self.room = nil
    self.rooms = {}
end

function GM.Multiplayer:IsHost()
    return self.room ~= nil and self.room.host == self.id
end

function GM.Multiplayer:notify(text, color)
    local game = GM.Session and GM.Session.Game
    if game and game.lockstep and game.lockstep == self.lockstep then
        game:addEvent(text, { color = color or BAD, duration = 600 })
    end
end

function GM.Multiplayer:Send(kind, data)
    if not self.connected then return false end
    local ok, raw = pcall(Protocol.Encode, kind, data)
    if not ok then
        Logger:warn("multiplayer", "Failed to encode " .. kind .. ": " .. tostring(raw))
        return false
    end
    self.peer:send(raw, 0, "reliable")
    return true
end

function GM.Multiplayer:ListRooms()
    return self:Send("rooms")
end

function GM.Multiplayer:CreateRoom(settings)
    return self:Send("create", settings)
end

function GM.Multiplayer:JoinRoom(id)
    return self:Send("join", { id = id })
end

function GM.Multiplayer:Rejoin()
    if not self.session then return false end
    return self:Send("rejoin", { room = self.session.room, token = self.session.token })
end

function GM.Multiplayer:Configure(settings)
    return self:Send("settings", settings)
end

function GM.Multiplayer:LeaveRoom()
    self.room = nil
    return self:Send("leave")
end

function GM.Multiplayer:StartGame()
    return self:Send("start")
end

function GM.Multiplayer:Finished(lockstep)
    if lockstep ~= self.lockstep then return end
    self:Send("finished")
    self:clearSession()
end

function GM.Multiplayer:stopReconnecting(reason)
    self.reconnecting = false
    self.reconnectAt = nil
    self.rejoining = false
    self:notify("Could not rejoin the game: " .. reason)
end

function GM.Multiplayer:startGame(data)
    local settings = data.settings or {}
    if not settings.map or not love.filesystem.getInfo(settings.map .. "map.bin") then
        self.error = "Missing map " .. tostring(settings.map)
        self:LeaveRoom()
        return
    end
    local session = self.session
    if not (session and session.room == data.room and session.token == data.token) then
        self.resyncs = 0
    end
    self:saveSession({ address = self.address, room = data.room, token = data.token, slot = data.slot })
    self.reconnecting = false
    self.reconnectAt = nil
    self.reconnects = 0
    self.room = nil

    local lockstep = Lockstep(self, data.hashTicks)
    lockstep:load(data.history, data.tick)
    self.lockstep = lockstep
    local function launch()
        if self.lockstep ~= lockstep then return end
        if GM.Menu and GM.Menu.background then
            GM.Menu.background:stop()
        end
        GM.Session:Start({
            map = settings.map,
            bots = settings.bots,
            nations = settings.nations,
            difficulty = settings.difficulty,
            seed = data.seed,
            humans = data.players,
            localSlot = data.slot,
            lockstep = lockstep
        })
    end
    if GM.Menu and GM.Menu:active() and not GM.Menu.wipe then
        local name = settings.map:match("([^/]+)/$") or ""
        GM.Menu.wipe = { phase = "cover", start = love.timer.getTime(), label = name, action = launch }
    else
        launch()
    end
end

function GM.Multiplayer:dispatch(kind, data)
    local handlers = self.handlers[kind]
    if not handlers then
        Logger:trace("multiplayer", "Unhandled message " .. kind)
        return
    end
    for _, handler in ipairs(handlers) do
        handler(data or {})
    end
end

function GM.Multiplayer:inGame()
    local lockstep = self.lockstep
    return lockstep ~= nil and lockstep.game ~= nil and lockstep.game.phase ~= "ended"
end

function GM.Multiplayer:onConnectionLost()
    local wasOnline = self.state == "online"
    local address = self.address
    self:Disconnect()
    if not self.error then
        self.error = wasOnline and "Connection to the server lost" or "Could not reach " .. tostring(address)
    end
    Logger:warn("multiplayer", self.error)
    if not self:inGame() or not self.session then return end
    if self.reconnects < MAX_RECONNECTS then
        if not self.reconnecting then
            self:notify("Connection to the server lost. Reconnecting...")
        end
        self.reconnecting = true
        self.reconnects = self.reconnects + 1
        self.reconnectAt = love.timer.getTime() + RECONNECT_DELAY
    else
        self:stopReconnecting("the server is unreachable")
    end
end

function GM.Multiplayer:Think()
    local now = love.timer.getTime()
    if not self.host then
        if self.reconnecting and not self:inGame() then
            self.reconnecting = false
            self.reconnectAt = nil
        end
        if self.reconnectAt and now >= self.reconnectAt and self.session then
            self.reconnectAt = nil
            self.rejoining = true
            self:Connect(self.session.address, self.name)
        end
        return
    end
    if self.state == "online" and not self.room and GM.Menu and GM.Menu:active() and GM.Menu.screen == "multiplayer"
        and now - self.roomsTime > ROOMS_REFRESH then
        self.roomsTime = now
        self:ListRooms()
    end
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            self.connected = true
            Logger:info("multiplayer", "Connected to " .. tostring(event.peer))
            self:Send("hello", { name = self.name, version = NetConfig.version })
        elseif event.type == "receive" then
            local kind, data = Protocol.Decode(event.data)
            if kind then
                self:dispatch(kind, data)
            end
        elseif event.type == "disconnect" then
            self:onConnectionLost()
            return
        end
        if not self.host then return end
        event = self.host:service(0)
    end
end
