local GM = require("src.core.index")
local json = require("libs.json")
local enet = require("enet")

GM.Multiplayer = {}

GM.Modules:Register("Multiplayer", 90)

function GM.Multiplayer:Initialize()
    self.host = enet.host_create()
    self.server = self.host:connect("localhost:6789")
    self.connected = false
end

function GM.Multiplayer:Think(dt)
    if not self.host then return end

    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            self.connected = true
            print("Connected at", event.peer)
            event.peer:send(json.encode({type = "ping", data = {}}))
            event.peer:send(json.encode({type = "hello", data = {}}))
        elseif event.type == "receive" then
            print("Receive :", event.data)
        elseif event.type == "disconnect" then
            self.connected = false
            print("Disconnect")
        end
        event = self.host:service(0)
    end
end