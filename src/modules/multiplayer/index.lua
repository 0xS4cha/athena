local GM = require("src.core.index")
local enet = require("enet")
local json = require("libs.json")
local Protocol = require("src.net.protocol")
local NetConfig = require("src.net.config")
local Lockstep = require("src.modules.multiplayer.lockstep")
local LocalServer = require("src.modules.multiplayer.localserver")
local Lan = require("src.modules.multiplayer.lan")

GM.Multiplayer = {}

GM.Modules:Register("Multiplayer", 90)

local ROOMS_REFRESH = 2
local RECONNECT_DELAY = 3
local MAX_RECONNECTS = 10
local SESSION_FILE = "multiplayer_session.json"
local BAD = { 0.95, 0.35, 0.3, 1 }

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
    self.reconnecting = false
    self.reconnectAt = nil
    self.reconnects = 0
    self.rejoining = false
    self.localServer = LocalServer()
    self.isLocal = false
    self.solo = nil
    self.lan = Lan()
    self.lanHost = false
    self.lanAddress = nil
    self.announceAt = 0
    self.pendingJoin = nil

    self:On("welcome", function(data)
        self.id = data.id
        self.state = "online"
        self.error = nil
        if self.rejoining then
            self.rejoining = false
            self:Rejoin()
        elseif self.solo then
            self:CreateRoom(self.solo)
        elseif self.pendingJoin then
            self:JoinRoom(self.pendingJoin)
            self.pendingJoin = nil
        end
        self:ListRooms()
    end)
    self:On("rooms", function(data) self.rooms = data.rooms or {} end)
    self:On("room", function(data)
        self.room = data
        self.error = nil
        if self.solo and not self.solo.autostart then
            self.solo = nil
        end
    end)
    self:On("error", function(data)
        self.error = data.message
        Logger:warn("multiplayer", tostring(data.message))
        if self.solo then
            self:abortSolo(tostring(data.message))
        elseif self:inGame() then
            self:notify(tostring(data.message))
        end
        if data.session == false then
            self:clearSession()
            if self.reconnecting then
                self:stopReconnecting(tostring(data.message))
            end
        end
    end)
    self:On("start", function(data) self:startGame(data) end)
    self:On("resume", function(data) self:resumeGame(data) end)
    self:On("frame", function(data)
        if self.lockstep then self.lockstep:receive(data) end
    end)
    self:On("sync", function(data)
        if self.lockstep and type(data.snapshot) == "string" then
            self.lockstep:applySnapshot(data.tick, data.snapshot)
        end
    end)
    self:On("reject", function(data)
        if self.lockstep then self.lockstep:reject(data) end
    end)
    self:On("ended", function(data)
        if self.lockstep then self.lockstep:serverEnded(data) end
    end)
    self:On("control", function(data)
        if self.lockstep then self.lockstep:applyControls(data) end
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
    if not session.isLocal then
        love.filesystem.write(SESSION_FILE, json.encode(session))
    end
end

function GM.Multiplayer:clearSession()
    self.session = nil
    love.filesystem.remove(SESSION_FILE)
end

function GM.Multiplayer:CanRejoin()
    return self.session ~= nil and not self.session.isLocal and self.state == "online" and self.session.address == self.address
end

function GM.Multiplayer:On(kind, handler)
    self.handlers[kind] = self.handlers[kind] or {}
    table.insert(self.handlers[kind], handler)
end

function GM.Multiplayer:Connect(address, name, isLocal)
    self:Disconnect()
    self.name = name or self.name
    self.isLocal = isLocal == true
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

function GM.Multiplayer:PlaySolo(settings, name)
    self.solo = {
        map = settings.map,
        bots = settings.bots,
        nations = settings.nations,
        difficulty = settings.difficulty,
        autoplay = settings.autoplay,
        name = "Solo",
        autostart = true
    }
    self.error = nil
    self.lockstep = nil
    self.lanHost = false
    self.localServer:Start(function(port)
        if not self.solo then return end
        self:Connect(NetConfig.localAddress .. ":" .. port, name, true)
    end)
end

function GM.Multiplayer:HostLan(settings, name)
    self.solo = {
        map = settings.map,
        bots = settings.bots,
        nations = settings.nations,
        difficulty = settings.difficulty,
        name = (name or "Player") .. "'s LAN game"
    }
    self.error = nil
    self.lockstep = nil
    self.lanHost = true
    self.lanAddress = Lan.localAddress()
    self.localServer:Start(function(port)
        if not self.solo then return end
        self:Connect(NetConfig.localAddress .. ":" .. port, name, true)
    end, true)
end

function GM.Multiplayer:JoinLan(game, name)
    self.pendingJoin = game.room
    self:Connect(game.address, name)
end

function GM.Multiplayer:LanGames()
    return self.lan:List()
end

function GM.Multiplayer:LanEndpoint()
    if not self.lanHost or not self.localServer:Running() then return nil end
    return (self.lanAddress or "?") .. ":" .. tostring(self.localServer.port)
end

function GM.Multiplayer:stopLocal()
    self:Disconnect()
    self.localServer:Stop()
    self.isLocal = false
    self.lanHost = false
    self.session = nil
end

function GM.Multiplayer:abortSolo(reason)
    self.solo = nil
    self.error = reason
    if GM.Menu and GM.Menu.CancelLaunch then
        GM.Menu:CancelLaunch(reason)
    end
    if not self.lockstep then
        self:stopLocal()
    end
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

function GM.Multiplayer:Flush()
    if self.host then
        self.host:flush()
    end
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
    local lockstep = self.lockstep
    local lastTick = lockstep and lockstep.room == self.session.room and lockstep:lastContiguous() or nil
    return self:Send("rejoin", { room = self.session.room, token = self.session.token, lastTick = lastTick })
end

function GM.Multiplayer:Configure(settings)
    return self:Send("settings", settings)
end

function GM.Multiplayer:LeaveRoom()
    self.room = nil
    if self.isLocal and not self.lockstep then
        self:stopLocal()
        return true
    end
    return self:Send("leave")
end

function GM.Multiplayer:LeaveGame(lockstep)
    if lockstep ~= self.lockstep then return end
    self.lockstep = nil
    self.reconnecting = false
    self.reconnectAt = nil
    if self.isLocal then
        self:stopLocal()
    else
        self:LeaveRoom()
    end
end

function GM.Multiplayer:StartGame()
    return self:Send("start")
end

function GM.Multiplayer:Finished(lockstep)
    if lockstep ~= self.lockstep then return end
    if not self.isLocal then
        self:clearSession()
    end
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
        if self.solo then self:abortSolo(self.error) end
        return
    end
    self:saveSession({ address = self.address, room = data.room, token = data.token, slot = data.slot, isLocal = self.isLocal })
    self.reconnecting = false
    self.reconnectAt = nil
    self.reconnects = 0
    self.room = nil
    self.solo = nil

    local lockstep = Lockstep(self, { room = data.room, slot = data.slot, hashTicks = data.hashTicks, controls = data.controls })
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
            autoplay = settings.autoplay,
            seed = data.seed,
            humans = data.players,
            localSlot = data.slot,
            authority = false,
            lockstep = lockstep
        })
        if type(data.snapshot) == "string" then
            lockstep:applySnapshot(data.tick, data.snapshot)
        end
    end
    if GM.Menu and GM.Menu:active() then
        GM.Menu:Launch(settings.map:match("([^/]+)/$") or "", launch)
    else
        launch()
    end
