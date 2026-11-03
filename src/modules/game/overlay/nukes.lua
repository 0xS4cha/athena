local Style = require("src.modules.hud.style")
local Config = require("src.config.game")
local Interaction = require("src.modules.game.interaction")
local Nukes = require("src.modules.game.systems.nukes")
local Overlay = require("src.modules.game.overlay.shared")

local floor = math.floor

function Overlay.drawNukeAlerts(game, camera)
    local alerts = game.nukeAlerts
    if not alerts or #alerts == 0 then return end
    local time = love.timer.getTime()
    local pulse = 0.55 + 0.45 * math.sin(time * 10)
    local size = math.max(2, floor(camera.scale))
    for _, nuke in ipairs(alerts) do
        if not nuke.dead then
            local def = Config.nukes[nuke.nukeKind]
            local radius = def.outer or 12
            Overlay.pixelCircle(camera, nuke.toX, nuke.toY, radius, { 1, 0.25, 0.2 }, pulse, time * 0.6, true)
            Overlay.pixelCircle(camera, nuke.toX, nuke.toY, (def.inner or 6), { 1, 0.6, 0.3 }, pulse * 0.8, -time * 0.9)
            love.graphics.setColor(1, 0.3, 0.25, 0.8)
            for k = -3, 3 do
                local hx, hy = camera:toScreen(floor(nuke.toX) + k, floor(nuke.toY))
                local vx, vy = camera:toScreen(floor(nuke.toX), floor(nuke.toY) + k)
                love.graphics.rectangle("fill", hx, hy, size, size)
                love.graphics.rectangle("fill", vx, vy, size, size)
            end
            local dx, dy = nuke.toX - nuke.x, nuke.toY - nuke.y
            local length = math.sqrt(dx * dx + dy * dy)
            love.graphics.setColor(1, 0.3, 0.25, 0.55)
            for d = 0, length, 3 do
                local sx, sy = camera:toScreen(floor(nuke.x + dx * d / length), floor(nuke.y + dy * d / length))
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end
end

function Overlay.dashedLine(camera, ax, ay, bx, by, color, alpha, spacing)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end
    local size = math.max(2, floor(camera.scale))
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    for d = 0, length, spacing do
        local sx, sy = camera:toScreen(floor(ax + dx * d / length), floor(ay + dy * d / length))
        love.graphics.rectangle("fill", sx, sy, size, size)
    end
end

