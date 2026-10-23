require("src.core.logger")
local ArgParser = require("src.core.args")
local Host = require("src.server.host")
local Config = require("src.net.config")

local host

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("port", { default = Config.port, type = "value" })
    parser:add_argument("peers", { default = Config.maxPeers, type = "value" })
    local flags = parser:parse(args)

    math.randomseed(os.time())
    host = Host({ port = flags.port, maxPeers = flags.peers })
    local ok, err = host:Start()
    if not ok then
        error(err)
    end
end

function love.update(dt)
    host:Think(dt)
end

function love.quit()
    if host then
        host:Stop()
    end
end
