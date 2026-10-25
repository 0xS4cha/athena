local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")
local Vision = require("src.modules.game.systems.vision")

local function sq(v) return v * v end

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
            local d = sq(unit.x - x) + sq(unit.y - y)
            if not bestD or d < bestD then
                best, bestD = unit, d
            end
        end
    end
    return best
end

function Nukes.shelter(game, player, x, y)
    local def = Config.units.bunker
    local r2 = def.radius * def.radius
    for _, unit in ipairs(game.units) do
        if unit.kind == "bunker" and unit.owner == player and unit.buildLeft == 0 and not unit.dead
            and sq(unit.x - x) + sq(unit.y - y) <= r2 then
            return unit
        end
    end
    return nil
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

local FRIENDLY_TILES = 3000

function Nukes.hitChance(def, d)
    if d <= def.inner then return 1 end
    local ring = def.outer - def.inner
    return math.min(1, Config.nukeRingChance * (1 - (d - def.inner) / ring) + 0.15)
end

local warheadTotal

local function warheadYield()
    if warheadTotal then return warheadTotal end
    local def = Config.nukes.warhead
    local total = 0
    for dy = -def.outer, def.outer do
        for dx = -def.outer, def.outer do
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= def.outer then
                total = total + Nukes.hitChance(def, d)
            end
        end
    end
    warheadTotal = total
    return total
end

local function knownTo(game, player, unit)
    if unit.owner:isFriendly(player) then return true end
    if game.echoes and game.echoes[unit] then return true end
    return Vision.live(game, player, unit)
end

