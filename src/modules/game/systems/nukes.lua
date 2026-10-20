local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")

local Nukes = {}

function Nukes.init(game)
    game.fallout = {}
    game.explosions = {}
end

function Nukes.readySilo(game, player, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local best, bestD
    for _, unit in ipairs(game.units) do
        if unit.kind == "silo" and unit.owner == player and unit.buildLeft == 0 and unit.cooldown == 0 and not unit.dead then
            local d = (unit.x - x) ^ 2 + (unit.y - y) ^ 2
            if not bestD or d < bestD then
                best, bestD = unit, d
            end
        end
    end
    return best
end

function Nukes.check(game, player, kind, tile)
    local def = Config.nukes[kind]
    if not def then return false, "Unknown" end
    if game.phase ~= "playing" or not player.alive then return false, "Not now" end
    if player:unitCount("silo") == 0 then return false, "Needs silo" end
    if not Nukes.readySilo(game, player, tile) then return false, "Reloading" end
    if player.gold < def.cost then return false, "No gold" end
    local target = game:playerAt(tile)
    if def.needsPlayer and (not target or target == player) then return false, "Needs enemy" end
    if target == player then return false, "Own land" end
    return true
end

function Nukes.spawn(game, player, kind, fromX, fromY, tile)
    local map = game.map
    local def = Config.nukes[kind]
    local tx, ty = map:coords(tile)
    tx, ty = tx + 0.5, ty + 0.5
    local distance = math.sqrt((tx - fromX) ^ 2 + (ty - fromY) ^ 2)
    local unit = Units.add(game, player, "nuke", tile, {
        nukeKind = kind,
        fromX = fromX,
        fromY = fromY,
        toX = tx,
        toY = ty,
        target = tile,
        elapsed = 0,
        duration = math.max(15, math.floor(distance / def.speed)),
        update = Nukes.update
    })
    unit.x, unit.y = fromX, fromY
    return unit
end

function Nukes.launch(game, player, kind, tile)
    local ok = Nukes.check(game, player, kind, tile)
    if not ok then return nil end
    local def = Config.nukes[kind]
    local silo = Nukes.readySilo(game, player, tile)
    player.gold = player.gold - def.cost
    silo.cooldown = Config.units.silo.cooldownTicks
    local unit = Nukes.spawn(game, player, kind, silo.x, silo.y, tile)
    local target = game:playerAt(tile)
    if target then
        target:changeRelation(player, -100)
        game:notify(target, string.format("%s launched a %s at you!", player.name, def.label), { color = { 1, 0.3, 0.2, 1 }, duration = 300 })
        game:emit("nukeLaunched", unit, player, target)
    end
    game:notify(player, def.label .. " launched.", { color = { 1, 0.6, 0.3, 1 } })
    return unit
end

function Nukes.interceptor(game, nuke)
    local range = Config.units.sam.range
    local r2 = range * range
    for _, unit in ipairs(game.units) do
        if unit.kind == "sam" and unit.buildLeft == 0 and unit.cooldown == 0 and not unit.dead
            and unit.owner ~= nuke.owner and not unit.owner:isAlliedWith(nuke.owner) then
            local dn = (unit.x - nuke.x) ^ 2 + (unit.y - nuke.y) ^ 2
            local dt = (unit.x - nuke.toX) ^ 2 + (unit.y - nuke.toY) ^ 2
            if dn <= r2 and dt <= r2 then
                return unit
            end
        end
    end
    return nil
end

function Nukes.update(game, nuke)
    nuke.elapsed = nuke.elapsed + 1
    local t = math.min(1, nuke.elapsed / nuke.duration)
    nuke.x = nuke.fromX + (nuke.toX - nuke.fromX) * t
    nuke.y = nuke.fromY + (nuke.toY - nuke.fromY) * t
    nuke.progress = t

    if nuke.nukeKind ~= "warhead" and t > 0.3 then
        local sam = Nukes.interceptor(game, nuke)
        if sam then
            sam.cooldown = Config.units.sam.cooldownTicks
            game:notify(nuke.owner, "Your " .. Config.nukes[nuke.nukeKind].label .. " was intercepted by a SAM.", { color = { 0.95, 0.5, 0.3, 1 } })
            game:notify(sam.owner, "Your SAM intercepted a " .. Config.nukes[nuke.nukeKind].label .. ".", { color = { 0.3, 0.85, 0.45, 1 } })
            table.insert(game.explosions, { x = nuke.x, y = nuke.y, radius = 6, tick = game.tick })
            Units.remove(game, nuke)
            return
        end
    end

    if t < 1 then return end
    if nuke.nukeKind == "mirv" then
        Nukes.split(game, nuke)
    else
        Nukes.detonate(game, nuke.owner, nuke.toX, nuke.toY, Config.nukes[nuke.nukeKind])
    end
    Units.remove(game, nuke)
end

function Nukes.split(game, nuke)
    local map = game.map
    local def = Config.nukes.mirv
    local targetId = map.owner[nuke.target]
    local rng = game.rng
    local launched = 0
    for _ = 1, def.warheads * 6 do
        if launched >= def.warheads then break end
        local x = math.floor(nuke.toX + (rng:random() * 2 - 1) * def.spread)
        local y = math.floor(nuke.toY + (rng:random() * 2 - 1) * def.spread)
        if map:isValid(x, y) then
            local i = map:index(x, y)
            if targetId ~= 0 and map.owner[i] == targetId then
                Nukes.spawn(game, nuke.owner, "warhead", nuke.toX, nuke.toY, i)
                launched = launched + 1
            end
        end
    end
end

function Nukes.detonate(game, attacker, cx, cy, def)
    local map = game.map
    local rng = game.rng
    local lost = {}
    local strength = Config.falloutStrength
    local ring = def.outer - def.inner
    map:forDisk(cx, cy, def.outer, function(i, d2)
        if not map:isLand(i) then return end
        local d = math.sqrt(d2)
        if d > def.inner and rng:random() > Config.nukeRingChance * (1 - (d - def.inner) / ring) + 0.15 then
            return
        end
        if map.fallout[i] == 0 then
            game.fallout[#game.fallout + 1] = i
        end
        map.fallout[i] = strength
        local owner = map.owner[i]
        if owner ~= 0 then
            lost[owner] = (lost[owner] or 0) + 1
            game:setOwner(i, 0)
        else
            game.renderer:paintTile(i)
        end
    end)

    for id, count in pairs(lost) do
        local player = game.players[id]
        local fraction = math.min(1, count / math.max(1, player.tiles + count) * Config.nukeTroopKill)
        player.troops = player.troops * (1 - fraction)
        player.workers = player.workers * (1 - fraction)
        if player ~= attacker then
            player:changeRelation(attacker, -50)
        end
    end

    local r2 = def.outer * def.outer
    for _, unit in ipairs(game.units) do
        if not unit.dead and unit.kind ~= "nuke" and (unit.x - cx) ^ 2 + (unit.y - cy) ^ 2 <= r2 then
            Units.remove(game, unit)
        end
    end
    table.insert(game.explosions, { x = cx, y = cy, radius = def.outer, tick = game.tick })
    game:emit("nukeDetonated", attacker, cx, cy, def, lost)
end

function Nukes.step(game)
    if game.phase ~= "playing" then return end
    for k = #game.explosions, 1, -1 do
        if game.tick - game.explosions[k].tick > 20 then
            table.remove(game.explosions, k)
        end
    end
    if game.tick % Config.falloutDecayTicks ~= 0 then return end
    local map = game.map
    local list = game.fallout
    local k = 1
    while k <= #list do
        local i = list[k]
        local value = map.fallout[i] - Config.falloutDecay
        if value <= 0 then
            map.fallout[i] = 0
            list[k] = list[#list]
            list[#list] = nil
        else
            map.fallout[i] = value
            k = k + 1
        end
        if map.owner[i] == 0 then
            game.renderer:paintTile(i)
        end
    end
end

Nukes.intents = {
    nuke = function(game, intent)
        local player = game.players[intent.player]
        if player then
            Nukes.launch(game, player, intent.kind, intent.tile)
        end
    end
}

return Nukes
