local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Structures = require("src.modules.game.structures")
local Pixel = require("src.modules.hud.pixel")
local Vision = require("src.modules.game.systems.vision")
local Units = require("src.modules.game.systems.units")
local Yields = require("src.modules.game.yields")
local Overlay = require("src.modules.game.overlay.shared")

Overlay.structureZoomStart = 1.6
Overlay.structureZoomFull = 3.5

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
Overlay.badgeMinScale = 0.7
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

local YIELD_MIN_SCALE = 2.5
local YIELD_FADE = 1
local YIELD_ICON = 10
local YIELD_FONT = 10
local YIELD_INK = { 0.04, 0.04, 0.07 }

local function drawYield(game, camera, unit, ox, oy, footprint)
    if unit.owner ~= game.human or game.options.spectator then return end
    local alpha = math.min(1, (camera.scale - YIELD_MIN_SCALE) / YIELD_FADE)
    if alpha <= 0 then return end
    local value = Yields.of(game, unit.owner, unit)
    if not value then return end
    local amount = value.population or value.gold
    local text = (amount < 0 and "-" or "+") .. Format.number(math.abs(amount)) .. (value.gold and "/s" or "")
    local icon = value.gold and "Coin.png" or "Team.png"
    local color = amount < 0 and Style.colors.bad or value.gold and Style.colors.gold or Style.colors.troops
    local font = Style.font(YIELD_FONT)
    local w = YIELD_ICON + 6 + font:getWidth(text)
    local h = math.max(YIELD_ICON, font:getHeight()) + 2
    local x, y = floor(ox + footprint / 2 - w / 2), floor(oy - h - 1)
    love.graphics.setColor(YIELD_INK[1], YIELD_INK[2], YIELD_INK[3], alpha * 0.78)
    love.graphics.rectangle("fill", x + 1, y, w - 2, h)
    love.graphics.rectangle("fill", x, y + 1, w, h - 2)
    Pixel.icon(icon, x + 2, y + floor((h - YIELD_ICON) / 2), YIELD_ICON, alpha)
    Pixel.text(text, x + YIELD_ICON + 4, y + floor((h - font:getHeight()) / 2), YIELD_FONT, color, alpha)
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
    if detail < 1 and camera.scale >= Overlay.badgeMinScale and unit.kind ~= "capital" then
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
    drawYield(game, camera, unit, ox, oy, footprint)
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

return Overlay
