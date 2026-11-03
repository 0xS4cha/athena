local Config = require("src.config.game")
local Supply = require("src.modules.game.systems.supply")
local Overlay = require("src.modules.game.overlay.shared")

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

return Overlay
