local enet = require("enet")
local Class = require("src.core.class")
local Protocol = require("net.protocol")
local Client = require("net.client")
local Config = require("net.config")

local Server = Class()

function Server:init(options)
    options = options or {}
    self.address = options.address or Config.address
    self.port = options.port or Config.port
    self.maxPeers = options.maxPeers or Config.maxPeers
    self.channels = options.channels or Config.channels
    self.tickRate = options.tickRate or Config.tickRate
    self.host = nil
    self.clients = {}
    self.count = 0
    self.handlers = {}
    self.accumulator = 0
    self.tick = 0
end

function Server:Start()
    self.host = enet.host_create(self.address .. ":" .. self.port, self.maxPeers, self.channels)
    if not self.host then
        error("Failed to bind " .. self.address .. ":" .. self.port)
    end
    Logger:info("server", "Listening on " .. self.address .. ":" .. self.port)
end

function Server:Stop()
    if not self.host then return end
    for _, client in pairs(self.clients) do
        client.peer:disconnect_now()
    end
    self.host:flush()
    self.host:destroy()
    self.host = nil
    self.clients = {}
    self.count = 0
    Logger:info("server", "Stopped")
end

function Server:On(kind, handler)
    self.handlers[kind] = self.handlers[kind] or {}
    table.insert(self.handlers[kind], handler)
end

function Server:Emit(kind, client, data)
    local handlers = self.handlers[kind]
    if not handlers then return false end
    for _, handler in ipairs(handlers) do
        handler(client, data)
    end
    return true
end

function Server:Send(client, kind, data, channel, flag)
    client:Send(kind, data, channel, flag)
end

function Server:Broadcast(kind, data, except, channel, flag)
    local raw = Protocol.Encode(kind, data)
    for _, client in pairs(self.clients) do
        if client ~= except then
            client.peer:send(raw, channel or 0, flag or "reliable")
        end
    end
end

function Server:Find(id)
    for _, client in pairs(self.clients) do
        if client.id == id then
            return client
        end
    end
    return nil
end

function Server:onConnect(peer)
    peer:timeout(0, 0, Config.timeout)
    local client = Client(peer)
    self.clients[peer:index()] = client
    self.count = self.count + 1
    Logger:info("server", "Client connected", client.id, client:Address())
    self:Emit("connect", client)
end

function Server:onDisconnect(peer)
    local client = self.clients[peer:index()]
    if not client then return end
    self.clients[peer:index()] = nil
    self.count = self.count - 1
    Logger:info("server", "Client disconnected", client.id)
    self:Emit("disconnect", client)
end

function Server:onReceive(peer, raw)
    local client = self.clients[peer:index()]
    if not client then return end
    local kind, data = Protocol.Decode(raw)
    if not kind then
        Logger:warn("server", "Invalid message from", client.id)
        return
    end
    if not self:Emit(kind, client, data) then
        Logger:trace("server", "Unhandled message", kind, "from", client.id)
    end
end

function Server:Poll()
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            self:onConnect(event.peer)
        elseif event.type == "disconnect" then
            self:onDisconnect(event.peer)
        elseif event.type == "receive" then
            self:onReceive(event.peer, event.data)
        end
        event = self.host:service(0)
    end
end

function Server:Think(dt)
    if not self.host then return end
    self:Poll()
    self.accumulator = self.accumulator + dt
    local step = 1 / self.tickRate
    while self.accumulator >= step do
        self.accumulator = self.accumulator - step
        self.tick = self.tick + 1
        self:Emit("tick", nil, self.tick)
    end
    self.host:flush()
end

return Server
