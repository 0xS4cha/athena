local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Icons = require("src.modules.hud.icons")
local Rails = require("src.modules.game.systems.rails")
local Supply = require("src.modules.game.systems.supply")

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

Overlay.structureZoomStart = 1.6
Overlay.structureZoomFull = 3.5

local STRUCTURE_COLORS = {
    d = { 0.14, 0.14, 0.17 },
    l = { 0.86, 0.85, 0.8 },
    r = { 0.78, 0.22, 0.16 },
    y = { 0.95, 0.78, 0.3 },
    g = { 0.45, 0.47, 0.5 }
}

Overlay.structures = {
    capital = { "y.y.y", "yyyyy", "yrcry", "yyyyy", ".ddd." },
    city = { "rr.rr", "ll.ll", ".....", "rr.rr", "ll.ll" },
    tradePort = { "yy.yy", "yy.yy", "ggggg", "g.g.g", "g.g.g" },
    militaryPort = { "..d..", ".ddd.", "..d..", "d.d.d", ".ddd." },
    factory = { "d...d", "d...d", "ddddd", "dlcld", "ddddd" },
    defensePost = { "d.d.d", "ddddd", "dcccd", "dcccd", "ddddd" },
    silo = { ".ddd.", "dlrld", "dlrld", "dlrld", ".ddd." },
    sam = { "r...r", ".r.r.", "..d..", ".ddd.", "ddddd" }
}

local ALWAYS_VISIBLE = { nuke = true }

local function nearTerritory(game, player, x, y, range)
    local map = game.map
    local own = map.owner
    local id = player.id
    x, y = math.floor(x), math.floor(y)
    for dy = -range, range, 3 do
        local ty = y + dy
        if ty >= 0 and ty < map.height then
            for dx = -range, range, 3 do
                local tx = x + dx
                if tx >= 0 and tx < map.width and own[ty * map.width + tx] == id then
                    return true
                end
            end
        end
    end
    return false
end

local function nearWarship(game, player, unit)
    local r2 = Config.warshipVision * Config.warshipVision
    for _, ship in ipairs(game.ships or {}) do
        if ship.kind == "warship" and ship.owner == player and not ship.dead
            and (ship.x - unit.x) ^ 2 + (ship.y - unit.y) ^ 2 <= r2 then
            return true
        end
    end
    return false
end

function Overlay.isVisible(game, unit)
    local human = game.human
    if ALWAYS_VISIBLE[unit.kind] or unit.owner:isFriendly(human) or not human.alive then
        return true
    end
    if unit.visionTick and game.tick - unit.visionTick < Config.visionRefreshTicks then
        return unit.visible
    end
    unit.visionTick = game.tick
    unit.visible = nearTerritory(game, human, unit.x, unit.y, Config.visionRange) or nearWarship(game, human, unit)
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

function Overlay.drawBuilding(game, camera, unit)
    local alpha = Overlay.structureAlpha(camera)
    if alpha <= 0 then return end
    local pattern = Overlay.structures[unit.kind]
    if not pattern then return end
    if unit.buildLeft > 0 then
        alpha = alpha * 0.45
    end
    local owner = unit.owner.color
    local size = camera.scale
    local half = math.floor(#pattern / 2)
    local tx, ty = math.floor(unit.x), math.floor(unit.y)
    if unit.blockaded and math.floor(love.timer.getTime() * 3) % 2 == 0 then
        love.graphics.setColor(0.95, 0.2, 0.15, alpha)
        for k = -half - 1, half + 1 do
            for _, p in ipairs({ { k, -half - 1 }, { k, half + 1 }, { -half - 1, k }, { half + 1, k } }) do
                local sx, sy = camera:toScreen(tx + p[1], ty + p[2])
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end
    for row = 1, #pattern do
        local line = pattern[row]
        for col = 1, #line do
            local ch = line:sub(col, col)
            if ch ~= "." then
                local color = ch == "c" and owner or STRUCTURE_COLORS[ch]
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                local sx, sy = camera:toScreen(tx + col - 1 - half, ty + row - 1 - half)
                love.graphics.rectangle("fill", sx, sy, size, size)
            end
        end
    end
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

function Overlay.draw(game, camera)
    love.graphics.push("all")
    local W, H = love.graphics.getDimensions()
    local layers = game.renderer.layers
    if layers.supply and game.phase == "playing" then
        Overlay.drawSupply(game, camera)
    end
    Overlay.drawCombat(game, camera, W, H)
    if layers.units then
        Overlay.drawRails(game, camera)
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
