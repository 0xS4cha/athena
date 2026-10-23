local Config = require("src.config.game")
local Format = require("src.core.format")
local Units = require("src.modules.game.systems.units")
local Attack = require("src.modules.game.systems.attack")
local Pathfinding = require("src.modules.map.pathfinding")

local function sq(v) return v * v end

local Ships = {}

function Ships.init(game)
    game.pathfinder = Pathfinding.new(game.map)
    game.tradeRoutes = {}
end

function Ships.isHostile(a, b)
    return a:canAttack(b)
end

function Ships.waterNear(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    return map:findNear(x, y, 4, function(i) return map:isWater(i) end)
end

function Ships.findPath(game, from, to)
    return game.pathfinder:water(from, to, Config.pathMaxNodes)
end

function Ships.place(game, unit)
    local path = unit.path
    local index = math.min(#path, math.max(1, math.floor(unit.progress)))
    local x, y = game.map:coords(path[index])
    unit.x = x + 0.5
    unit.y = y + 0.5
    unit.tile = path[index]
end

function Ships.advance(game, unit, speed)
    unit.progress = unit.progress + speed
    Ships.place(game, unit)
    return unit.progress >= #unit.path
end

function Ships.landingTile(game, player, tile)
    local map = game.map
    if map:isWater(tile) then return nil end
    local ownerId = map.owner[tile]
    if ownerId == player.id then return nil end
    if map:isCoast(tile) then return tile end
    local x, y = map:coords(tile)
    local near = map:findNear(x, y, Config.boatLandingSearch, function(i)
        return map.owner[i] == ownerId and map:isCoast(i)
    end)
    if near or ownerId == 0 then return near end
    local best, bestD
    for b in pairs(game.players[ownerId].borders) do
        if map:isCoast(b) then
            local bx, by = map:coords(b)
            local d = sq(bx - x) + sq(by - y)
            if not bestD or d < bestD or (d == bestD and b < best) then
                best, bestD = b, d
            end
        end
    end
    return best
end

function Ships.militaryPorts(game, player)
    local list = {}
    for _, unit in ipairs(game.units) do
        if unit.kind == "militaryPort" and unit.owner == player and unit.buildLeft == 0 and not unit.dead then
            list[#list + 1] = unit
        end
    end
    return list
end

function Ships.boatLimit(game, player)
    return math.min(Config.maxBoats, #Ships.militaryPorts(game, player) * Config.boatsPerMilitaryPort)
end

function Ships.launchTile(game, player, destination)
    local map = game.map
    local dx, dy = map:coords(destination)
    local candidates = {}
    for _, port in ipairs(Ships.militaryPorts(game, player)) do
        if not port.blockaded then
            candidates[#candidates + 1] = { tile = port.tile, d = sq(port.x - dx) + sq(port.y - dy) }
        end
    end
    table.sort(candidates, function(a, b) return a.d < b.d or (a.d == b.d and a.tile < b.tile) end)
    for _, candidate in ipairs(candidates) do
        if game.pathfinder:connected(candidate.tile, destination) then
            return candidate.tile
        end
    end
    return nil
end

function Ships.canSendBoat(game, player, tile)
    local limit = Ships.boatLimit(game, player)
    if limit == 0 then
        return false, "Needs military port"
    end
    if player:unitCount("transport") >= limit then
        return false, "Max boats"
    end
    local destination = Ships.landingTile(game, player, tile)
    if not destination then return false, "No landing" end
    local target = game:playerAt(destination)
    if target and not player:canAttack(target) then return false, player:hasPact(target) and "Pact" or "Allied" end
    local source = Ships.launchTile(game, player, destination)
    if not source then return false, "No sea route" end
    return true, nil, source, destination
end

function Ships.updateTransport(game, unit)
    if not Ships.advance(game, unit, Config.boatSpeed) then return end
    local player = unit.owner
    local map = game.map
    local tile = unit.path[#unit.path]
    local ownerId = map.owner[tile]
    local target = ownerId ~= 0 and game.players[ownerId] or nil
    player.troops = player.troops + unit.troops
    if ownerId ~= player.id and player.alive and player:canAttack(target) then
        game:setOwner(tile, player.id)
        Attack.launch(game, player, ownerId, unit.troops)
    end
    Units.remove(game, unit)
end

function Ships.sendBoat(game, player, tile, troops)
    local ok, reason, source, destination = Ships.canSendBoat(game, player, tile)
    if not ok then
        game:notify(player, "Cannot send boat: " .. reason .. ".")
        return nil
    end
    troops = math.floor(math.min(troops, player.troops))
    if troops < 1 then return nil end
    local path = Ships.findPath(game, source, destination)
    if not path then
        game:notify(player, "No sea route to that coast.")
        return nil
    end
    player.troops = player.troops - troops
    local unit = Units.add(game, player, "transport", source, {
        path = path,
        progress = 1,
        troops = troops,
        destination = destination,
        update = Ships.updateTransport
    })
    local target = game:playerAt(destination)
    if target then
        game:notify(target, string.format("%s is sending a boat with %s troops!", player.name, Format.number(troops)), { color = { 0.95, 0.35, 0.3, 1 } })
    end
    return unit
end

function Ships.canTrade(a, b)
    return a ~= b and not a.embargo[b.id] and not b.embargo[a.id]
end

function Ships.route(game, from, to)
    local key = from.tile .. ":" .. to.tile
    local cached = game.tradeRoutes[key]
    if cached == nil then
        cached = Ships.findPath(game, from.tile, to.tile) or false
        game.tradeRoutes[key] = cached
    end
    return cached or nil
end

function Ships.updateTrade(game, unit)
    if not Ships.advance(game, unit, Config.tradeSpeed) then return end
    local port = unit.toPort
    if port and not port.dead and not port.blockaded and Ships.canTrade(unit.owner, port.owner) then
        local gold = Config.tradeBaseGold + #unit.path * Config.tradeGoldPerTile
        unit.owner.gold = unit.owner.gold + gold
        if port.owner ~= unit.owner then
            port.owner.gold = port.owner.gold + gold
        end
        game:emit("tradeCompleted", unit, port, gold)
    end
    if unit.fromPort then
        unit.fromPort.activeTrade = nil
    end
    Units.remove(game, unit)
end

local PORTS = { tradePort = true, militaryPort = true }

function Ships.blockader(game, port)
    local r2 = Config.blockadeRange * Config.blockadeRange
    for _, ship in ipairs(game.ships or {}) do
        if ship.kind == "warship" and not ship.dead and Ships.isHostile(ship.owner, port.owner)
            and sq(ship.x - port.x) + sq(ship.y - port.y) <= r2 then
            return ship
        end
    end
    return nil
end

function Ships.updateBlockades(game)
    for _, unit in ipairs(game.units) do
        if PORTS[unit.kind] and not unit.dead and unit.buildLeft == 0 then
            local ship = Ships.blockader(game, unit)
            local was = unit.blockaded
            unit.blockaded = ship ~= nil
            if unit.blockaded and not was then
                local label = Config.units[unit.kind].label
                game:notify(unit.owner, string.format("%s is blockading your %s!", ship.owner.name, label), { color = { 0.95, 0.35, 0.3, 1 } })
                game:notify(ship.owner, string.format("Your warship is blockading a %s of %s.", label, unit.owner.name), { color = { 0.3, 0.85, 0.45, 1 }, minor = true })
                game:emit("blockadeStarted", unit, ship)
            elseif was and not unit.blockaded then
                game:notify(unit.owner, "The blockade of your " .. Config.units[unit.kind].label .. " has been lifted.", { color = { 0.55, 0.75, 1, 1 }, minor = true })
            end
        end
    end
end

function Ships.updatePort(game, port)
    if port.buildLeft > 0 or port.activeTrade or port.blockaded then return end
    port.tradeTimer = (port.tradeTimer or game.rng:random(1, Config.tradeInterval)) - 1
    if port.tradeTimer > 0 then return end
    port.tradeTimer = Config.tradeInterval + game.rng:random(0, Config.tradeInterval)
    if game.rng:random() > Config.tradeChance then return end
    local candidates = {}
    local component = game.pathfinder:waterComponents(port.tile)
    for _, unit in ipairs(game.units) do
        if unit.kind == "tradePort" and unit ~= port and not unit.dead and unit.buildLeft == 0 and Ships.canTrade(port.owner, unit.owner) then
            local shared = false
            for c in pairs(game.pathfinder:waterComponents(unit.tile)) do
                if component[c] then shared = true end
            end
            if shared then
                candidates[#candidates + 1] = { port = unit, d = sq(unit.x - port.x) + sq(unit.y - port.y) }
            end
        end
    end
    table.sort(candidates, function(a, b) return a.d < b.d or (a.d == b.d and a.port.id < b.port.id) end)
    if #candidates > 0 then
        local target = candidates[game.rng:random(math.min(Config.tradePartners, #candidates))].port
        do
            local path = Ships.route(game, port, target)
            if path then
                port.activeTrade = Units.add(game, port.owner, "trade", port.tile, {
                    path = path,
                    progress = 1,
                    fromPort = port,
                    toPort = target,
                    update = Ships.updateTrade
                })
                return
            end
        end
    end
end

local PRIORITY = { warship = 3, transport = 2, trade = 1 }

function Ships.step(game)
    local ships = {}
    for _, unit in ipairs(game.units) do
        if PRIORITY[unit.kind] and not unit.dead then
            ships[#ships + 1] = unit
        end
    end
    game.ships = ships
    if game.phase == "playing" and game.tick % Config.blockadeCheckTicks == 0 then
        Ships.updateBlockades(game)
    end
end

function Ships.nearestShip(game, warship, range)
    local best, bestD, bestPriority
    local priority = PRIORITY
    for _, unit in ipairs(game.ships or {}) do
        local p = priority[unit.kind]
        if p and unit ~= warship and not unit.dead and Ships.isHostile(warship.owner, unit.owner) then
            local d = math.sqrt(sq(unit.x - warship.x) + sq(unit.y - warship.y))
            if d <= range and (not bestPriority or p > bestPriority or (p == bestPriority and d < bestD)) then
                best, bestD, bestPriority = unit, d, p
            end
        end
    end
    return best, bestD
end

function Ships.capture(game, ship, player)
    local previous = ship.owner
    previous.unitCounts.trade = math.max(0, previous:unitCount("trade") - 1)
    player.unitCounts.trade = player:unitCount("trade") + 1
    ship.owner = player
    if ship.fromPort then
        ship.fromPort.activeTrade = nil
        ship.fromPort = nil
    end
    local port = Units.nearestPort(game, player, ship.tile, "tradePort")
    local path = port and game.pathfinder:connected(ship.tile, port.tile) and Ships.findPath(game, ship.tile, port.tile)
    if not path then
        Units.remove(game, ship)
        return
    end
    ship.path = path
    ship.progress = 1
    ship.toPort = port
    game:notify(previous, "A trade ship was captured by " .. player.name .. ".", { color = { 0.95, 0.5, 0.3, 1 }, minor = true })
    game:notify(player, "Your warship captured a trade ship from " .. previous.name .. ".", { color = { 0.3, 0.85, 0.45, 1 }, minor = true })
end

function Ships.strike(game, warship, target)
    local def = Config.units.warship
    warship.cooldown = def.reloadTicks
    if target.kind == "trade" then
        Ships.capture(game, target, warship.owner)
    elseif target.kind == "transport" then
        game:notify(target.owner, "Your transport ship was sunk by " .. warship.owner.name .. ".", { color = { 0.95, 0.35, 0.3, 1 } })
        game:notify(warship.owner, "Your warship sank a transport from " .. target.owner.name .. ".", { color = { 0.3, 0.85, 0.45, 1 }, minor = true })
        Units.remove(game, target)
    else
        target.health = target.health - def.damage
        if target.health <= 0 then
            game:notify(target.owner, "Your warship was destroyed by " .. warship.owner.name .. ".", { color = { 0.95, 0.35, 0.3, 1 } })
            Units.remove(game, target)
        end
    end
end

function Ships.station(game, warship, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local component = game.pathfinder.component[warship.tile]
    local water = map:findNear(x, y, Config.blockadeRange, function(i)
        return map:isWater(i) and game.pathfinder.component[i] == component
    end)
    if not water then return nil end
    warship.home = water
    warship.stationed = true
    warship.retry = nil
    return water
end

function Ships.blockadeTarget(game, warship)
    local best, bestD
    local r2 = Config.aiBlockadeSearch * Config.aiBlockadeSearch
    local component = game.pathfinder.component[warship.tile]
    for _, unit in ipairs(game.units) do
        if PORTS[unit.kind] and not unit.dead and Ships.isHostile(warship.owner, unit.owner) and not unit.owner:isBot() then
            local d = sq(unit.x - warship.x) + sq(unit.y - warship.y)
            if d <= r2 and (not bestD or d < bestD) and game.pathfinder:waterComponents(unit.tile)[component] then
                best, bestD = unit, d
            end
        end
    end
    return best
end

function Ships.patrolTarget(game, warship)
    local map = game.map
    local def = Config.units.warship
    if not warship.stationed and not warship.owner:isHuman() and game.rng:random() < Config.aiBlockadeChance then
        local port = Ships.blockadeTarget(game, warship)
        local water = port and Ships.station(game, warship, port.tile)
        if water then
            return water
        end
    end
    local radius = warship.stationed and Config.stationRadius or def.patrolRadius
    local hx, hy = map:coords(warship.home)
    for _ = 1, 10 do
        local x = hx + game.rng:random(-radius, radius)
        local y = hy + game.rng:random(-radius, radius)
        if map:isValid(x, y) then
            local i = map:index(x, y)
            if map:isWater(i) and game.pathfinder.component[i] == game.pathfinder.component[warship.home] then
                return i
            end
        end
    end
    return nil
end

function Ships.updateWarship(game, warship)
    local def = Config.units.warship
    local target, distance
    if game.tick >= (warship.scan or 0) or (warship.target and warship.target.dead) then
        warship.target = Ships.nearestShip(game, warship, def.range)
        warship.scan = game.tick + 5
    end
    target = warship.target
    if target then
        distance = math.sqrt(sq(target.x - warship.x) + sq(target.y - warship.y))
        if distance > def.range * 1.5 or not Ships.isHostile(warship.owner, target.owner) then
            target = nil
            warship.target = nil
        end
    end
    if target then
        if distance <= def.attackRange then
            if warship.cooldown == 0 then
                Ships.strike(game, warship, target)
            end
            return
        end
        if (warship.chasing ~= target or game.tick >= (warship.repath or 0)) and game.tick >= (warship.retry or 0) then
            local path = Ships.findPath(game, warship.tile, target.tile)
            warship.chasing = target
            warship.repath = game.tick + 10
            if path then
                warship.path = path
                warship.progress = 1
            else
                warship.retry = game.tick + 30
            end
        end
    elseif (not warship.path or warship.progress >= #warship.path) and game.tick >= (warship.retry or 0) then
        warship.chasing = nil
        local destination = Ships.patrolTarget(game, warship)
        warship.path = destination and Ships.findPath(game, warship.tile, destination) or nil
        warship.progress = 1
        if not warship.path then
            warship.retry = game.tick + 30
        end
    end
    if warship.path and warship.progress < #warship.path then
        Ships.advance(game, warship, target and def.speed or def.speed * 0.6)
    end
end

function Ships.unitCompleted(game, unit)
    if unit.kind == "tradePort" then
        unit.update = Ships.updatePort
    elseif unit.kind == "warship" then
        local water = Ships.waterNear(game, unit.tile)
        if not water then
            Units.remove(game, unit)
            return
        end
        local x, y = game.map:coords(water)
        unit.tile = water
        unit.home = water
        unit.x, unit.y = x + 0.5, y + 0.5
        unit.health = Config.units.warship.health
        unit.update = Ships.updateWarship
    end
end

function Ships.unitRemoved(game, unit)
    if unit.kind == "trade" and unit.fromPort then
        unit.fromPort.activeTrade = nil
    end
end

function Ships.eliminated(game, player)
    for _, unit in ipairs(game.units) do
        if unit.owner == player and not Units.isBuilding(unit.kind) then
            Units.remove(game, unit)
        end
    end
end

Ships.intents = {
    warship = function(game, intent)
        local player = game.players[intent.player]
        if not player or not player.alive then return end
        local map = game.map
        local tx, ty = map:coords(intent.tile)
        local best, bestD
        for _, ship in ipairs(game.ships or {}) do
            if ship.kind == "warship" and ship.owner == player and not ship.dead
                and game.pathfinder:connected(ship.tile, intent.tile) then
                local d = sq(ship.x - tx) + sq(ship.y - ty)
                if not bestD or d < bestD then best, bestD = ship, d end
            end
        end
        local water = best and Ships.station(game, best, intent.tile)
        local path = water and Ships.findPath(game, best.tile, water)
        if not path then
            game:notify(player, "No warship can reach that place.")
            return
        end
        best.path = path
        best.progress = 1
        best.target = nil
        best.chasing = nil
        game:notify(player, "Warship dispatched.", { color = { 0.55, 0.75, 1, 1 }, minor = true })
    end,
    boat = function(game, intent)
        if game.phase ~= "playing" then return end
        local player = game.players[intent.player]
        if not player or not player.alive then return end
        Ships.sendBoat(game, player, intent.tile, player.troops * (intent.ratio or player.attackRatio))
    end
}

return Ships
