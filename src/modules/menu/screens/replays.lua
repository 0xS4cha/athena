local GM = require("src.core.index")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")
local Common = require("src.modules.menu.screens.multiplayer.common")
local ReplayFile = require("src.modules.replay.file")
local Rules = require("src.modules.game.rules")

local Replays = { id = "replays" }

local ROW = Common.ROW
local CONTROLS_H = Common.CONTROLS_H
local CONFIRM_SECONDS = 4

local function selected(menu)
    return menu.replays and menu.replays[menu.replayIndex or 1]
end

local function visibleRows()
    return math.max(1, math.floor(Play.layout().rows.h / ROW))
end

local function clampScroll(menu)
    local maxScroll = math.max(0, #(menu.replays or {}) - visibleRows())
    local index = menu.replayIndex or 1
    local scroll = menu.replayScroll or 0
    if index <= scroll then scroll = index - 1 end
    if index > scroll + visibleRows() then scroll = index - visibleRows() end
    menu.replayScroll = Fx.clamp(scroll, 0, maxScroll)
end

local function refresh(menu)
    menu.replays = ReplayFile.list()
    menu.replayIndex = Fx.clamp(menu.replayIndex or 1, 1, math.max(1, #menu.replays))
    clampScroll(menu)
end

local function move(menu, delta)
    if #menu.replays == 0 then return end
    menu.replayIndex = Fx.clamp(menu.replayIndex + delta, 1, #menu.replays)
    menu.replayError = nil
    menu.replayDeleteAt = nil
    clampScroll(menu)
    menu:revealPreview()
end

local function watch(menu)
    local entry = selected(menu)
    if not entry or menu.wipe then return end
    local ok, err = GM.Replay:Watch(entry.name)
    menu.replayError = not ok and err or nil
end

local function remove(menu)
    local entry = selected(menu)
    if not entry then return end
    local now = love.timer.getTime()
    if menu.replayDeleteAt and now - menu.replayDeleteAt < CONFIRM_SECONDS then
        ReplayFile.delete(entry.name)
        menu.replayDeleteAt = nil
        refresh(menu)
        menu:revealPreview()
    else
        menu.replayDeleteAt = now
    end
end

local function clickRow(menu, my)
    local l = Play.layout()
    local k = math.floor((my - l.rows.y) / ROW) + 1 + (menu.replayScroll or 0)
    if not menu.replays[k] then return end
    local now = love.timer.getTime()
    if k == menu.replayIndex and menu.lastClick and now - menu.lastClick < 0.4 then
        watch(menu)
        return
    end
    menu.replayIndex = k
    menu.lastClick = now
    menu.replayError = nil
    menu.replayDeleteAt = nil
    menu:revealPreview()
end

function Replays.enter(menu)
    refresh(menu)
    menu.replayError = nil
    menu.replayDeleteAt = nil
    menu:revealPreview()
end

function Replays.build(menu)
    local l = Play.layout()
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - CONTROLS_H + 12
    local third = math.floor((cw - 24) / 3)
    return {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() menu:switch("root", -1) end },
        {
            id = "list", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
            press = function(_, _, my) clickRow(menu, my) end,
            up = function() move(menu, -1) end, down = function() move(menu, 1) end
        },
        { id = "delete", x = cx, y = cy + 222, w = third, h = 58, press = function() remove(menu) end },
        { id = "watch", x = cx + third + 24, y = cy + 222, w = cw - third - 24, h = 58, press = function() watch(menu) end }
    }
end

local function mapOf(menu, entry)
    return entry and Common.mapByPath(menu, entry.header.settings.map)
end

local function capitalized(text)
    text = tostring(text or "")
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function drawDetails(menu, entry, x, y)
    local header = entry.header
    local names = {}
    for _, player in ipairs(header.players) do names[#names + 1] = player.name end
    local s = header.settings
    local lines = {
        { "Played", os.date("%Y-%m-%d %H:%M", header.date or 0) },
        { "Length", Format.time(header.ticks, Config.tickRate) },
        { "Result", header.result or "?" },
        { "Mode", Rules.label(s.rules) .. "  -  " .. capitalized(s.difficulty) },
        { "Players", table.concat(names, ", ") }
    }
    for k, line in ipairs(lines) do
        local ly = y + (k - 1) * 28
        UI.text(line[1], x, ly, 12, UI.colors.muted)
        UI.text(line[2], x + 110, ly - 1, 14, UI.colors.text)
    end
    if entry.outdated then
        UI.text("Recorded with another version: it cannot be watched.", x, y + #lines * 28, 12, UI.colors.bad)
    elseif menu.replayError then
        UI.text(menu.replayError, x, y + #lines * 28, 12, UI.colors.bad)
    end
end

function Replays.draw(menu, elements, p)
    local l = Play.layout()
    local back, watchButton, deleteButton = elements[1], elements[4], elements[3]
    local entry = selected(menu)
    UI.alpha = menu:stagger(p, 1)
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("REPLAYS", back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text(string.format("Your games are saved automatically. The last %d are kept.", ReplayFile.keep), back.x + back.w + 38, 76, 12, UI.colors.muted)

    local e = menu:stagger(p, 2)
    UI.alpha = e
    UI.panel(l.list.x, l.list.y, l.list.w, l.list.h, {})
    UI.text("SAVED GAMES", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
    local rows = {}
    local scroll = menu.replayScroll or 0
    for k = scroll + 1, math.min(#menu.replays, scroll + visibleRows()) do
        local item = menu.replays[k]
        rows[#rows + 1] = {
            label = item.header.mapName or "?",
            icon = item.outdated and "Locked.png" or "Play.png",
            detail = Format.time(item.header.ticks, Config.tickRate),
            color = item.outdated and UI.colors.muted or nil
        }
    end
    Common.drawRows(menu, l, e, rows, (menu.replayIndex or 1) - scroll)
    if #rows == 0 then
        UI.text("No replay yet.", l.rows.x + UI.unit * 4, l.rows.y + 6, 13, UI.colors.muted)
    end

    e = menu:stagger(p, 3)
    UI.alpha = e
    UI.panel(l.panel.x, l.panel.y, l.panel.w, l.panel.h, { accent = UI.colors.gold, cornerAlpha = 0.5 })
    local map = mapOf(menu, entry)
    if map then
        Play.drawPreview(menu, l, e, map, false)
    elseif not entry then
        UI.text("Finish a game to watch it here.", l.preview.x + 12, l.preview.y + 12, 14, UI.colors.muted)
    end
    if entry then
        drawDetails(menu, entry, l.panel.x + 24, l.panel.y + l.panel.h - CONTROLS_H + 12)
    end
    local armed = menu.replayDeleteAt and love.timer.getTime() - menu.replayDeleteAt < CONFIRM_SECONDS
    UI.button("delete", deleteButton.x, deleteButton.y, deleteButton.w, deleteButton.h, armed and "CONFIRM?" or "DELETE", {
        hot = menu.focus == "delete", icon = "Exit.png", size = 16, color = UI.colors.bad, disabled = entry == nil
    })
    local playable = entry ~= nil and not entry.outdated
    UI.button("watch", watchButton.x, watchButton.y, watchButton.w, watchButton.h, "WATCH REPLAY", {
        hot = menu.focus == "watch", primary = playable, disabled = not playable, size = 20, icon = "Play.png", hint = "ENTER"
    })
    UI.alpha = 1
end

function Replays.keyPressed(menu, key)
    if key == "return" or key == "kpenter" then
        if menu.focus == "back" or menu.focus == "delete" then return false end
        watch(menu)
        return true
    end
    if (key == "up" or key == "down") and (menu.focus == nil or menu.focus == "list") then
        move(menu, key == "up" and -1 or 1)
        return true
    end
    return false
end

function Replays.wheel(menu, y)
    local maxScroll = math.max(0, #menu.replays - visibleRows())
    menu.replayScroll = Fx.clamp((menu.replayScroll or 0) - y * 3, 0, maxScroll)
end

function Replays.back(menu)
    menu:switch("root", -1)
end

return Replays