function Overlay.drawNukePreview(game, camera)
    local mx, my = love.mouse.getPosition()
    local mouseTile = game.map:tileAt(camera:toWorld(mx, my))
    local kind, tile = Interaction.previewTarget(game, mouseTile)
    if not kind then return end
    local preview = Nukes.preview(game, game.human, kind, tile)
    local def = preview.def
    local time = love.timer.getTime()
    local pulse = 0.7 + 0.3 * math.sin(time * 6)
    local hot = preview.ok and { 1, 0.35, 0.2 } or { 0.6, 0.62, 0.68 }
    local warm = preview.ok and { 1, 0.7, 0.3 } or { 0.75, 0.77, 0.82 }
    local cx, cy = camera:toScreen(preview.x, preview.y)
    local scale = camera.scale
    local size = math.max(2, floor(scale))
    if preview.silo then
        Overlay.pixelCircle(camera, preview.silo.x, preview.silo.y, 6, Style.colors.gold, 0.9, time, true)
        Overlay.dashedLine(camera, preview.silo.x, preview.silo.y, preview.x, preview.y, Style.colors.gold, 0.6, 3)
    end
    if kind == "mirv" then
        local half = def.spread * scale
        love.graphics.setColor(hot[1], hot[2], hot[3], 0.1)
        love.graphics.rectangle("fill", cx - half, cy - half, half * 2, half * 2)
        love.graphics.setColor(hot[1], hot[2], hot[3], 0.8 * pulse)
        for k = -def.spread, def.spread, 3 do
            for _, p in ipairs({ { k, -def.spread }, { k, def.spread }, { -def.spread, k }, { def.spread, k } }) do
                local sx, sy = camera:toScreen(floor(preview.x + p[1]), floor(preview.y + p[2]))
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    else
        love.graphics.setColor(warm[1], warm[2], warm[3], 0.14)
        love.graphics.circle("fill", cx, cy, def.outer * scale)
        love.graphics.setColor(hot[1], hot[2], hot[3], 0.28)
        love.graphics.circle("fill", cx, cy, def.inner * scale)
        Overlay.pixelCircle(camera, preview.x, preview.y, def.outer, warm, 0.9 * pulse, time * 0.4, true)
        Overlay.pixelCircle(camera, preview.x, preview.y, def.inner, hot, pulse, -time * 0.6, true)
        if #preview.friendlyTiles > 0 and time % 0.6 < 0.4 then
            love.graphics.setColor(1, 1, 1, 0.75)
            local map = game.map
            for _, i in ipairs(preview.friendlyTiles) do
                local x, y = map:coords(i)
                local sx, sy = camera:toScreen(x, y)
                love.graphics.rectangle("fill", sx, sy, math.max(1, scale), math.max(1, scale))
            end
        end
    end
    local samRange = Config.units.sam.range
    for _, sam in ipairs(preview.sams) do
        Overlay.pixelCircle(camera, sam.x, sam.y, samRange, { 1, 0.25, 0.2 }, 0.55, -time * 0.3)
        local sx, sy = camera:toScreen(sam.x, sam.y)
        love.graphics.setColor(1, 0.25, 0.2, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.line(sx - 6, sy - 6, sx + 6, sy + 6)
        love.graphics.line(sx - 6, sy + 6, sx + 6, sy - 6)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setColor(hot[1], hot[2], hot[3], 1)
    for k = -4, 4 do
        if k ~= 0 then
            love.graphics.rectangle("fill", cx + k * size * 1.5 - size / 2, cy - size / 2, size, size)
            love.graphics.rectangle("fill", cx - size / 2, cy + k * size * 1.5 - size / 2, size, size)
        end
    end
end

local function pixel(camera, x, y, size, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    local sx, sy = camera:toScreen(math.floor(x), math.floor(y))
    love.graphics.rectangle("fill", sx, sy, size, size)
end

local function pixelRing(camera, cx, cy, radius, size, step)
    local count = math.max(16, math.floor(radius * 6.28 / step))
    for k = 0, count - 1 do
        local angle = k / count * math.pi * 2
        local sx, sy = camera:toScreen(math.floor(cx + math.cos(angle) * radius), math.floor(cy + math.sin(angle) * radius))
        love.graphics.rectangle("fill", sx, sy, size, size)
    end
end

local bit = require("bit")

local function noise(a, b)
    return bit.band(bit.bxor(a * 73856093, b * 19349663), 0x7fffffff) % 97
end

function Overlay.drawNuke(game, camera, unit)
    local def = Config.nukes[unit.nukeKind]
    local size = math.max(1.5, camera.scale)
    local blink = math.floor(love.timer.getTime() * 4) % 2 == 0
    if unit.nukeKind ~= "warhead" then
        love.graphics.setColor(1, 0.2, 0.15, blink and 0.9 or 0.4)
        pixelRing(camera, unit.toX, unit.toY, def.outer, size, 2)
        love.graphics.setColor(1, 0.45, 0.2, 0.7)
        pixelRing(camera, unit.toX, unit.toY, def.inner, size, 3)
        local dx, dy = unit.x - unit.fromX, unit.y - unit.fromY
        local length = math.sqrt(dx * dx + dy * dy)
        local trail = math.min(length, 40)
        for k = 1, math.floor(trail) do
            local t = k / math.max(1, length)
            local fade = 1 - k / (trail + 1)
            local shade = 0.55 + (noise(k, game.tick) % 3) * 0.1
            pixel(camera, unit.x - dx * t, unit.y - dy * t, size, shade, shade, shade, 0.7 * fade)
        end
    end
    pixel(camera, unit.x, unit.y, size, 1, 1, 0.85, 1)
    if unit.nukeKind ~= "warhead" then
        pixel(camera, unit.x + 1, unit.y, size, 1, 0.55, 0.15, 1)
        pixel(camera, unit.x, unit.y + 1, size, 1, 0.55, 0.15, 1)
        pixel(camera, unit.x + 1, unit.y + 1, size, 0.9, 0.2, 0.1, 1)
    end
end

local FIRE = {
    { 1, 1, 0.85 },
    { 1, 0.85, 0.3 },
    { 1, 0.55, 0.12 },
    { 0.85, 0.22, 0.08 },
    { 0.45, 0.42, 0.4 }
}

function Overlay.drawExplosions(game, camera)
    local frame = math.floor(love.timer.getTime() * 10)
    for _, e in ipairs(game.explosions or {}) do
        local age = (game.tick - e.tick) / Config.explosionTicks
        local alpha = 1 - age
        local radius = e.radius * math.min(1, 0.3 + age * 2)
        local step = radius > 40 and 2 or 1
        local size = math.max(1, camera.scale) * step
        local cx, cy = math.floor(e.x), math.floor(e.y)
        local r = math.floor(radius)
        for dy = -r, r, step do
            for dx = -r, r, step do
                local d2 = dx * dx + dy * dy
                if d2 <= r * r then
                    local n = noise(cx + dx, cy + dy + frame)
                    if n < 60 then
                        local heat = math.sqrt(d2) / math.max(1, r) + age * 1.4
                        local index = math.min(#FIRE, 1 + math.floor(heat * 2.5 + (n % 3) * 0.4))
                        local c = FIRE[index]
                        pixel(camera, cx + dx, cy + dy, size, c[1], c[2], c[3], alpha * (index == #FIRE and 0.6 or 0.9))
                    end
                end
            end
        end
        love.graphics.setColor(1, 1, 1, alpha * 0.9)
        pixelRing(camera, cx, cy, e.radius * (0.6 + age * 1.2), math.max(1.5, camera.scale), 1.5)
        if e.radius >= 20 and age > 0.2 then
            local rise = e.radius * 0.9 * math.min(1, age * 1.5)
            local cap = math.floor(e.radius * 0.35)
            for dy = -cap, math.floor(cap / 2) do
                for dx = -cap, cap do
                    if dx * dx + dy * dy * 3 <= cap * cap then
                        local n = noise(dx, dy + frame)
                        local c = FIRE[n % 2 == 0 and 5 or 3]
                        pixel(camera, cx + dx, cy - rise + dy, math.max(1, camera.scale), c[1], c[2], c[3], alpha * 0.85)
                    end
                end
            end
            for y = 0, math.floor(rise) do
                local width = math.max(1, math.floor(cap * 0.25))
                for dx = -width, width do
                    pixel(camera, cx + dx, cy - y, math.max(1, camera.scale), 0.5, 0.45, 0.42, alpha * 0.7)
                end
            end
        end
    end
end

return Overlay
