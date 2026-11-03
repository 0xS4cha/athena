local GM = require("src.core.index")
local UI = require("src.modules.hud.pixel")
local Rules = require("src.modules.game.rules")

local Screen = { id = "rules" }

local SEG_W = 340
local MODE_SEG_W = 520
local ROW_MIN = 44
local ROW_MAX = 58

local function readOnly(menu)
    local mp = GM.Multiplayer
    return menu.rulesBack == "multiplayer" and mp.room ~= nil and not mp:IsHost()
end

local function current(menu)
    if readOnly(menu) then
        return Rules.sanitize(GM.Multiplayer.room.settings.rules)
    end
    return menu.rules
end

local function layout()
    local W, H = love.graphics.getDimensions()
    local M = math.max(40, math.floor(W * 0.04))
    local w = math.min(880, W - M * 2)
    local rowH = math.max(ROW_MIN, math.min(ROW_MAX, math.floor((H - 112 - 70 - 40) / (#Rules.fields + 2))))
    return { M = M, x = M, y = 112, w = w, rowH = rowH }
end

local function segments(element, count, mx)
    local width = element.segW or SEG_W
    local x = element.x + element.w - width - 12
    if mx < x then return nil end
    return math.max(1, math.min(count, math.floor((mx - x) / (width / count)) + 1))
end

local function setMode(menu, index)
    local raw = { mode = Rules.modes[index].id }
    for _, field in ipairs(Rules.fields) do
        raw[field.id] = menu.rules[field.id]
    end
    menu:setRules(Rules.sanitize(raw))
end

local function setField(menu, field, index)
    menu:setRules(Rules.set(menu.rules, field.id, field.values[index]))
end

local function selector(menu, element, count, index, apply)
    if readOnly(menu) then return end
    element.press = function(_, mx)
        local target = mx and segments(element, count, mx) or (not mx and index() % count + 1) or nil
        if target then apply(target) end
    end
    element.left = function() apply(math.max(1, index() - 1)) end
    element.right = function() apply(math.min(count, index() + 1)) end
end

function Screen.build(menu)
    local l = layout()
    local list = {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() Screen.back(menu) end }
    }
    local y = l.y + 46
    local modeRow = { id = "mode", x = l.x + 18, y = y, w = l.w - 36, h = l.rowH + 8, segW = MODE_SEG_W }
    selector(menu, modeRow, #Rules.modes, function() return Rules.modeIndex(menu.rules) end, function(k) setMode(menu, k) end)
    modeRow.nav = not readOnly(menu)
    list[#list + 1] = modeRow
    y = y + l.rowH + 12
    for _, field in ipairs(Rules.fields) do
        local element = { id = field.id, field = field, x = l.x + 18, y = y, w = l.w - 36, h = l.rowH - 6 }
        selector(menu, element, #field.values, function() return Rules.valueIndex(field, menu.rules) end, function(k) setField(menu, field, k) end)
        element.nav = not readOnly(menu)
        list[#list + 1] = element
        y = y + l.rowH
    end
    return list
end

local function drawRow(menu, element, p, k, title, hint, labels, index)
    local u = UI.unit
    local e = menu:stagger(p, k + 1)
    UI.alpha = e
    local dx = math.floor((1 - e) * -30 / u) * u
    local x, y, w, h = element.x + dx, element.y, element.w, element.h
    local hot = UI.ease("rules:" .. element.id, menu.focus == element.id and element.press ~= nil)
    if hot > 0.01 then
        UI.color(UI.colors.raised, 0.7 * hot)
        UI.block(x, y, w, h)
        UI.color(UI.colors.hover, hot)
        love.graphics.rectangle("fill", x, y + u * 2, u, h - u * 4)
    end
    UI.text(title, x + u * 6, y + 3, 15, UI.colors.text)
    UI.text(hint, x + u * 6, y + 25, 10, UI.colors.muted, 0.8)
    local width = element.segW or SEG_W
    UI.segments("rules:seg:" .. element.id, x + w - width - 12, y + 6, width, h - 12, labels, index, { hot = menu.focus == element.id and element.press ~= nil, size = 11 })
end

function Screen.draw(menu, elements, p)
    local l = layout()
    local rules = current(menu)
    UI.alpha = menu:stagger(p, 1)
    local back = elements[1]
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("GAME RULES", back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text(readOnly(menu) and "Only the host can change the rules." or Rules.hint(rules), back.x + back.w + 38, 76, 12, UI.colors.muted)

    UI.alpha = menu:stagger(p, 2)
    local last = elements[#elements]
    UI.panel(l.x, l.y, l.w, last.y + last.h + 14 - l.y, { title = "MODE AND RULES" })
    local labels = {}
    for k, entry in ipairs(Rules.modes) do labels[k] = entry.label end
    drawRow(menu, elements[2], p, 2, "Mode", "A preset, or your own", labels, Rules.modeIndex(rules))
    for k = 3, #elements do
        local element = elements[k]
        drawRow(menu, element, p, k, element.field.label, element.field.hint, element.field.labels, Rules.valueIndex(element.field, rules))
    end
    UI.alpha = 1
end

function Screen.back(menu)
    menu:switch(menu.rulesBack or "play", -1)
end

return Screen
