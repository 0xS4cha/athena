local Style = require("src.modules.hud.style")
local Format = require("src.core.format")

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

function Overlay.draw(game, camera)
    love.graphics.push("all")
    local W, H = love.graphics.getDimensions()
    local layers = game.renderer.layers
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
