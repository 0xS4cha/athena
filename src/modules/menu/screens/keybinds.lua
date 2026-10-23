local UI = require("src.modules.hud.pixel")
local Style = require("src.modules.hud.style")
local Keybinds = require("src.modules.input.keybinds")

local Screen = { id = "keybinds" }

local GROUPS = {
    { id = "build", title = "BUILD" },
    { id = "nuke", title = "NUKES" }
}

local ROW_H = 40

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = math.max(40, math.floor(W * 0.04))
    local gap = 32
    local w = math.min(460, math.floor((W - M * 2 - gap) / 2))
    return { M = M, x = M, y = 112, w = w, gap = gap, H = H }
end

local function actionsIn(group)
    local list = {}
    for _, action in ipairs(Keybinds.actions) do
        if action.group == group then
            list[#list + 1] = action
        end
    end
    return list
end

local function bind(menu, id)
    menu.binding = menu.binding ~= id and id or nil
    menu.bindMessage = nil
end

function Screen.enter(menu)
    menu.binding = nil
    menu.bindMessage = nil
end

function Screen.build(menu)
    local l = layout()
    local list = {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() Screen.back(menu) end }
    }
    for k, group in ipairs(GROUPS) do
        local px = l.x + (k - 1) * (l.w + l.gap)
        local y = l.y + 52
        for _, action in ipairs(actionsIn(group.id)) do
            list[#list + 1] = { id = action.id, x = px + 18, y = y, w = l.w - 36, h = ROW_H - 6, action = action, press = function() bind(menu, action.id) end }
            y = y + ROW_H
        end
        if k == #GROUPS then
            list[#list + 1] = {
                id = "reset", x = px, y = y + 40, w = l.w, h = 46,
                press = function()
                    Keybinds.reset()
                    menu.binding = nil
                    menu.bindMessage = "Default bindings restored"
                end
            }
        end
    end
    return list
end

function Screen.capture(menu, key)
    if not menu.binding then return false end
    if key == "escape" then
        menu.binding = nil
        return true
    end
    local ok, message = Keybinds.set(menu.binding, (key ~= "backspace" and key ~= "delete") and key or nil)
    menu.bindMessage = message
    if ok then
        menu.binding = nil
    end
    return true
end

local function drawKey(x, y, h, label, color, alpha)
    local u = UI.unit
    local font = Style.font(12)
    local w = math.max(u * 16, font:getWidth(label) + u * 8)
    x = x - w
    UI.color(UI.colors.ink, 0.9 * alpha)
    UI.block(x, y, w, h, u)
    UI.color(UI.colors.raised, alpha)
    UI.block(x + u, y + u, w - 2 * u, h - 3 * u, u)
    love.graphics.setColor(1, 1, 1, 0.15 * UI.alpha * alpha)
    love.graphics.rectangle("fill", x + 2 * u, y + u, w - 4 * u, u)
    UI.text(label, x + math.floor((w - font:getWidth(label)) / 2), y + math.floor((h - u - font:getHeight()) / 2), 12, color, alpha)
end

function Screen.draw(menu, elements, p)
    local l = layout()
    local u = UI.unit
    UI.alpha = menu:stagger(p, 1)
    local back = elements[1]
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("KEY BINDINGS", back.x + back.w + 36, 36, 26, UI.colors.text)
    local hint = menu.binding and "Press a key. Backspace clears, Escape cancels." or "Click an action, then press a key. In game, left click places, right click cancels."
    UI.text(menu.bindMessage or hint, back.x + back.w + 38, 76, 12, menu.bindMessage and UI.colors.gold or UI.colors.muted)

    for k, group in ipairs(GROUPS) do
        UI.alpha = menu:stagger(p, k + 1)
        local count = #actionsIn(group.id)
        UI.panel(l.x + (k - 1) * (l.w + l.gap), l.y, l.w, 64 + count * ROW_H, { title = group.title })
    end

    local blink = love.timer.getTime() % 0.8 < 0.5
    for k = 2, #elements do
        local element = elements[k]
        UI.alpha = menu:stagger(p, math.min(k, 12) + 1)
        local x, y, w, h = element.x, element.y, element.w, element.h
        if element.id == "reset" then
            UI.button("reset", x, y, w, h, "RESET TO DEFAULTS", { hot = menu.focus == "reset", icon = "Restart.png", align = "left", size = 14 })
        else
            local action = element.action
            local capturing = menu.binding == action.id
            local hot = UI.ease("bind:" .. action.id, menu.focus == action.id or capturing)
            if hot > 0.01 then
                UI.color(UI.colors.raised, 0.7 * hot)
                UI.block(x, y, w, h)
                UI.color(capturing and UI.colors.gold or UI.colors.hover, hot)
                love.graphics.rectangle("fill", x, y + u * 2, u, h - u * 4)
            end
            UI.icon(action.icon, x + u * 5, y + math.floor((h - 20) / 2), 20)
            UI.text(action.label, x + u * 5 + 28, y + 4, 14, UI.colors.text)
            local key = Keybinds.get(action.id)
            if capturing then
                drawKey(x + w - u * 3, y + u, h - u * 2, "...", UI.colors.gold, blink and 1 or 0.4)
            else
                drawKey(x + w - u * 3, y + u, h - u * 2, Keybinds.label(key), key and UI.colors.gold or UI.colors.muted, 1)
            end
        end
    end
    UI.alpha = 1
end

function Screen.back(menu)
    menu:switch("settings", -1)
end

return Screen
