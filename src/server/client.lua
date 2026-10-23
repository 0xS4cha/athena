local Class = require("src.core.class")
local UUID = require("src.core.uuid")
local Protocol = require("src.net.protocol")

local Client = Class()

function Client:init(peer)
    self.peer = peer
    self.id = UUID.getUUID()
    self.name = nil
    self.connectedAt = love.timer.getTime()
end

function Client:Send(kind, data)
    self.peer:send(Protocol.Encode(kind, data), 0, "reliable")
end

function Client:SendRaw(raw)
    self.peer:send(raw, 0, "reliable")
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
