package.path = love.filesystem.getSourceBaseDirectory() .. "/?.lua;" .. package.path

require("src.core.logger")
local ArgParser = require("src.core.args")
local Server = require("net.server")
local Config = require("net.config")

local server

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("port", { default = Config.port, type = "value" })
    parser:add_argument("peers", { default = Config.maxPeers, type = "value" })
    local flags = parser:parse(args)

    server = Server({ port = flags.port, maxPeers = flags.peers })

    server:On("hello", function(client, data)
        client.name = type(data) == "table" and data.name or "Player"
        client:Send("welcome", { id = client.id, tick = server.tick })
        server:Broadcast("joined", { id = client.id, name = client.name }, client)
    end)

    server:On("ping", function(client, data)
        client:Send("pong", data)
    end)

    server:On("disconnect", function(client)
        server:Broadcast("left", { id = client.id })
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
