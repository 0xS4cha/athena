local json = require("libs.json")

local Protocol = {}

function Protocol.Encode(kind, data)
    return json.encode({ type = kind, data = data })
end

function Protocol.Decode(raw)
    local ok, message = pcall(json.decode, raw)
    if not ok or type(message) ~= "table" or type(message.type) ~= "string" then
        return nil
    end
    return message.type, message.data
end

return Protocol
