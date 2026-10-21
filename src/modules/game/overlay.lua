local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Icons = require("src.modules.hud.icons")
local Rails = require("src.modules.game.systems.rails")
local Supply = require("src.modules.game.systems.supply")
local Attack = require("src.modules.game.systems.attack")
local Structures = require("src.modules.game.structures")
local Pixel = require("src.modules.hud.pixel")
local Vision = require("src.modules.game.systems.vision")
local Units = require("src.modules.game.systems.units")
local Threats = require("src.modules.game.threats")
local Diplomap = require("src.modules.game.diplomap")

local Overlay = {}

local LABEL_REFRESH = 20
local LABEL_SEARCH = 30

local function labelPosition(game, player)
    local cache = player.label
    if cache and cache.tick > game.tick - LABEL_REFRESH and cache.tiles == player.tiles then
        return cache.x, cache.y
    end
    local map = game.map
    local cx, cy = player:center()
    local tile = map:tileAt(cx, cy)
    local x, y = cx, cy
    if not tile or map.owner[tile] ~= player.id then
        local near = map:findNear(cx, cy, LABEL_SEARCH, function(i)
            return map.owner[i] == player.id
        end)
        if near then
            local nx, ny = map:coords(near)
            x, y = nx + 0.5, ny + 0.5
        end
    end
    player.label = { tick = game.tick, tiles = player.tiles, x = x, y = y }
    return x, y
end

local function shadowText(text, x, y, color)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, x, y)
end

