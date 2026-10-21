local UI = require("src.modules.hud.pixel")

local Settings = { id = "settings" }

local SPEEDS = { "x1", "x2", "x4", "x8" }

local function rows(menu)
    local s = menu.settings
    return {
        { id = "fullscreen", label = "Fullscreen", hint = "Borderless desktop fullscreen", kind = "toggle", value = s.fullscreen },
        { id = "vsync", label = "VSync", hint = "Sync frames with your display", kind = "toggle", value = s.vsync },
        { id = "background", label = "Live battle", hint = "AI nations fight behind the menu", kind = "toggle", value = s.background },
        { id = "battleSpeed", label = "Battle speed", hint = "Speed of the background battle", kind = "segments", value = s.battleSpeed },
        { id = "particles", label = "Embers", hint = "Floating sparks over the menu", kind = "toggle", value = s.particles },
        { id = "nextBattle", label = "Next battle", hint = "Jump to another battlefield", kind = "action" }
    }
end

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = math.max(40, math.floor(W * 0.04))
    local w = math.min(640, W - M * 2)
    return { M = M, x = M, y = 112, w = w, rowH = 62, H = H }
end

function Settings.build(menu)
    local l = layout()
    local list = {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() menu:switch("root", -1) end }
    }
    local y = l.y + 52
    for _, row in ipairs(rows(menu)) do
        local element = { id = row.id, x = l.x + 18, y = y, w = l.w - 36, h = l.rowH - 8, row = row }
        if row.kind == "toggle" then
            element.press = function() menu:setOption(row.id, not menu.settings[row.id]) end
            element.left = function() menu:setOption(row.id, false) end
            element.right = function() menu:setOption(row.id, true) end
        elseif row.kind == "segments" then
            local segX = element.x + element.w - 260
            element.press = function(_, mx)
                if mx and mx >= segX then
                    menu:setOption(row.id, math.max(1, math.min(#SPEEDS, math.floor((mx - segX) / (240 / #SPEEDS)) + 1)))
                elseif not mx then
                    menu:setOption(row.id, menu.settings.battleSpeed % #SPEEDS + 1)
                end
            end
            element.left = function() menu:setOption(row.id, math.max(1, menu.settings.battleSpeed - 1)) end
            element.right = function() menu:setOption(row.id, math.min(#SPEEDS, menu.settings.battleSpeed + 1)) end
        else
            element.press = function() menu:nextBattle() end
        end
        list[#list + 1] = element
        y = y + l.rowH
    end
    return list
end

function Settings.draw(menu, elements, p)
    local l = layout()
    local u = UI.unit
    UI.alpha = menu:stagger(p, 1)
    local back = elements[1]
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("SETTINGS", back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text("Saved automatically.", back.x + back.w + 38, 76, 12, UI.colors.muted)

    UI.alpha = menu:stagger(p, 2)
    local count = #elements - 1
    UI.panel(l.x, l.y, l.w, 70 + count * l.rowH, { title = "DISPLAY & MENU" })

    for k = 2, #elements do
        local element = elements[k]
        local row = element.row
        local e = menu:stagger(p, k + 1)
        UI.alpha = e
        local dx = math.floor((1 - e) * -30 / u) * u
        local x, y, w, h = element.x + dx, element.y, element.w, element.h
        local hot = UI.ease("set:" .. row.id, menu.focus == row.id)
        if hot > 0.01 then
            UI.color(UI.colors.raised, 0.7 * hot)
            UI.block(x, y, w, h)
            UI.color(UI.colors.hover, hot)
            love.graphics.rectangle("fill", x, y + u * 2, u, h - u * 4)
        end
        UI.text(row.label, x + u * 6, y + 6, 15, UI.colors.text)
        UI.text(row.hint, x + u * 6, y + 30, 10, UI.colors.muted, 0.8)
        if row.kind == "toggle" then
            UI.toggle("toggle:" .. row.id, x + w - u * 20, y + math.floor((h - u * 7) / 2), row.value, menu.focus == row.id)
        elseif row.kind == "segments" then
            UI.segments("seg:" .. row.id, x + w - 260, y + 10, 240, h - 20, SPEEDS, row.value, { hot = menu.focus == row.id, size = 12 })
        else
            UI.color(UI.colors.gold, 0.6 + 0.4 * hot)
            UI.arrow(x + w - u * 12 + math.floor(hot * 2) * u, y + math.floor(h / 2), 4, 1)
        end
    end
    UI.alpha = 1
end

function Settings.back(menu)
    menu:switch("root", -1)
end

return Settings