function Nukes.preview(game, player, kind, tile)
    local cache = game.nukePreview
    local bucket = math.floor(game.tick / 5)
    if cache and cache.kind == kind and cache.tile == tile and cache.bucket == bucket then
        return cache
    end
    local map = game.map
    local def = Config.nukes[kind]
    local x, y = map:coords(tile)
    local cx, cy = x + 0.5, y + 0.5
    local ok, reason = Nukes.check(game, player, kind, tile)
    local result = {
        kind = kind, tile = tile, bucket = bucket, def = def, ok = ok, reason = reason,
        x = cx, y = cy, target = game:playerAt(tile),
        total = 0, enemy = 0, friendly = 0, friendlyTiles = {},
        enemyBuildings = 0, friendlyBuildings = 0, sams = {}, sheltered = false
    }
    local silo = Nukes.readySilo(game, player, tile)
    if not silo then
        for _, unit in ipairs(game.units) do
            if unit.kind == "silo" and unit.owner == player and unit.buildLeft == 0 and not unit.dead then
                silo = unit
                break
            end
        end
    end
    result.silo = silo
    if silo then
        local distance = math.sqrt(sq(cx - silo.x) + sq(cy - silo.y))
        result.flight = math.max(15, math.floor(distance / def.speed)) / Config.tickRate
    end
    local function tally(i, chance)
        local owner = map.owner[i]
        result.total = result.total + chance
        if owner == 0 then return end
        local other = game.players[owner]
        if other:isFriendly(player) then
            result.friendly = result.friendly + chance
            if #result.friendlyTiles < FRIENDLY_TILES then
                result.friendlyTiles[#result.friendlyTiles + 1] = i
            end
        else
            result.enemy = result.enemy + chance
        end
    end
    local radius
    if kind == "mirv" then
        result.warheads = def.warheads
        radius = def.spread
        local targetId = result.target and result.target.id or 0
        local inside = 0
        for ty = math.max(0, y - def.spread), math.min(map.height - 1, y + def.spread), 2 do
            for tx = math.max(0, x - def.spread), math.min(map.width - 1, x + def.spread), 2 do
                if map.owner[map:index(tx, ty)] == targetId and targetId ~= 0 then
                    inside = inside + 4
                end
            end
        end
        result.enemy = math.min(inside, def.warheads * warheadYield())
        result.total = result.enemy
        for _, unit in ipairs(game.units) do
            if not unit.dead and unit.kind ~= "nuke" and unit.owner.id == targetId and Units.isBuilding(unit.kind)
                and math.abs(unit.x - cx) <= def.spread and math.abs(unit.y - cy) <= def.spread and knownTo(game, player, unit) then
                result.enemyBuildings = result.enemyBuildings + 1
            end
        end
    else
        radius = def.outer
        map:forDisk(cx, cy, def.outer, function(i, d2)
            if map:isLand(i) then
                tally(i, Nukes.hitChance(def, math.sqrt(d2)))
            end
        end)
        local r2 = def.outer * def.outer
        for _, unit in ipairs(game.units) do
            if not unit.dead and unit.kind ~= "nuke" and Units.isBuilding(unit.kind) and sq(unit.x - cx) + sq(unit.y - cy) <= r2 and knownTo(game, player, unit) then
                if unit.owner:isFriendly(player) then
                    result.friendlyBuildings = result.friendlyBuildings + 1
                else
                    result.enemyBuildings = result.enemyBuildings + 1
                end
            end
        end
    end
    result.radius = radius
    local range = Config.units.sam.range
    for _, unit in ipairs(game.units) do
        if unit.kind == "sam" and not unit.dead and unit.buildLeft == 0 and not unit.owner:isFriendly(player)
            and sq(unit.x - cx) + sq(unit.y - cy) <= range * range and knownTo(game, player, unit) then
            result.sams[#result.sams + 1] = unit
        end
    end
    local victim = result.target
    local shelter = victim and victim ~= player and Nukes.shelter(game, victim, cx, cy)
    result.sheltered = shelter and knownTo(game, player, shelter) or false
    result.blind = not Vision.inRadar(game, player, cx, cy)
    game.nukePreview = result
    return result
end

function Nukes.spawn(game, player, kind, fromX, fromY, tile)
    local map = game.map
    local def = Config.nukes[kind]
    local tx, ty = map:coords(tile)
    tx, ty = tx + 0.5, ty + 0.5
    local distance = math.sqrt(sq(tx - fromX) + sq(ty - fromY))
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
        game:emit("nukeLaunched", unit, player, target)
    end
    game:notify(player, def.label .. " launched.", { color = { 1, 0.6, 0.3, 1 }, minor = true })
    return unit
end

function Nukes.interceptor(game, nuke)
    local range = Config.units.sam.range
    local r2 = range * range
    for _, unit in ipairs(game.units) do
        if unit.kind == "sam" and unit.buildLeft == 0 and unit.cooldown == 0 and not unit.dead
            and unit.owner ~= nuke.owner and not unit.owner:isAlliedWith(nuke.owner) then
            local dn = sq(unit.x - nuke.x) + sq(unit.y - nuke.y)
            local dt = sq(unit.x - nuke.toX) + sq(unit.y - nuke.toY)
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
            game:notify(sam.owner, "Your SAM intercepted a " .. Config.nukes[nuke.nukeKind].label .. ".", { color = { 0.3, 0.85, 0.45, 1 }, minor = true })
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
    local r2 = def.outer * def.outer
    local bunker = Config.units.bunker
    local protected = {}
    for _, unit in ipairs(game.units) do
        local d2 = sq(unit.x - cx) + sq(unit.y - cy)
        if not unit.dead and unit.buildLeft == 0 and d2 <= r2 then
            if unit.kind == "bunker" then
                protected[unit] = d2 > bunker.hitRadius * bunker.hitRadius
            elseif Units.isBuilding(unit.kind) and Nukes.shelter(game, unit.owner, unit.x, unit.y) then
                protected[unit] = rng:random() < bunker.shelterBuildings
            end
        end
    end
    local function shielded(i)
        local unit = game.buildingAt[i]
        return unit and protected[unit] == true
    end
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
        if owner ~= 0 and not shielded(i) then
            lost[owner] = (lost[owner] or 0) + 1
            game:setOwner(i, 0)
        else
            game.renderer:paintTile(i)
        end
    end)

    for id, count in pairs(lost) do
        local player = game.players[id]
        local fraction = math.min(1, count / math.max(1, player.tiles + count) * Config.nukeTroopKill)
        if Nukes.shelter(game, player, cx, cy) then
            fraction = fraction * (1 - Config.units.bunker.shelter)
        end
        player.troops = player.troops * (1 - fraction)
        player.workers = player.workers * (1 - fraction)
        if player ~= attacker then
            player:changeRelation(attacker, -50)
        end
    end

    for _, unit in ipairs(game.units) do
        if not unit.dead and unit.kind ~= "nuke" and not protected[unit] and sq(unit.x - cx) + sq(unit.y - cy) <= r2 then
            Units.remove(game, unit)
        end
    end
    table.insert(game.explosions, { x = cx, y = cy, radius = def.outer, tick = game.tick })
    game:emit("nukeDetonated", attacker, cx, cy, def, lost)
end

function Nukes.step(game)
    if game.phase ~= "playing" then return end
    for k = #game.explosions, 1, -1 do
        if game.tick - game.explosions[k].tick > Config.explosionTicks then
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
