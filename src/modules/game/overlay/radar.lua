local Config = require("src.config.game")
local Structures = require("src.modules.game.structures")
local Vision = require("src.modules.game.systems.vision")
local Units = require("src.modules.game.systems.units")
local Overlay = require("src.modules.game.overlay.shared")

local floor = math.floor

local RADAR_GREEN = { 0.45, 1, 0.55 }

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
                if detail < 1 and scale >= Overlay.badgeMinScale then
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

return Overlay
