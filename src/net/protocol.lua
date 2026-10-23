local Codec = require("src.net.codec")

local Protocol = {}

function Protocol.Encode(kind, data)
    return Codec.encode({ kind, data })
end

function Protocol.Decode(raw)
    local message = Codec.decode(raw)
    if type(message) ~= "table" or type(message[1]) ~= "string" then
        return nil
    end
    return message[1], message[2]
end

return Protocol
