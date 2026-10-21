local Class = require("src.core.class")
local UUID = require("src.core.uuid")
local Protocol = require("net.protocol")

local Client = Class()

function Client:init(peer)
    self.peer = peer
    self.id = UUID.getUUID()
    self.name = nil
    self.connectedAt = love.timer.getTime()
end

function Client:Send(kind, data, channel, flag)
    self.peer:send(Protocol.Encode(kind, data), channel or 0, flag or "reliable")
end

function Client:Disconnect()
    self.peer:disconnect_later()
end

function Client:Address()
    return tostring(self.peer)
end

function Client:Ping()
    return self.peer:round_trip_time()
end

return Client
