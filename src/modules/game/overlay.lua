local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Icons = require("src.modules.hud.icons")

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
    local troops = Format.number(player.troops)
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

function Overlay.drawBuilding(game, camera, unit, radius)
    local sx, sy = camera:toScreen(unit.x, unit.y)
    local c = unit.owner.color
    local alpha = unit.buildLeft > 0 and 0.5 or 1
    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.circle("fill", sx + 1, sy + 1, radius + 1)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.circle("fill", sx, sy, radius)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", sx, sy, radius)
    local icon = Icons.get(Config.units[unit.kind].icon)
    if icon and radius >= 6 then
        local scale = radius * 1.3 / icon:getWidth()
        love.graphics.draw(icon, sx, sy, 0, scale, scale, icon:getWidth() / 2, icon:getHeight() / 2)
    end
    if unit.buildLeft > 0 and unit.buildTotal then
        local progress = 1 - unit.buildLeft / unit.buildTotal
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", sx, sy, radius + 3, -math.pi / 2, -math.pi / 2 + progress * math.pi * 2)
    end
end

function Overlay.drawUnits(game, camera, W, H)
    local radius = math.max(2.5, math.min(11, camera.scale * 2.5))
    for _, unit in ipairs(game.units) do
        if not unit.dead then
            local sx, sy = camera:toScreen(unit.x, unit.y)
            if sx > -20 and sy > -20 and sx < W + 20 and sy < H + 20 then
                local draw = Overlay.unitDrawers[unit.kind] or Overlay.drawBuilding
                draw(game, camera, unit, radius)
            end
        end
    end
end

function Overlay.drawShip(game, camera, unit, radius, shape)
    local sx, sy = camera:toScreen(unit.x, unit.y)
    local c = unit.owner.color
    local r = math.max(4, radius * 0.8)
    if unit.owner == game.human and unit.path then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.setLineWidth(1)
        local last = unit.path[#unit.path]
        local lx, ly = game.map:coords(last)
        local tx, ty = camera:toScreen(lx + 0.5, ly + 0.5)
        love.graphics.line(sx, sy, tx, ty)
    end
    love.graphics.setColor(0, 0, 0, 0.7)
    if shape == "triangle" then
        love.graphics.polygon("fill", sx, sy - r - 2, sx - r - 2, sy + r + 1, sx + r + 2, sy + r + 1)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.polygon("fill", sx, sy - r, sx - r, sy + r, sx + r, sy + r)
    elseif shape == "circle" then
        love.graphics.circle("fill", sx, sy, r * 0.8 + 1.5)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.circle("fill", sx, sy, r * 0.8)
    else
        love.graphics.rectangle("fill", sx - r * 1.3 - 1.5, sy - r * 0.6 - 1.5, r * 2.6 + 3, r * 1.2 + 3, 2, 2)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        love.graphics.rectangle("fill", sx - r * 1.3, sy - r * 0.6, r * 2.6, r * 1.2, 2, 2)
    end
    if unit.troops and radius >= 6 then
        local font = Style.font(10)
        love.graphics.setFont(font)
        local text = Format.number(unit.troops)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(text, sx - font:getWidth(text) / 2 + 1, sy + r + 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, sx - font:getWidth(text) / 2, sy + r + 1)
    end
end

function Overlay.drawNuke(game, camera, unit)
    local def = Config.nukes[unit.nukeKind]
    local sx, sy = camera:toScreen(unit.fromX, unit.fromY)
    local cx, cy = camera:toScreen(unit.x, unit.y)
    local tx, ty = camera:toScreen(unit.toX, unit.toY)
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
    if unit.nukeKind ~= "warhead" then
        love.graphics.setColor(1, 0.2, 0.15, 0.25 + 0.25 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", tx, ty, def.outer * camera.scale)
        love.graphics.setColor(1, 0.2, 0.15, 0.12)
        love.graphics.circle("fill", tx, ty, def.inner * camera.scale)
        love.graphics.setColor(1, 0.6, 0.3, 0.5)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(sx, sy, cx, cy)
    end
    love.graphics.setColor(1, 0.9, 0.4, 1)
    love.graphics.circle("fill", cx, cy, unit.nukeKind == "warhead" and 2 or 4)
    love.graphics.setColor(1, 0.3, 0.1, 1)
    love.graphics.circle("line", cx, cy, unit.nukeKind == "warhead" and 3 or 6)
end

function Overlay.drawExplosions(game, camera)
    for _, e in ipairs(game.explosions or {}) do
        local age = (game.tick - e.tick) / 20
        local sx, sy = camera:toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.85 - age * 0.5, 0.4 - age * 0.3, 0.7 * (1 - age))
        love.graphics.circle("fill", sx, sy, e.radius * camera.scale * (0.4 + age * 0.8))
        love.graphics.setColor(1, 1, 1, 0.8 * (1 - age))
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", sx, sy, e.radius * camera.scale * (0.5 + age))
    end
end

Overlay.unitDrawers = {
    nuke = function(game, camera, unit)
        Overlay.drawNuke(game, camera, unit)
    end,
    transport = function(game, camera, unit, radius)
        Overlay.drawShip(game, camera, unit, radius, "boat")
    end,
    trade = function(game, camera, unit, radius)
        Overlay.drawShip(game, camera, unit, radius * 0.8, "circle")
    end,
    warship = function(game, camera, unit, radius)
        Overlay.drawShip(game, camera, unit, radius, "triangle")
        if unit.health and unit.health < Config.units.warship.health and radius >= 5 then
            local sx, sy = camera:toScreen(unit.x, unit.y)
            local w = radius * 2.4
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", sx - w / 2, sy - radius - 7, w, 3)
            love.graphics.setColor(0.3, 0.9, 0.4, 1)
            love.graphics.rectangle("fill", sx - w / 2, sy - radius - 7, w * unit.health / Config.units.warship.health, 3)
        end
    end
}

function Overlay.draw(game, camera)
    love.graphics.push("all")
    local W, H = love.graphics.getDimensions()
    local layers = game.renderer.layers
    if layers.units then
        Overlay.drawUnits(game, camera, W, H)
    end
    Overlay.drawExplosions(game, camera)
    if layers.names and layers.political then
        for _, player in ipairs(game.players) do
            if player.alive and player.tiles > 0 then
                Overlay.drawLabel(game, camera, player, W, H)
            end
        end
    end
    love.graphics.pop()
end

return Overlay
