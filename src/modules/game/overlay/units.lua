local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Rails = require("src.modules.game.systems.rails")
local Overlay = require("src.modules.game.overlay.shared")

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
    warship = { "...g...", "..ggg..", "cccccgd", ".ddddd." },
    submarine = { "...g....", "..cc....", "ccccccgd", ".dddddd." }
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

function Overlay.drawShip(game, camera, unit, _, alpha)
    alpha = alpha or 1
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
                love.graphics.setColor(0.9, 0.95, 1, 0.5 * (1 - k / 6) * alpha)
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
                love.graphics.setColor(color[1], color[2], color[3], alpha)
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

Overlay.unitDrawers = {
    nuke = function(game, camera, unit)
        Overlay.drawNuke(game, camera, unit)
    end,
    transport = Overlay.drawShip,
    trade = Overlay.drawShip,
    warship = function(game, camera, unit)
        Overlay.drawShip(game, camera, unit)
        Overlay.drawHealth(camera, unit)
    end,
    submarine = function(game, camera, unit)
        local surfaced = (unit.revealedUntil or 0) > game.tick
        Overlay.drawShip(game, camera, unit, nil, surfaced and 1 or 0.55)
        Overlay.drawHealth(camera, unit)
    end
}

function Overlay.drawHealth(camera, unit)
    local max = unit.maxHealth or Config.units[unit.kind].health
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

return Overlay
