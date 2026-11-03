local Common = require("src.modules.menu.screens.multiplayer.common")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")

local net, find, mapByPath = Common.net, Common.find, Common.mapByPath
local ROW = Common.ROW

local Browse = {}

local function passwordHandler(menu)
    return function(_, text)
        local value = menu.password or ""
        if text then
            if #value < 24 and text:match("^[%w%-_%.!@#%$%%%^&%*]$") then
                menu.password = value .. text
            end
        else
            menu.password = value:sub(1, -2)
        end
    end
end

local function selectedRoom(menu)
    return net().rooms[menu.roomIndex or 1]
end

function Browse.confirm(menu)
    local room = selectedRoom(menu)
    if room then
        net():JoinRoom(room.id, menu.password)
    end
end

local function createRoom(menu)
    local settings = Common.hostSettings(menu)
    settings.name = (menu.settings.name ~= "" and menu.settings.name or "Player") .. "'s game"
    settings.password = menu.password
    menu.hostRoom = nil
    net():CreateRoom(settings)
end

local function moveRoom(menu, delta)
    local count = #net().rooms
    if count == 0 then return end
    menu.roomIndex = Fx.clamp((menu.roomIndex or 1) + delta, 1, count)
end

function Browse.build(menu, l, add)
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - Common.CONTROLS_H + 12
    local half = math.floor((cw - 24) / 2)
    add({
        id = "rooms", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
        press = function(_, _, my) Browse.clickRoom(menu, my) end,
        up = function() moveRoom(menu, -1) end, down = function() moveRoom(menu, 1) end
    })
    add({ id = "password", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 40, press = function() menu.editing = "password" end, text = passwordHandler(menu) })
    add({ id = "refresh", x = cx, y = cy + 90, w = half, h = 44, press = function() net():ListRooms() end })
    add({ id = "disconnect", x = cx + half + 24, y = cy + 90, w = cw - half - 24, h = 44, press = function() net():Disconnect() end })
    if net():CanRejoin() then
        add({ id = "create", x = cx, y = cy + 156, w = half, h = 50, press = function() createRoom(menu) end })
        add({ id = "rejoin", x = cx + half + 24, y = cy + 156, w = cw - half - 24, h = 50, press = function() net():Rejoin() end })
    else
        add({ id = "create", x = cx, y = cy + 156, w = cw, h = 50, press = function() createRoom(menu) end })
    end
    add({ id = "join", x = cx, y = cy + 222, w = cw, h = 58, press = function() Browse.confirm(menu) end })
end

function Browse.clickRoom(menu, my)
    local l = Play.layout()
    local k = math.floor((my - l.rows.y) / ROW) + 1
    if not net().rooms[k] then return end
    local now = love.timer.getTime()
    if k == menu.roomIndex and menu.lastClick and now - menu.lastClick < 0.4 then
        Browse.confirm(menu)
        return
    end
    menu.roomIndex = k
    menu.lastClick = now
end

function Browse.drawList(menu, l, e)
    local mp = net()
    UI.text("OPEN ROOMS", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
    local rows = {}
    for _, room in ipairs(mp.rooms) do
        rows[#rows + 1] = { label = room.name, icon = room.locked and "Locked.png" or "Home.png", detail = string.format("%d/%d", room.players, room.max) }
    end
    Common.drawRows(menu, l, e, rows, menu.roomIndex)
    if #rows == 0 then
        UI.text("No open room.", l.rows.x + UI.unit * 4, l.rows.y + 6, 13, UI.colors.muted)
    end
end

function Browse.draw(menu, elements, l, e)
    local mp = net()
    local room = selectedRoom(menu)
    local map = room and mapByPath(menu, room.map)
    if map then
        Play.drawPreview(menu, l, e, map, true)
        Play.drawChips(l, map, true, 0)
    else
        UI.text(#mp.rooms == 0 and "No open room yet. Create one!" or "Unknown map", l.preview.x + 12, l.preview.y + 12, 14, UI.colors.muted)
    end

    local password = find(elements, "password")
    UI.text("ROOM PASSWORD", password.x, password.y - 22, 11, UI.colors.muted)
    UI.field("password", password.x, password.y, password.w, password.h, string.rep("*", #(menu.password or "")), {
        editing = menu.editing == "password", hot = menu.focus == "password", icon = "Key.png", placeholder = "Optional", size = 13
    })
    local refresh = find(elements, "refresh")
    UI.text(string.format("Connected to %s as %s", tostring(mp.address), mp.name), refresh.x, refresh.y - 66, 12, UI.colors.muted)
    Common.drawStatus(menu, refresh.x, refresh.y - 42)
    UI.button("refresh", refresh.x, refresh.y, refresh.w, refresh.h, "REFRESH", { hot = menu.focus == "refresh", icon = "Restart.png", size = 14 })
    local disconnect = find(elements, "disconnect")
    UI.button("disconnect", disconnect.x, disconnect.y, disconnect.w, disconnect.h, "DISCONNECT", { hot = menu.focus == "disconnect", icon = "Exit.png", size = 14, color = UI.colors.bad })
    local create = find(elements, "create")
    local current = menu:current()
    UI.button("create", create.x, create.y, create.w, create.h, "CREATE ROOM", {
        hot = menu.focus == "create", icon = "Home.png", size = 16, sublabel = current and ("on " .. current.name) or nil, align = "left"
    })
    local rejoin = find(elements, "rejoin")
    if rejoin then
        UI.button("rejoin", rejoin.x, rejoin.y, rejoin.w, rejoin.h, "REJOIN GAME", {
            hot = menu.focus == "rejoin", icon = "Restart.png", size = 16, sublabel = "Your last game is still running", align = "left", color = UI.colors.gold
        })
    end
    local join = find(elements, "join")
    UI.button("join", join.x, join.y, join.w, join.h, room and ("JOIN " .. string.upper(room.name)) or "JOIN ROOM", {
        hot = menu.focus == "join", primary = room ~= nil, disabled = room == nil, size = 18, icon = "Play.png", hint = "ENTER"
    })
end

function Browse.navigate(menu, delta)
    if menu.focus == nil or menu.focus == "rooms" then
        moveRoom(menu, delta)
        return true
    end
    return false
end

return Browse