end

function GM.Multiplayer:resumeGame(data)
    local lockstep = self.lockstep
    if not lockstep or lockstep.room ~= data.room or not lockstep.game then
        self:Send("resync")
        return
    end
    self.reconnecting = false
    self.reconnectAt = nil
    self.reconnects = 0
    lockstep:applyControls(data.controls or lockstep.controls)
    lockstep:resume(data.tick)
    self:notify("Reconnected to the server.", { 0.3, 0.85, 0.45, 1 })
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
    if self.solo then
        self:abortSolo(self.error)
        return
    end
    if not self:inGame() or not self.session then return end
    if self.isLocal and not self.localServer:Running() then
        self:notify("The local game server stopped.")
        return
    end
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

function GM.Multiplayer:updateLan(now)
    local browsing = GM.Menu and GM.Menu:active() and GM.Menu.screen == "multiplayer"
    self.lan:Listen(browsing and not self.lanHost)
    self.lan:Poll()
    local room = self.room
    if self.lanHost and room and room.state == "lobby" and self.localServer:Running()
        and now - self.announceAt >= NetConfig.discoveryInterval then
        self.announceAt = now
        self.lan:Announce({
            port = self.localServer.port,
            room = room.id,
            players = #(room.players or {}),
            max = room.max,
            locked = room.locked,
            map = room.settings and room.settings.map,
            name = room.name,
            address = self.lanAddress
        })
    end
end

function GM.Multiplayer:Think()
    self.localServer:Update()
    self:updateLan(love.timer.getTime())
    if self.solo and self.localServer.state == "failed" then
        self:abortSolo(self.localServer.error or "The local game server failed to start")
    end
    local now = love.timer.getTime()
    if not self.host then
        if self.reconnecting and not self:inGame() then
            self.reconnecting = false
            self.reconnectAt = nil
        end
        if self.reconnectAt and now >= self.reconnectAt and self.session then
            self.reconnectAt = nil
            self.rejoining = true
            self:Connect(self.session.address, self.name, self.session.isLocal)
        end
        return
    end
    if self.state == "online" and not self.room and GM.Menu and GM.Menu:active() and GM.Menu.screen == "multiplayer"
        and now - self.roomsTime > ROOMS_REFRESH then
        self.roomsTime = now
        self:ListRooms()
    end
    self:Poll()
end

function GM.Multiplayer:Poll()
    if not self.host then return end
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

function GM.Multiplayer:Shutdown()
    self:Disconnect()
    self.localServer:Stop()
    self.lan:Close()
end
