local enet = require("enet")
local Class = require("src.core.class")
local Protocol = require("src.net.protocol")
local Client = require("src.server.client")
local Config = require("src.net.config")

local Server = Class()

function Server:init(options)
    options = options or {}
    self.address = options.address or Config.address
    self.port = options.port or Config.port
    self.maxPeers = options.maxPeers or Config.maxPeers
    self.channels = options.channels or Config.channels
    self.host = nil
    self.clients = {}
    self.count = 0
    self.handlers = {}
end

function Server:Start()
    local ok, host = pcall(enet.host_create, self.address .. ":" .. self.port, self.maxPeers, self.channels)
    if not ok or not host then
        return false, "Failed to bind " .. self.address .. ":" .. self.port
    end
    self.host = host
    Logger:info("server", "Listening on " .. self.address .. ":" .. self.port)
    return true
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
    self:Emit("update", nil, dt)
    self.host:flush()
end

return Server