function Overlay.drawLabel(game, camera, player, W, H)
    local size = math.min(36, math.sqrt(player.tiles) * camera.scale * 2 / (#player.name + 4))
    if size < 8 then return end
    local wx, wy = labelPosition(game, player)
    local sx, sy = camera:toScreen(wx, wy)
    if sx < -200 or sy < -100 or sx > W + 200 or sy > H + 100 then return end

    local font = Style.font(size)
    local small = Style.font(math.max(6, size * 0.7))
    local name = player.name
    local troops = Vision.troopsText(game, game.human, player)
    local nameW = font:getWidth(name)
    local flagH = size >= 12 and player.flag and size * 0.75 or 0
    local flagW = flagH * 4 / 3
    local total = nameW + (flagH > 0 and flagW + 4 or 0)
    local x = sx - total / 2
    local y = sy - font:getHeight() * 0.8

    if flagH > 0 then
        Style.flag(player.flag, x, y + (font:getHeight() - flagW) / 2, flagW)
        x = x + flagW + 4
    end
    love.graphics.setFont(font)
    local color = player == game.human and { 1, 1, 0.75, 1 } or { 1, 1, 1, 1 }
    shadowText(name, math.floor(x), math.floor(y), color)
    love.graphics.setFont(small)
    shadowText(troops, math.floor(sx - small:getWidth(troops) / 2), math.floor(y + font:getHeight()), { 0.92, 0.92, 0.95, 1 })

    if Overlay.decorateLabel then
        Overlay.decorateLabel(game, player, sx, y, size)
    end
end

Overlay.structureZoomStart = 1.6
Overlay.structureZoomFull = 3.5

local RADAR_GREEN = { 0.45, 1, 0.55 }

function Overlay.isVisible(game, unit)
    local human = game.human
    if not human.alive or unit.owner:isFriendly(human) then
        return true
    end
    local interval = Units.isBuilding(unit.kind) and Config.visionRefreshTicks or 4
    if unit.visionTick and game.tick - unit.visionTick < interval then
        return unit.visible
    end
    unit.visionTick = game.tick
    unit.visible = Vision.live(game, human, unit)
    return unit.visible
end

function Overlay.structureAt(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    for dy = -2, 2 do
        for dx = -2, 2 do
            if map:isValid(x + dx, y + dy) then
                local unit = game.buildingAt[map:index(x + dx, y + dy)]
                if unit and not unit.dead and Overlay.isVisible(game, unit) then
                    return unit
                end
            end
        end
    end
    return nil
end

function Overlay.structureAlpha(camera)
    return math.max(0, math.min(1, (camera.scale - Overlay.structureZoomStart) / (Overlay.structureZoomFull - Overlay.structureZoomStart)))
end

local floor = math.floor
local BADGE_MIN_SCALE = 0.7
local FLASH_TICKS = 12
local WINDOW_LIGHT = { 1, 0.86, 0.42 }
local SMOKE = { 0.42, 0.42, 0.47 }
local BLOCKADE = { 0.95, 0.2, 0.15, 1 }
local WHITE = { 1, 1, 1 }

local function lighten(c, t)
    return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t }
end

local function underAttack(game, player)
    local cache = game.overlayThreats
    if not cache or cache.tick ~= game.tick then
        cache = { tick = game.tick }
        game.overlayThreats = cache
    end
    local value = cache[player.id]
    if value == nil then
        value = #Attack.incoming(game, player) > 0
        cache[player.id] = value
    end
    return value
end

function Overlay.pixelCircle(camera, cx, cy, radius, color, alpha, rotation, dense)
    local count = math.max(16, floor(2 * math.pi * radius / (dense and 1 or 2.5)))
    local size = math.max(2, floor(camera.scale))
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    for k = 0, count - 1, dense and 1 or 2 do
        if dense and k % 4 == 3 then goto continue end
        local a = k / count * math.pi * 2 + (rotation or 0)
        local sx, sy = camera:toScreen(floor(cx + math.cos(a) * radius), floor(cy + math.sin(a) * radius))
        love.graphics.rectangle("fill", sx, sy, size, size)
        ::continue::
    end
end

function Overlay.drawBadge(unit, camera, alpha)
    local glyph = Structures.badges[unit.kind]
    if not glyph then return end
    local sx, sy = camera:toScreen(unit.x, unit.y)
    local u = 2
    local size = #glyph * u + 4
    local x, y = floor(sx - size / 2), floor(sy - size / 2)
    if unit.buildLeft > 0 then
        alpha = alpha * 0.55
    end
    local c = unit.owner.color
    love.graphics.setColor(0.06, 0.05, 0.09, alpha)
    love.graphics.rectangle("fill", x, y - 1, size, size + 2)
    love.graphics.rectangle("fill", x - 1, y, size + 2, size)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.rectangle("fill", x + 1, y, size - 2, size)
    love.graphics.rectangle("fill", x, y + 1, size, size - 2)
    local bright = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11 > 0.62
    if bright then
        love.graphics.setColor(0.06, 0.05, 0.09, alpha)
    else
        love.graphics.setColor(1, 1, 1, alpha)
    end
    for row = 1, #glyph do
        for col = 1, #glyph[row] do
            if glyph[row]:sub(col, col) == "x" then
                love.graphics.rectangle("fill", x + 2 + (col - 1) * u, y + 2 + (row - 1) * u, u, u)
            end
        end
    end
end

local function drawProgress(x, y, width, scale, progress, color, alpha)
    local h = math.max(3, floor(scale * 0.8))
    local cells = Structures.SIZE
    love.graphics.setColor(0.06, 0.05, 0.09, alpha * 0.85)
    love.graphics.rectangle("fill", x - 1, y - 1, width + 2, h + 2)
    for k = 0, cells - 1 do
        if (k + 0.5) / cells <= progress then
            love.graphics.setColor(color[1], color[2], color[3], alpha)
        else
            love.graphics.setColor(0.2, 0.22, 0.3, alpha)
        end
        love.graphics.rectangle("fill", x + floor(k * width / cells), y, math.max(1, floor(width / cells) - 1), h)
    end
end

local function drawCooldown(game, camera, unit, alpha)
    local total = Config.units[unit.kind].cooldownTicks
    if not total or unit.cooldown <= 0 then return end
    local segments = 12
    local filled = floor((1 - unit.cooldown / total) * segments)
    local size = math.max(2, floor(camera.scale * 0.8))
    local c = lighten(unit.owner.color, 0.3)
    for k = 0, segments - 1 do
        local a = k / segments * math.pi * 2 - math.pi / 2
        local sx, sy = camera:toScreen(unit.x + math.cos(a) * 5, unit.y + math.sin(a) * 5)
        if k < filled then
            love.graphics.setColor(c[1], c[2], c[3], alpha)
        else
            love.graphics.setColor(0.06, 0.05, 0.09, alpha * 0.6)
        end
        love.graphics.rectangle("fill", floor(sx - size / 2), floor(sy - size / 2), size, size)
    end
end

local function drawAnimations(game, camera, unit, def, ox, oy, alpha, time)
    local scale = camera.scale
    if def.windows and def.cells then
        for k, cell in ipairs(def.cells) do
            local slot = floor(time / 1.7 + k * 0.61 + unit.id * 0.37)
            if (unit.id * 31 + k * 17 + slot * 13) % 5 < 3 then
                love.graphics.setColor(WINDOW_LIGHT[1], WINDOW_LIGHT[2], WINDOW_LIGHT[3], alpha * 0.9)
                love.graphics.rectangle("fill", ox + cell[1] * scale, oy + cell[2] * scale, scale, scale)
            end
        end
    end
    if def.smoke then
        local bx = ox + (def.smoke[1] + 1) * scale
        local by = oy + (def.smoke[2] + 1) * scale
        for p = 0, 2 do
            local phase = (time * 0.5 + p / 3 + unit.id * 0.13) % 1
            local size = math.max(1, floor(scale * (0.9 + phase * 0.8)))
            local x = bx + floor((phase * 1.4 + math.sin(time * 2 + p) * 0.3) * scale)
            local y = by - floor((0.5 + phase * 3.5) * scale)
            love.graphics.setColor(SMOKE[1], SMOKE[2], SMOKE[3], alpha * 0.8 * (1 - phase))
            love.graphics.rectangle("fill", x, y, size, size)
        end
    end
    if def.beacon and unit.owner.upkeepPaid ~= false and (time * 1.5 + unit.id * 0.3) % 1 < 0.35 then
        local x, y = ox + (def.beacon[1] + 1) * scale, oy + (def.beacon[2] + 1) * scale
        love.graphics.setColor(1, 0.95, 0.6, alpha * 0.35)
        love.graphics.rectangle("fill", x - scale, y - scale, scale * 3, scale * 3)
        love.graphics.setColor(1, 0.95, 0.6, alpha)
        love.graphics.rectangle("fill", x, y, scale, scale)
    end
    if def.light and unit.cooldown == 0 and (time * 2) % 1 < 0.5 then
        local x, y = ox + (def.light[1] + 1) * scale, oy + (def.light[2] + 1) * scale
        love.graphics.setColor(1, 0.25, 0.2, alpha * 0.4)
        love.graphics.rectangle("fill", x - scale, y - scale, scale * 3, scale * 3)
        love.graphics.setColor(1, 0.4, 0.3, alpha)
        love.graphics.rectangle("fill", x, y, scale, scale)
    end
    if def.shine then
        local col = floor(((time + unit.id * 0.5) % 3) / 0.5 * Structures.SIZE / 2)
        if col >= 1 and col <= 5 then
            love.graphics.setColor(1, 1, 1, alpha * 0.6)
            love.graphics.rectangle("fill", ox + col * scale, oy + 2 * scale, scale, scale)
        end
    end
    if unit.kind == "defensePost" and underAttack(game, unit.owner) then
        local phase = (time * 0.8) % 1
        Overlay.pixelCircle(camera, unit.x, unit.y, 4 + phase * 10, lighten(unit.owner.color, 0.4), alpha * (1 - phase))
    end
end

function Overlay.drawBuilding(game, camera, unit)
    local detail = Overlay.structureAlpha(camera)
    if detail < 1 and camera.scale >= BADGE_MIN_SCALE and unit.kind ~= "capital" then
        Overlay.drawBadge(unit, camera, (1 - detail) * 0.9)
    end
    if detail <= 0 or not Structures.has(unit.kind) then return end
    local def = Structures.art[unit.kind]
    local scale = camera.scale
    local half = floor(Structures.SIZE / 2)
    local ox, oy = camera:toScreen(floor(unit.x) - half, floor(unit.y) - half)
    local time = love.timer.getTime()
    local offline = unit.kind == "radar" and unit.buildLeft == 0 and not Vision.online(unit)
    local frame = offline and 1 or Structures.frame(unit.kind, time + unit.id * 0.37)
    local owner = unit.owner.color
    local footprint = Structures.SIZE * scale
    local cell = Structures.CELL

    if unit.buildLeft > 0 then
        local progress = 1 - unit.buildLeft / math.max(1, unit.buildTotal or 1)
        local rows = floor(progress * cell + 0.5)
        Structures.draw(unit.kind, ox, oy, scale, owner, detail * 0.28, { frame = frame })
        if rows > 0 then
            Structures.draw(unit.kind, ox, oy, scale, owner, detail, { frame = frame, rows = rows })
            local edge = lighten(owner, 0.5)
            love.graphics.setColor(edge[1], edge[2], edge[3], detail * (0.6 + 0.4 * math.sin(time * 8)))
            love.graphics.rectangle("fill", ox, oy + (cell - rows) * scale, footprint, math.max(1, floor(scale * 0.4)))
        end
        drawProgress(ox, oy + cell * scale + 2, footprint, scale, progress, lighten(owner, 0.25), detail)
        return
    end

    Structures.draw(unit.kind, ox, oy, scale, owner, detail, { frame = frame })
    drawAnimations(game, camera, unit, def, ox, oy, detail, time)
    local now = game.tick + game.accumulator * Config.tickRate
    local stamp = math.max(unit.completedTick or -1000, unit.capturedTick or -1000)
    local age = now - stamp
    if age >= 0 and age < FLASH_TICKS then
        Structures.layer(unit.kind, frame, "silhouette", ox, oy, scale, WHITE, detail * (1 - age / FLASH_TICKS))
    end
    drawCooldown(game, camera, unit, detail)
    if unit.blockaded or offline then
        Pixel.corners(ox, oy, footprint, footprint, BLOCKADE, detail * (0.55 + 0.45 * math.sin(time * 6)))
    end
end

function Overlay.drawRadarSweeps(game, camera)
    local human = game.human
    if not human.alive or game.options.spectator then return end
    local radars = Vision.radars(game, human)
    if #radars == 0 then return end
    local now = game.tick + game.accumulator * Config.tickRate
    local size = math.max(2, floor(camera.scale))
    for _, radar in ipairs(radars) do
        local range = Vision.radarRange(game, radar)
        local cx, cy = camera:toScreen(radar.x, radar.y)
        local radius = range * camera.scale
        love.graphics.setColor(RADAR_GREEN[1], RADAR_GREEN[2], RADAR_GREEN[3], 0.07)
        love.graphics.circle("fill", cx, cy, radius)
        local beam = Vision.beam(radar, now)
        for slice = 0, 11 do
            love.graphics.setColor(RADAR_GREEN[1], RADAR_GREEN[2], RADAR_GREEN[3], 0.32 * (1 - slice / 12))
            love.graphics.arc("fill", "pie", cx, cy, radius, beam - (slice + 1) * 0.05, beam - slice * 0.05, 4)
        end
        Overlay.pixelCircle(camera, radar.x + 1, radar.y + 1, range, { 0.03, 0.05, 0.08 }, 0.6, 0, true)
        Overlay.pixelCircle(camera, radar.x, radar.y, range, RADAR_GREEN, 0.85, 0, true)
        local cos, sin = math.cos(beam), math.sin(beam)
        for r = 1, range do
            local sx, sy = camera:toScreen(floor(radar.x + cos * r), floor(radar.y + sin * r))
            love.graphics.setColor(0.03, 0.05, 0.08, 0.5)
            love.graphics.rectangle("fill", sx + 1, sy + 1, size, size)
            love.graphics.setColor(RADAR_GREEN[1], RADAR_GREEN[2], RADAR_GREEN[3], 0.95)
            love.graphics.rectangle("fill", sx, sy, size, size)
        end
    end
end

function Overlay.drawEchoes(game, camera)
    local human = game.human
    if not human.alive or game.options.spectator then return end
    local detail = Overlay.structureAlpha(camera)
    local now = game.tick + game.accumulator * Config.tickRate
    local scale = camera.scale
    local half = floor(Structures.SIZE / 2)
    for unit, echo in pairs(game.echoes) do
        local age = now - echo.tick
        if age < 8 then
            Overlay.pixelCircle(camera, echo.x, echo.y, 2 + age * 1.2, RADAR_GREEN, 0.8 * (1 - age / 8))
        end
        if unit.dead or not Overlay.isVisible(game, unit) then
            local fade = math.max(0, 1 - age / Config.radarGhostTicks)
            if Units.isBuilding(unit.kind) then
                if detail > 0 and Structures.has(unit.kind) then
                    local ox, oy = camera:toScreen(floor(echo.x) - half, floor(echo.y) - half)
                    Structures.draw(unit.kind, ox, oy, scale, unit.owner.color, detail * (0.2 + 0.45 * fade))
                    Structures.layer(unit.kind, 1, "silhouette", ox, oy, scale, RADAR_GREEN, detail * 0.35 * fade)
                end
                if detail < 1 and scale >= BADGE_MIN_SCALE then
                    Overlay.drawBadge({ kind = unit.kind, owner = unit.owner, x = echo.x, y = echo.y, buildLeft = 0 }, camera, (1 - detail) * (0.3 + 0.6 * fade))
                end
            else
                local color = unit.kind == "nuke" and { 1, 0.3, 0.25 } or RADAR_GREEN
                local sx, sy = camera:toScreen(echo.x, echo.y)
                local blip = math.max(3, floor(scale * 1.5))
                love.graphics.setColor(color[1], color[2], color[3], 0.25 * fade)
                love.graphics.rectangle("fill", floor(sx - blip * 1.5), floor(sy - blip * 1.5), blip * 3, blip * 3)
                love.graphics.setColor(color[1], color[2], color[3], 0.9 * fade)
                love.graphics.rectangle("fill", floor(sx - blip / 2), floor(sy - blip / 2), blip, blip)
            end
        end
    end
end

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

function Overlay.drawHoveredStructure(game, camera)
    local detail = Overlay.structureAlpha(camera)
    if detail <= 0 or game.options.spectator then return end
    local mx, my = love.mouse.getPosition()
    local tile = game.map:tileAt(camera:toWorld(mx, my))
    local unit = tile and Overlay.structureAt(game, tile)
    if not unit or not Structures.has(unit.kind) then return end
    local def = Config.units[unit.kind]
    local time = love.timer.getTime()
    local range = unit.kind == "radar" and Vision.radarRange(game, unit) or def.range or def.radius
    if range then
        Overlay.pixelCircle(camera, unit.x, unit.y, range, lighten(unit.owner.color, 0.35), detail * 0.8, time * 0.15)
    end
    local half = floor(Structures.SIZE / 2)
    local ox, oy = camera:toScreen(floor(unit.x) - half, floor(unit.y) - half)
    local footprint = Structures.SIZE * camera.scale
    local pad = math.max(2, floor(camera.scale * 0.5 + math.sin(time * 5) * 1.5))
    Pixel.corners(ox - pad, oy - pad, footprint + pad * 2, footprint + pad * 2, Style.colors.gold, detail)
end

local RAIL_DARK = { 0.24, 0.2, 0.17 }
local RAIL_LIGHT = { 0.5, 0.45, 0.4 }

function Overlay.drawRail(game, camera, rail, alpha, W, H)
    local map = game.map
    local size = camera.scale
    local tiles = rail.tiles
    for k = 1, math.floor(rail.built) do
        local x, y = map:coords(tiles[k])
        local sx, sy = camera:toScreen(x, y)
        if sx > -size and sy > -size and sx < W and sy < H then
            local c = k % 2 == 0 and RAIL_DARK or RAIL_LIGHT
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.rectangle("fill", sx, sy, size, size)
        end
    end
    if rail.built >= #tiles and alpha >= 1 then
        local tx, ty = Rails.trainPosition(game, rail)
        local sx, sy = camera:toScreen(math.floor(tx), math.floor(ty))
        local c = rail.a.owner.color
        love.graphics.setColor(0.08, 0.08, 0.1, 1)
        love.graphics.rectangle("fill", sx - size * 0.25, sy - size * 0.25, size * 1.5, size * 1.5)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", sx, sy, size, size)
    end
end

function Overlay.drawRails(game, camera)
    if not game.rails or #game.rails == 0 then return end
    local alpha = Overlay.structureAlpha(camera)
    if alpha <= 0 then return end
    local W, H = love.graphics.getDimensions()
    for _, rail in ipairs(game.rails) do
        if Overlay.isVisible(game, rail.a) and Overlay.isVisible(game, rail.b) then
            Overlay.drawRail(game, camera, rail, alpha, W, H)
        end
    end
end

function Overlay.drawUnits(game, camera, W, H)
    local radius = math.max(2.5, math.min(11, camera.scale * 2.5))
    for _, unit in ipairs(game.units) do
        if not unit.dead and Overlay.isVisible(game, unit) then
            local sx, sy = camera:toScreen(unit.x, unit.y)
            if sx > -20 and sy > -20 and sx < W + 20 and sy < H + 20 then
                local draw = Overlay.unitDrawers[unit.kind] or Overlay.drawBuilding
                draw(game, camera, unit, radius)
            end
        end
    end
end

local SHIP_COLORS = {
    d = { 0.16, 0.14, 0.13 },
    l = { 0.95, 0.94, 0.88 },
    y = { 0.95, 0.78, 0.3 },
    g = { 0.5, 0.52, 0.56 }
}

Overlay.ships = {
    transport = { "..l..", ".lll.", "cccc.", ".dddd" },
    trade = { ".y.y.", "cyyy.", "ddddd", ".ddd." },
    warship = { "...g...", "..ggg..", "cccccgd", ".ddddd." }
}

local function heading(game, unit)
    local path = unit.path
    if not path or #path < 2 then return 1, 0 end
    local index = math.max(1, math.min(#path - 1, math.floor(unit.progress)))
    local map = game.map
    local ax, ay = map:coords(path[index])
    local bx, by = map:coords(path[math.min(#path, index + 2)])
    local dx, dy = bx - ax, by - ay
    if math.abs(dx) >= math.abs(dy) then
        return dx >= 0 and 1 or -1, 0
    end
    return 0, dy >= 0 and 1 or -1
end

function Overlay.drawShip(game, camera, unit)
    local sprite = Overlay.ships[unit.kind]
    if not sprite then return end
    local map = game.map
    local size = math.max(1.5, camera.scale)
    local hx, hy = heading(game, unit)
    local tx, ty = math.floor(unit.x), math.floor(unit.y)

    if unit.path and camera.scale >= 2 then
        local index = math.floor(unit.progress)
        for k = 1, 5 do
            local tile = unit.path[index - k]
            if tile then
                local x, y = map:coords(tile)
                local sx, sy = camera:toScreen(x, y)
                love.graphics.setColor(0.9, 0.95, 1, 0.5 * (1 - k / 6))
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end

    local owner = unit.owner.color
    local h = #sprite
    local w = #sprite[1]
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    for row = 1, h do
        local line = sprite[row]
        for col = 1, w do
            local ch = line:sub(col, col)
            if ch ~= "." then
                local ox, oy = col - 1 - cx, row - 1 - cy
                local px, py
                if hx ~= 0 then
                    px, py = ox * hx, oy
                else
                    px, py = -oy * hy, ox * hy
                end
                local color = ch == "c" and owner or SHIP_COLORS[ch]
                love.graphics.setColor(color[1], color[2], color[3], 1)
                local sx, sy = camera:toScreen(tx + px, ty + py)
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end

    if unit.troops and camera.scale >= 3 then
        local font = Style.font(10)
        love.graphics.setFont(font)
        local text = Format.number(unit.troops)
        local sx, sy = camera:toScreen(tx + 0.5, ty + cy + 1.5)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(text, sx - font:getWidth(text) / 2 + 1, sy + 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, sx - font:getWidth(text) / 2, sy)
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

Overlay.unitDrawers = {
    nuke = function(game, camera, unit)
        Overlay.drawNuke(game, camera, unit)
    end,
    transport = Overlay.drawShip,
    trade = Overlay.drawShip,
    warship = function(game, camera, unit)
        Overlay.drawShip(game, camera, unit)
        local max = Config.units.warship.health
        if unit.health and unit.health < max and camera.scale >= 2 then
            local size = camera.scale
            local tx, ty = math.floor(unit.x), math.floor(unit.y)
            for k = -3, 3 do
                local filled = (k + 4) / 7 <= unit.health / max
                if filled then
                    love.graphics.setColor(0.3, 0.9, 0.4, 1)
                else
                    love.graphics.setColor(0.6, 0.15, 0.12, 1)
                end
                local sx, sy = camera:toScreen(tx + k, ty - 3)
                love.graphics.rectangle("fill", sx, sy, size, size * 0.6)
            end
        end
    end
}

function Overlay.decorateLabel(game, player, sx, y, size)
    local human = game.human
    local marks = {}
    if player:isAlliedWith(human) then marks[#marks + 1] = "Team.png" end
    if player:hasPact(human) then marks[#marks + 1] = "Key.png" end
    if player.traitorUntil > game.tick then marks[#marks + 1] = "Unlocked.png" end
    if human.target == player.id then marks[#marks + 1] = "MagnifyingGlass.png" end
    for id in pairs(human.allies) do
        local ally = game.players[id]
        if ally and ally.target == player.id then
            marks[#marks + 1] = "MagnifyingGlass.png"
            break
        end
    end
    if player.embargo[human.id] or human.embargo[player.id] then marks[#marks + 1] = "Locked.png" end
    local iconSize = math.max(14, size * 0.8)
    local x = sx - (#marks * (iconSize + 2)) / 2
    for _, name in ipairs(marks) do
        local icon = Icons.get(name)
        if icon then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icon, x, y - iconSize - 2, 0, iconSize / icon:getWidth(), iconSize / icon:getHeight())
        end
        x = x + iconSize + 2
    end
    if player.emoji then
        local icon = Icons.get(player.emoji.icon)
        if icon then
            local s = math.max(18, size * 1.4)
            local bob = math.sin(love.timer.getTime() * 4) * 3
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle("fill", sx, y - iconSize - s / 2 - 6 + bob, s * 0.7)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icon, sx - s / 2, y - iconSize - s - 6 + bob, 0, s / icon:getWidth(), s / icon:getHeight())
        end
    end
end

function Overlay.drawSupply(game, camera)
    local points = Supply.points(game, game.human)
    if not points then return end
    local radius = Config.supplyRange
    local size = math.max(1, camera.scale)
    love.graphics.setColor(0.45, 1, 0.55, 0.8)
    local steps = math.max(24, math.floor(radius * 4))
    for k = 1, #points, 2 do
        local cx, cy = points[k], points[k + 1]
        for s = 0, steps - 1 do
            if s % 4 ~= 3 then
                local angle = s / steps * math.pi * 2
                local sx, sy = camera:toScreen(math.floor(cx + math.cos(angle) * radius), math.floor(cy + math.sin(angle) * radius))
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end
end

local COMBAT_COLORS = {
    { 1, 0.95, 0.7 },
    { 1, 0.6, 0.15 },
    { 0.95, 0.25, 0.1 }
}

function Overlay.drawCombat(game, camera, W, H)
    local combat = game.combat
    if not combat then return end
    local map = game.map
    local size = math.max(1.5, camera.scale)
    local frame = math.floor(love.timer.getTime() * 12)
    local window = Config.combatTicks
    for k = 1, #combat.tiles do
        local age = game.tick - combat.ticks[k]
        if age < window then
            local tile = combat.tiles[k]
            local x, y = map:coords(tile)
            local sx, sy = camera:toScreen(x, y)
            if sx > -size and sy > -size and sx < W and sy < H then
                local seed = (tile * 7 + frame) % 5
                if seed < 3 then
                    local c = COMBAT_COLORS[seed + 1]
                    love.graphics.setColor(c[1], c[2], c[3], 1 - age / window)
                    love.graphics.rectangle("fill", sx, sy, size, size)
                end
                if seed == 0 and camera.scale >= 3 then
                    local ox = (tile % 3) - 1
                    local oy = (math.floor(tile / 3) % 3) - 1
                    love.graphics.setColor(1, 1, 0.8, 0.8 * (1 - age / window))
                    love.graphics.rectangle("fill", sx + ox * size, sy + oy * size, size, size)
                end
            end
        end
    end
end

local function spawnSoldier(game, attack, soldier)
    local recent = attack.recent
    local front = recent[love.math.random(#recent)]
    local fx, fy = game.map:coords(front)
    local cx, cy = attack.attacker:center()
    local dx, dy = fx - cx, fy - cy
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then dx, dy, length = 1, 0, 1 end
    dx, dy = dx / length, dy / length
    local distance = love.math.random(4, 11)
    local side = love.math.random(-2, 2)
    soldier.sx = fx - dx * distance - dy * side
    soldier.sy = fy - dy * distance + dx * side
    soldier.ex = fx - dy * side * 0.5
    soldier.ey = fy + dx * side * 0.5
    soldier.dx, soldier.dy = dx, dy
    soldier.t = 0
    soldier.duration = 0.7 + love.math.random() * 0.9
    return soldier
end

function Overlay.drawTroops(game, camera, W, H)
    local alpha = math.max(0, math.min(1, (camera.scale - 1.8) / 1.5))
    local dt = game.paused and 0 or love.timer.getDelta() * game:speed()
    local size = camera.scale
    for _, attack in ipairs(game.attacks) do
        if not attack.done and attack.recent and #attack.recent > 0 then
            local wanted = math.max(4, math.min(30, math.floor(math.sqrt(attack.troops) / 6)))
            local soldiers = attack.soldiers
            if not soldiers then
                soldiers = {}
                attack.soldiers = soldiers
            end
            while #soldiers < wanted do
                local soldier = spawnSoldier(game, attack, {})
                soldier.t = love.math.random() * soldier.duration
                soldiers[#soldiers + 1] = soldier
            end
            while #soldiers > wanted do
                soldiers[#soldiers] = nil
            end
            local c = attack.attacker.color
            for _, soldier in ipairs(soldiers) do
                soldier.t = soldier.t + dt
                if soldier.t >= soldier.duration then
                    spawnSoldier(game, attack, soldier)
                end
                if alpha > 0 then
                    local p = soldier.t / soldier.duration
                    local x = soldier.sx + (soldier.ex - soldier.sx) * p
                    local y = soldier.sy + (soldier.ey - soldier.sy) * p
                    local sx, sy = camera:toScreen(math.floor(x), math.floor(y))
                    if sx > -size and sy > -size and sx < W and sy < H then
                        local fade = alpha * math.min(1, (1 - p) * 4)
                        local bx, by = camera:toScreen(math.floor(x - soldier.dx), math.floor(y - soldier.dy))
                        love.graphics.setColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, fade)
                        love.graphics.rectangle("fill", bx, by, size, size)
                        love.graphics.setColor(math.min(1, c[1] * 1.3 + 0.2), math.min(1, c[2] * 1.3 + 0.2), math.min(1, c[3] * 1.3 + 0.2), fade)
                        love.graphics.rectangle("fill", sx, sy, size, size)
                    end
                end
            end
        end
    end
end

function Overlay.drawDiplomacyLegend()
    local entries = {}
    for _, category in ipairs(Diplomap.categories) do
        entries[#entries + 1] = { label = category.label, color = category.color }
    end
    Overlay.drawLegend("DIPLOMACY", entries)
end

function Overlay.draw(game, camera)
    love.graphics.push("all")
    local W, H = love.graphics.getDimensions()
    local layers = game.renderer.layers
    if layers.diplomacy then
        Diplomap.refresh(game)
    end
    if layers.supply and game.phase == "playing" then
        Overlay.drawSupply(game, camera)
    end
    Overlay.drawCombat(game, camera, W, H)
    if layers.units then
        Overlay.drawTroops(game, camera, W, H)
    end
    if layers.units then
        Overlay.drawRails(game, camera)
        Overlay.drawRadarSweeps(game, camera)
        Overlay.drawUnits(game, camera, W, H)
        Overlay.drawEchoes(game, camera)
        Overlay.drawNukeAlerts(game, camera)
        Overlay.drawHoveredStructure(game, camera)
    end
    Overlay.drawExplosions(game, camera)
    if layers.threat then
        Overlay.drawThreats(game, camera, W, H)
    end
    if layers.names and layers.political then
        for _, player in ipairs(game.players) do
            if player.alive and player.tiles > 0 then
                Overlay.drawLabel(game, camera, player, W, H)
            end
        end
    end
    if layers.threat then
        Overlay.drawThreatLegend(game)
    elseif layers.diplomacy and layers.political then
        Overlay.drawDiplomacyLegend()
    end
    love.graphics.pop()
end

return Overlay
