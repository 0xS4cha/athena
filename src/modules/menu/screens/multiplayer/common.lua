local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")

local Common = {}

Common.ROW = 30
Common.CONTROLS_H = 300

function Common.net()
    return GM.Multiplayer
end

function Common.phase()
    local mp = Common.net()
    if mp.state ~= "online" then return "connect" end
    if mp.room then return "lobby" end
    return "browse"
end

function Common.mapByPath(menu, path)
    for k, map in ipairs(menu.maps or {}) do
        if map.path == path then return map, k end
    end
end

function Common.hostSettings(menu)
    local map = menu:current()
    local s = menu.settings
    return { map = map and map.path, bots = s.bots, nations = s.nations, difficulty = s.difficulty, teams = s.teams, rules = menu.rules }
end

function Common.find(elements, id)
    for _, element in ipairs(elements) do
        if element.id == id then return element end
    end
end

function Common.drawRows(menu, l, e, rows, selected)
    local u = UI.unit
    local mx, my = love.mouse.getPosition()
    local area = l.rows
    love.graphics.setScissor(area.x - u * 4, area.y, area.w + u * 8, area.h)
    for k, row in ipairs(rows) do
        local ry = area.y + (k - 1) * Common.ROW
        if ry > area.y + area.h then break end
        local rowIn = Fx.clamp(e * 2 - k * 0.04, 0, 1)
        local isSelected = k == selected
        local hovered = UI.hotspot({ x = area.x, y = ry, w = area.w, h = Common.ROW - 2 }, mx, my)
        local hot = UI.ease("mprow:" .. k, isSelected and 1 or (hovered and 0.45 or 0), 18)
        UI.alpha = rowIn * e
        if hot > 0.01 then
            UI.color(isSelected and UI.colors.hover or UI.colors.raised, 0.25 + 0.6 * hot)
            UI.block(area.x, ry, area.w, Common.ROW - 3, u)
            if isSelected then
                UI.color(UI.colors.gold)
                love.graphics.rectangle("fill", area.x, ry + u, u, Common.ROW - 3 - 2 * u)
            end
        end
        local tx = area.x + u * 4 + math.floor(hot * 2) * u
        if row.icon then
            UI.icon(row.icon, tx, ry + 6, 14)
            tx = tx + 20
        end
        UI.text(row.label, tx, ry + 4, 13, row.color or UI.colors.text, isSelected and 1 or 0.85)
        if row.detail then
            local font = Style.font(11)
            UI.text(row.detail, area.x + area.w - u * 4 - font:getWidth(row.detail), ry + 6, 11, UI.colors.muted)
        end
    end
    love.graphics.setScissor()
    UI.alpha = e
end

function Common.drawStatus(menu, x, y)
    local mp = Common.net()
    if mp.state == "connecting" then
        local dots = string.rep(".", math.floor(love.timer.getTime() * 3) % 4)
        UI.text("Connecting to " .. tostring(mp.address) .. dots, x, y, 13, UI.colors.troops)
    elseif mp.error then
        UI.text(mp.error, x, y, 13, UI.colors.bad)
    end
end

return Common
