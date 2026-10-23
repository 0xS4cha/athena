local Class = require("src.core.class")

local LocalServer = Class()

local THREAD_FILE = "src/server/thread.lua"
local STOP_TIMEOUT = 2

local serial = 0

function LocalServer:init()
    self.thread = nil
    self.commands = nil
    self.status = nil
    self.state = "stopped"
    self.port = nil
    self.error = nil
    self.lan = false
    self.waiting = {}
end

function LocalServer:Running()
    return self.state == "running"
end

function LocalServer:Start(callback, lan)
    lan = lan == true
    if self.state ~= "stopped" and self.state ~= "failed" and self.lan ~= lan then
        self:Stop()
    end
    self.lan = lan
    if self.state == "running" then
        callback(self.port)
        return
    end
    self.waiting[#self.waiting + 1] = callback
    if self.state == "starting" then return end
    serial = serial + 1
    local suffix = string.format("%d_%d", os.time(), serial)
    self.commands = love.thread.getChannel("athena_server_commands_" .. suffix)
    self.status = love.thread.getChannel("athena_server_status_" .. suffix)
    self.commands:clear()
    self.status:clear()
    self.thread = love.thread.newThread(THREAD_FILE)
    self.thread:start("athena_server_commands_" .. suffix, "athena_server_status_" .. suffix, lan)
    self.state = "starting"
    self.error = nil
    Logger:info("localserver", lan and "Starting the LAN game server" or "Starting the local game server")
end

function LocalServer:fail(message)
    self.state = "failed"
    self.error = message
    self.waiting = {}
    self.thread = nil
    Logger:error("localserver", message)
end

function LocalServer:Update()
    if not self.thread then return end
    local threadError = self.thread:getError()
    if threadError then
        self:fail(threadError)
        return
    end
    local message = self.status:pop()
    while message do
        if message.ready then
            self.state = "running"
            self.port = message.port
            Logger:info("localserver", "Local game server listening on port " .. tostring(message.port))
            local waiting = self.waiting
            self.waiting = {}
            for _, callback in ipairs(waiting) do
                callback(self.port)
            end
        elseif message.error then
            self:fail(message.error)
            return
        elseif message.stopped then
            self.state = "stopped"
            self.thread = nil
            return
        end
        message = self.status:pop()
    end
end

function LocalServer:Stop()
    if not self.thread then
        self.state = "stopped"
        return
    end
    self.commands:push("stop")
    local deadline = love.timer.getTime() + STOP_TIMEOUT
    while self.thread:isRunning() and love.timer.getTime() < deadline do
        love.timer.sleep(0.005)
    end
    self.thread = nil
    self.state = "stopped"
    self.port = nil
    self.waiting = {}
end

return LocalServer
