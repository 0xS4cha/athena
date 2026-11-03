local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")
local Threats = require("src.modules.game.threats")
local Diplomap = require("src.modules.game.diplomap")
local Overlay = require("src.modules.game.overlay.shared")

local floor = math.floor

function Overlay.drawLegend(title, entries)
    local _, H = love.graphics.getDimensions()
    local u = Pixel.unit
    local w = 190
    local h = 34 + #entries * 18
    local x, y = 15, H - 50 - h
    Style.box(x, y, w, h, { corners = true })
    Pixel.text(title, x + u * 4, y + 6, 12, Style.colors.gold)
    for k, entry in ipairs(entries) do
        local ry = y + 28 + (k - 1) * 18
        local c = entry.color
        love.graphics.setColor(0.03, 0.04, 0.08, 1)
        love.graphics.rectangle("fill", x + u * 4, ry + 2, 12, 12)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", x + u * 4 + 2, ry + 4, 8, 8)
        Pixel.text(entry.label, x + u * 4 + 20, ry, 11, Style.colors.text)
    end
end

local function drawArrow(camera, fromX, fromY, toX, toY, thickness, color, alpha)
    local ax, ay = camera:toScreen(fromX, fromY)
    local bx, by = camera:toScreen(toX, toY)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 4 then return end
    dx, dy = dx / length, dy / length
    local width = 2 + thickness * 2
    local head = 8 + thickness * 3
    local hx, hy = bx - dx * head, by - dy * head
    local wing = { bx, by, hx - dy * head * 0.7, hy + dx * head * 0.7, hx + dy * head * 0.7, hy - dx * head * 0.7 }
    love.graphics.setLineStyle("rough")
    love.graphics.setColor(0.03, 0.04, 0.08, 0.7 * alpha)
    love.graphics.setLineWidth(width + 4)
    love.graphics.line(ax, ay, hx, hy)
    love.graphics.polygon("fill", wing[1] + dx * 3, wing[2] + dy * 3, wing[3] - dx * 2 - dy * 2, wing[4] - dy * 2 + dx * 2, wing[5] - dx * 2 + dy * 2, wing[6] - dy * 2 - dx * 2)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.setLineWidth(width)
    love.graphics.line(ax, ay, hx, hy)
    love.graphics.polygon("fill", wing)
    love.graphics.setLineWidth(1)
end

function Overlay.drawThreats(game, camera, W, H)
    local human = game.human
    if not human.alive or game.options.spectator or game.phase ~= "playing" then return end
    local fronts = Threats.fronts(game, human)
    local map = game.map
    local time = love.timer.getTime()
    local size = math.max(1, floor(camera.scale))
    for _, front in ipairs(fronts) do
        local level = Threats.levels[front.level]
        local c = level.color
        local pulse = front.level >= 4 and (0.6 + 0.4 * math.sin(time * 6)) or 1
        for _, tile in ipairs(front.tiles) do
            local x, y = map:coords(tile)
            local sx, sy = camera:toScreen(x, y)
            if sx > -size * 3 and sy > -size * 3 and sx < W + size * 3 and sy < H + size * 3 then
                local glow = size * (front.level + 1)
                love.graphics.setColor(c[1], c[2], c[3], (0.12 + 0.05 * front.level) * pulse)
                love.graphics.rectangle("fill", sx - glow, sy - glow, size + glow * 2, size + glow * 2)
                love.graphics.setColor(c[1], c[2], c[3], 0.95 * pulse)
                love.graphics.rectangle("fill", sx - size, sy - size, size * 3, size * 3)
            end
        end
    end
    Overlay.threatLabels = {}
    for k = 1, math.min(8, #fronts) do
        local front = fronts[k]
        if front.level >= 2 then
            local c = Threats.levels[front.level].color
            local ex, ey = front.player:center()
            local dx, dy = front.x - ex, front.y - ey
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 1 then
                dx, dy = dx / distance, dy / distance
                local reach = math.max(25, math.min(70, distance * 0.7))
                local fromX, fromY = front.x - dx * reach, front.y - dy * reach
                local pulse = front.level >= 4 and (0.65 + 0.35 * math.sin(time * 6)) or 0.9
                drawArrow(camera, fromX, fromY, front.x - dx * 4, front.y - dy * 4, front.level, c, pulse)
                local sx, sy = camera:toScreen(fromX, fromY)
                local text = (front.estimated and "~" or "") .. Format.number(front.troops) .. string.format("  x%.1f", front.score)
                Overlay.threatLabels[#Overlay.threatLabels + 1] = { text = text, x = sx, y = sy, color = c }
            end
        end
    end
end

function Overlay.drawThreatLegend(game)
    if not game.human.alive or game.options.spectator then return end
    local font = Style.font(12)
    for _, label in ipairs(Overlay.threatLabels or {}) do
        local w, h = font:getWidth(label.text) + 14, font:getHeight() + 6
        local x, y = floor(label.x - w / 2), floor(label.y - h - 6)
        Style.box(x, y, w, h, { accent = label.color })
        love.graphics.setColor(label.color[1], label.color[2], label.color[3], 1)
        love.graphics.rectangle("fill", x + 3, y + 3, 3, h - 6)
        Pixel.text(label.text, x + 9, y + 2, 12, Style.colors.text)
    end
    local entries = {}
    for _, level in ipairs(Threats.levels) do
        entries[#entries + 1] = { label = level.label, color = level.color }
    end
    Overlay.drawLegend("THREATS", entries)
end

function Overlay.drawDiplomacyLegend()
    local entries = {}
    for _, category in ipairs(Diplomap.categories) do
        entries[#entries + 1] = { label = category.label, color = category.color }
    end
    Overlay.drawLegend("DIPLOMACY", entries)
end

return Overlay
