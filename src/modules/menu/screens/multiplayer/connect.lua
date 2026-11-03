local Common = require("src.modules.menu.screens.multiplayer.common")
local Style = require("src.modules.hud.style")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")
local Palette = require("src.modules.player.palette")

local net, find = Common.net, Common.find
local ROW = Common.ROW

local Connect = {}

local FIELDS = {
    name = { limit = 24, pattern = "^[%w%s%-_%.']$" },
    server = { limit = 64, pattern = "^[%w%.%-:]$" },
    flag = { limit = 24, pattern = "^[%w%-]$" }
}

local function fieldHandler(menu, field)
    local rule = FIELDS[field]
    return function(_, text)
        local value = menu.settings[field]
        if text then
            if #value < rule.limit and text:match(rule.pattern) then
                menu.settings[field] = value .. text
            end
        else
            menu.settings[field] = value:sub(1, -2)
        end
    end
end

function Connect.confirm(menu)
    local mp = net()
    if mp.state == "connecting" then
        mp:Disconnect()
        return
    end
    local name = menu.settings.name ~= "" and menu.settings.name or "Player"
    mp:Connect(menu.settings.server, name)
    menu:saveSettings()
end

function Connect.build(menu, l, add)
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - Common.CONTROLS_H + 12
    local half = math.floor((cw - 24) / 2)
    add({
        id = "lan", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
        press = function(_, _, my) Connect.clickLan(menu, my) end
    })
    add({ id = "name", x = cx, y = cy + 22, w = half, h = 42, press = function() menu.editing = "name" end, text = fieldHandler(menu, "name") })
    add({ id = "server", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 42, press = function() menu.editing = "server" end, text = fieldHandler(menu, "server") })
    local count = #Palette.choices + 1
    add({
        id = "color", x = cx, y = cy + 106, w = half, h = 34,
        press = function(_, mx)
            if not mx then
                menu.settings.color = (menu.settings.color + 1) % count
            else
                menu.settings.color = Fx.clamp(math.floor((mx - cx) / (half / count)), 0, count - 1)
            end
            menu:saveSettings()
        end,
        left = function() menu.settings.color = (menu.settings.color - 1) % count end,
        right = function() menu.settings.color = (menu.settings.color + 1) % count end
    })
    add({ id = "flag", x = cx + half + 24, y = cy + 106, w = cw - half - 24, h = 34, press = function() menu.editing = "flag" end, text = fieldHandler(menu, "flag") })
    add({ id = "connect", x = cx, y = cy + 222, w = cw, h = 58, press = function() Connect.confirm(menu) end })
end

function Connect.clickLan(menu, my)
    local l = Play.layout()
    local game = net():LanGames()[math.floor((my - l.rows.y) / ROW) + 1]
    if not game then return end
    menu:saveSettings()
    net():JoinLan(game, menu.settings.name ~= "" and menu.settings.name or "Player", menu.password)
end

function Connect.drawList(_, l, e)
    local mp = net()
    UI.text("LAN GAMES", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
    local rows = {}
    for _, game in ipairs(mp:LanGames()) do
        rows[#rows + 1] = {
            label = game.name,
            icon = game.locked and "Locked.png" or "Home.png",
            detail = string.format("%d/%d", game.players, game.max)
        }
    end
    Common.drawRows(nil, l, e, rows, nil)
    if #rows == 0 then
        local dots = string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
        UI.text("Searching your network" .. dots, l.rows.x + UI.unit * 4, l.rows.y + 6, 13, UI.colors.muted)
    end
end

function Connect.draw(menu, elements, l)
    local s = menu.settings
    local area = l.preview
    UI.shadowText("PLAY WITH FRIENDS", area.x + 12, area.y + 12, 22, UI.colors.gold)
    local lines = {
        "Join a server, create a room and pick the battlefield.",
        "Games hosted on your network appear on the left: click one to join.",
        "Host a LAN game from New Game, or a server with  love . --server  (UDP 6789)."
    }
    for k, line in ipairs(lines) do
        UI.text(line, area.x + 12, area.y + 40 + k * 26, 13, UI.colors.muted)
    end

    local name = find(elements, "name")
    UI.text("COMMANDER", name.x, name.y - 22, 11, UI.colors.muted)
    UI.field("name", name.x, name.y, name.w, name.h, s.name, { editing = menu.editing == "name", hot = menu.focus == "name", icon = "Pencil.png", placeholder = "Player" })
    local server = find(elements, "server")
    UI.text("SERVER", server.x, server.y - 22, 11, UI.colors.muted)
    UI.field("server", server.x, server.y, server.w, server.h, s.server, { editing = menu.editing == "server", hot = menu.focus == "server", icon = "Monitor.png", placeholder = "localhost:6789" })

    local u = UI.unit
    local color = find(elements, "color")
    UI.text("COLOR", color.x, color.y - 22, 11, UI.colors.muted)
    local count = #Palette.choices + 1
    local cell = color.w / count
    for k = 0, count - 1 do
        local x0 = math.floor(color.x + k * cell)
        local x1 = math.floor(color.x + (k + 1) * cell) - u
        local selected = (s.color or 0) == k
        UI.color(selected and UI.colors.gold or UI.colors.ink, selected and 1 or 0.85)
        UI.block(x0, color.y, x1 - x0, color.h, u)
        if k == 0 then
            UI.color(UI.colors.raised)
            UI.block(x0 + u, color.y + u, x1 - x0 - 2 * u, color.h - 2 * u, u)
            UI.text("A", x0 + math.floor((x1 - x0) / 2) - 3, color.y + 8, 11, UI.colors.muted)
        else
            UI.color(Palette.choices[k])
            UI.block(x0 + u, color.y + u, x1 - x0 - 2 * u, color.h - 2 * u, u)
        end
    end
    local flag = find(elements, "flag")
    UI.text("FLAG (COUNTRY CODE)", flag.x, flag.y - 22, 11, UI.colors.muted)
    UI.field("flag", flag.x, flag.y, flag.w, flag.h, s.flag, { editing = menu.editing == "flag", hot = menu.focus == "flag", icon = "Pencil.png", placeholder = "fr, us, jp...", size = 13 })
    if s.flag ~= "" then
        Style.flag(s.flag, flag.x + flag.w - 34, flag.y + 5, 24)
    end
    Common.drawStatus(menu, name.x, name.y + 134)

    local button = find(elements, "connect")
    local connecting = net().state == "connecting"
    UI.button("connect", button.x, button.y, button.w, button.h, connecting and "CANCEL" or "CONNECT", {
        hot = menu.focus == "connect", primary = not connecting, size = 20, icon = "Team.png", hint = "ENTER"
    })
end

return Connect
