local Style = require("src.modules.hud.style")
local Config = require("src.config.game")
local Structures = require("src.modules.game.structures")
local Pixel = require("src.modules.hud.pixel")
local Units = require("src.modules.game.systems.units")
local Interaction = require("src.modules.game.interaction")
local Nukes = require("src.modules.game.systems.nukes")
local Overlay = require("src.modules.game.overlay.shared")

local floor = math.floor

function Overlay.drawBuildPreview(game, camera)
    local mx, my = love.mouse.getPosition()
    local preview = Interaction.buildPreview(game, game.map:tileAt(camera:toWorld(mx, my)))
    if not preview then return end
    local map = game.map
    local scale = camera.scale
    local time = love.timer.getTime()
    local color = preview.ok and Style.colors.good or Style.colors.bad
    local x, y = map:coords(preview.tile)
    local r = Config.buildingSpacing
    local zx, zy = camera:toScreen(x - r, y - r)
    local zone = (r * 2 + 1) * scale
    love.graphics.setColor(color[1], color[2], color[3], 0.12)
    love.graphics.rectangle("fill", zx, zy, zone, zone)
    Pixel.corners(zx, zy, zone, zone, color, 0.6 + 0.4 * math.sin(time * 6))
    if preview.tile ~= preview.mouse then
        local fx, fy = map:coords(preview.mouse)
        Overlay.dashedLine(camera, fx + 0.5, fy + 0.5, x + 0.5, y + 0.5, color, 0.7, 2)
    end
    local half = floor(Structures.SIZE / 2)
    local ox, oy = camera:toScreen(x - half, y - half)
    if Structures.has(preview.kind) then
        Structures.draw(preview.kind, ox, oy, scale, game.human.color, 0.45 + 0.2 * math.sin(time * 4))
    else
        Pixel.icon(preview.def.icon, ox, oy, Structures.SIZE * scale, 0.7)
    end
end

local function pendingOrigin(game, entry)
    local preview = entry.preview
    if preview.origin ~= nil then return preview.origin or nil end
    local human = game.human
    local intent = entry.intent
    local origin
    if intent.type == "boat" then
        local port = Units.nearestPort(game, human, preview.tile, "militaryPort")
        origin = port and port.tile
    elseif intent.type == "nuke" then
        local silo = Nukes.readySilo(game, human, preview.tile)
        origin = silo and silo.tile
    elseif intent.type == "build" then
        local ok, _, target = Units.check(game, human, intent.unit, preview.tile)
        preview.target = ok and target or preview.tile
    end
    preview.origin = origin or false
    return origin
end

function Overlay.drawPending(game, camera)
    local lockstep = game.lockstep
    if not lockstep or not game.human then return end
    local map = game.map
    local time = love.timer.getTime()
    local pulse = 0.55 + 0.45 * math.sin(time * 10)
    local scale = camera.scale
    for _, entry in ipairs(lockstep:pendingList()) do
        local intent = entry.intent
        local preview = entry.preview
        if preview and preview.tile then
            local origin = pendingOrigin(game, entry)
            local tx, ty = map:coords(preview.tile)
            tx, ty = tx + 0.5, ty + 0.5
            if intent.type == "boat" or intent.type == "nuke" then
                local color = intent.type == "boat" and Style.colors.troops or { 1, 0.35, 0.2 }
                if origin then
                    local ox, oy = map:coords(origin)
                    Overlay.dashedLine(camera, ox + 0.5, oy + 0.5, tx, ty, color, 0.85 * pulse, intent.type == "nuke" and 3 or 2)
                end
                Overlay.pixelCircle(camera, tx, ty, intent.type == "nuke" and 5 or 3, color, pulse, time * 2, true)
            elseif intent.type == "build" then
                local x, y = map:coords(preview.target or preview.tile)
                local half = floor(Structures.SIZE / 2)
                local ox, oy = camera:toScreen(x - half, y - half)
                if Structures.has(intent.unit) then
                    Structures.draw(intent.unit, ox, oy, scale, game.human.color, 0.3 + 0.2 * pulse)
                else
                    Pixel.icon(Config.units[intent.unit].icon, ox, oy, Structures.SIZE * scale, 0.5 * pulse)
                end
                Pixel.corners(ox, oy, Structures.SIZE * scale, Structures.SIZE * scale, Style.colors.gold, pulse)
            elseif intent.type == "spawn" then
                Overlay.pixelCircle(camera, tx, ty, Config.spawnRadius, Style.colors.gold, pulse, time, true)
            end
        end
    end
end

return Overlay
