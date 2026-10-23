require("love.timer")
require("love.filesystem")
require("love.data")
require("src.core.logger")
local Host = require("src.server.host")
local Config = require("src.net.config")

local commandsName, statusName, lan = ...
local commands = love.thread.getChannel(commandsName)
local status = love.thread.getChannel(statusName)

math.randomseed(os.time())

local address = lan and Config.address or Config.localAddress
local ports = lan and Config.lanPorts or Config.localPorts
local host, port
for candidate = ports[1], ports[2] do
    local attempt = Host({ address = address, port = candidate, maxPeers = Config.maxRoomPlayers * 2 })
    if attempt:Start() then
        host, port = attempt, candidate
        break
    end
end

if not host then
    status:push({ error = "No free local port for the game server" })
    return
end

status:push({ ready = true, port = port })

local last = love.timer.getTime()
while true do
    local command = commands:pop()
    if command == "stop" then
        host:Stop()
        status:push({ stopped = true })
        return
    end
    local now = love.timer.getTime()
    local ok, err = xpcall(host.Think, debug.traceback, host, now - last)
    if not ok then
        status:push({ error = tostring(err) })
        host:Stop()
        return
    end
    last = now
    love.timer.sleep(0.002)
end
