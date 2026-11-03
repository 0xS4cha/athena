local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")
local Common = require("src.modules.menu.screens.multiplayer.common")
local Connect = require("src.modules.menu.screens.multiplayer.connect")
local Browse = require("src.modules.menu.screens.multiplayer.browse")
local Lobby = require("src.modules.menu.screens.multiplayer.lobby")

local Multiplayer = { id = "multiplayer" }

local net, phase, find = Common.net, Common.phase, Common.find
local PHASES = { connect = Connect, browse = Browse, lobby = Lobby }

function Multiplayer.enter(menu)
    menu.editing = nil
    menu.roomIndex = menu.roomIndex or 1
    if phase() == "connect" then
        menu.editing = "name"
    end
    menu:revealPreview()
end

function Multiplayer.update(menu)
    local mp = net()
    local count = #mp.rooms
    if (menu.roomIndex or 1) > count then
        menu.roomIndex = math.max(1, count)
    end
    if phase() == "lobby" then
        Lobby.update(menu)
    end
end

function Multiplayer.build(menu)
    local l = Play.layout()
    local elements = {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() Multiplayer.back(menu) end }
    }
    PHASES[phase()].build(menu, l, function(element) elements[#elements + 1] = element end)
    return elements
end

function Multiplayer.draw(menu, elements, p)
    local l = Play.layout()
    local current = phase()
    local mp = net()

    UI.alpha = menu:stagger(p, 1)
    local back = find(elements, "back")
    UI.button("back", back.x, back.y, back.w, back.h, current == "lobby" and "LEAVE" or "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    local titles = {
        connect = { "MULTIPLAYER", "Connect to a server to find other commanders." },
        browse = { "SERVER ROOMS", "Join an open room or create your own." },
        lobby = { string.upper(mp.room and mp.room.name or "LOBBY"), mp:LanEndpoint() and ("Open on your network at " .. mp:LanEndpoint() .. ": friends find it in Multiplayer.")
            or mp:IsHost() and "You are the host: pick the map and start when everyone is in." or "Waiting for the host to start the game." }
    }
    UI.shadowText(titles[current][1], back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text(titles[current][2], back.x + back.w + 38, 76, 12, UI.colors.muted)

    local e = menu:stagger(p, 2)
    UI.alpha = e
    local dx = math.floor((1 - e) * -40)
    love.graphics.push()
    love.graphics.translate(dx, 0)
    UI.panel(l.list.x, l.list.y, l.list.w, l.list.h, {})
    PHASES[current].drawList(menu, l, e, elements)
    love.graphics.pop()

    e = menu:stagger(p, 3)
    UI.alpha = e
    love.graphics.push()
    love.graphics.translate(0, math.floor((1 - e) * 30))
    UI.panel(l.panel.x, l.panel.y, l.panel.w, l.panel.h, { accent = UI.colors.gold, cornerAlpha = 0.5 })
    PHASES[current].draw(menu, elements, l, e)
    love.graphics.pop()
    UI.alpha = 1
end

function Multiplayer.capture(menu, key)
    return phase() == "lobby" and Lobby.capture(menu, key)
end

function Multiplayer.keyPressed(menu, key)
    local current = PHASES[phase()]
    if key == "return" or key == "kpenter" then
        if menu.focus == "back" and menu.editing ~= "chat" then return false end
        current.confirm(menu)
        return true
    end
    if (key == "up" or key == "down") and current.navigate then
        return current.navigate(menu, key == "up" and -1 or 1)
    end
    return false
end

function Multiplayer.wheel(menu, y)
    if phase() == "lobby" then
        Lobby.wheel(menu, y)
    end
end

function Multiplayer.back(menu)
    if phase() == "lobby" then
        net():LeaveRoom()
        return
    end
    menu:switch("root", -1)
end

return Multiplayer
