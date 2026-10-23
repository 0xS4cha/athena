local socket = require("socket")
local Class = require("src.core.class")
local NetConfig = require("src.net.config")

local Lan = Class()

local PREFIX = "ATHENA"
local LIMITED = "255.255.255.255"
local LOOPBACK = "127.0.0.1"

local function udp()
    return (socket.udp4 or socket.udp)()
end

function Lan:init()
    self.listener = nil
    self.sender = nil
    self.games = {}
end

function Lan:Listen(enabled)
    if enabled and not self.listener then
        local listener = udp()
        if not listener then return end
        pcall(listener.setoption, listener, "reuseaddr", true)
        pcall(listener.setoption, listener, "reuseport", true)
        if not listener:setsockname("*", NetConfig.discoveryPort) then
            listener:close()
            return
        end
        listener:settimeout(0)
        self.listener = listener
    elseif not enabled and self.listener then
        self.listener:close()
        self.listener = nil
        self.games = {}
    end
end

local function parse(data, ip)
    local fields = {}
    for field in (data .. "|"):gmatch("([^|]*)|") do
        fields[#fields + 1] = field
    end
    if fields[1] ~= PREFIX or tonumber(fields[2]) ~= NetConfig.version then return nil end
    local port, room = tonumber(fields[3]), tonumber(fields[4])
    if not port or not room then return nil end
    local host = fields[10] ~= "" and fields[10] or ip
    return {
        address = host .. ":" .. port,
        room = room,
        players = tonumber(fields[5]) or 0,
        max = tonumber(fields[6]) or 0,
        locked = fields[7] == "1",
        map = fields[8],
        name = fields[9] or "LAN game"
    }
end

function Lan:Poll()
    local now = love.timer.getTime()
    if self.listener then
        local data, ip = self.listener:receivefrom()
        while data do
            local game = parse(data, ip)
            if game then
                game.seen = now
                self.games[game.address .. "#" .. game.room] = game
            end
            data, ip = self.listener:receivefrom()
        end
    end
    for key, game in pairs(self.games) do
        if now - game.seen > NetConfig.discoveryExpire then
            self.games[key] = nil
        end
    end
end

function Lan:List()
    local list = {}
    for _, game in pairs(self.games) do
        list[#list + 1] = game
    end
    table.sort(list, function(a, b)
        if a.address ~= b.address then return a.address < b.address end
        return a.room < b.room
    end)
    return list
end

function Lan:Announce(info)
    if not self.sender then
        local sender = udp()
        if not sender then return end
        pcall(sender.setoption, sender, "broadcast", true)
        sender:settimeout(0)
        self.sender = sender
    end
    local message = table.concat({
        PREFIX, NetConfig.version, info.port, info.room, info.players, info.max,
        info.locked and "1" or "0", info.map or "", (info.name or ""):gsub("|", ""), info.address or ""
    }, "|")
    local targets = { LIMITED, LOOPBACK }
    if info.address then
        targets[#targets + 1] = info.address:gsub("%d+$", "255")
    end
    for _, target in ipairs(targets) do
        pcall(self.sender.sendto, self.sender, message, target, NetConfig.discoveryPort)
    end
end

function Lan:Close()
    self:Listen(false)
    if self.sender then
        self.sender:close()
        self.sender = nil
    end
end

return Lan
