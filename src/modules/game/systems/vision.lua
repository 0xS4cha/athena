local Config = require("src.config.game")
local Format = require("src.core.format")
local Attack = require("src.modules.game.systems.attack")

local Vision = {}

local TAU = math.pi * 2

Vision.hidden = { silo = true, sam = true }

function Vision.init(game)
    game.echoes = {}
    game.radarCache = {}
end

function Vision.radarRange(game, unit)
    if not unit.range then
        local bonus = game.map:terrainType(unit.tile) == "mountain" and Config.radarMountainBonus or 1
        unit.range = Config.units.radar.range * bonus
    end
    return unit.range
end

function Vision.online(unit)
    return unit.kind == "radar" and unit.buildLeft == 0 and not unit.dead and unit.owner.upkeepPaid ~= false
end

function Vision.radars(game, player)
    local cache = game.radarCache
    if cache.tick ~= game.tick then
        cache = { tick = game.tick }
        game.radarCache = cache
    end
    local list = cache[player.id]
    if not list then
        list = {}
        for _, unit in ipairs(game.units) do
            if Vision.online(unit) and unit.owner:isFriendly(player) then
                list[#list + 1] = unit
            end
        end
        cache[player.id] = list
    end
    return list
end

function Vision.inRadar(game, player, x, y, factor)
    for _, radar in ipairs(Vision.radars(game, player)) do
        local range = Vision.radarRange(game, radar) * (factor or 1)
        if (radar.x - x) ^ 2 + (radar.y - y) ^ 2 <= range * range then
            return true
        end
    end
    return false
end

function Vision.nearTerritory(game, player, x, y, range)
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

function Vision.nearWarship(game, player, x, y)
    local r2 = Config.warshipVision * Config.warshipVision
    for _, ship in ipairs(game.ships or {}) do
        if ship.kind == "warship" and ship.owner == player and not ship.dead
            and (ship.x - x) ^ 2 + (ship.y - y) ^ 2 <= r2 then
            return true
        end
    end
    return false
end

local function observers(game, player)
    local list = { player }
    for id in pairs(player.allies) do
        local ally = game.players[id]
        if ally and ally.alive then
            list[#list + 1] = ally
        end
    end
    return list
end

function Vision.passive(game, player, x, y)
    for _, observer in ipairs(observers(game, player)) do
        if Vision.nearTerritory(game, observer, x, y, Config.visionRange) or Vision.nearWarship(game, observer, x, y) then
            return true
        end
    end
    return false
end

function Vision.live(game, player, unit)
    if unit.owner:isFriendly(player) then
        return true
    end
    if Vision.hidden[unit.kind] then
        return false
    end
    return Vision.passive(game, player, unit.x, unit.y)
end

function Vision.knows(game, player, x, y, kind)
    if Vision.inRadar(game, player, x, y) then
        return true
    end
    return not Vision.hidden[kind] and Vision.passive(game, player, x, y)
end

local function computeObserved(game, viewer)
    local set = {}
    for _, observer in ipairs(observers(game, viewer)) do
        set[observer.id] = true
        for _, neighbor in ipairs(Attack.neighbors(game, observer)) do
            set[neighbor.id] = true
        end
    end
    for _, player in ipairs(game.players) do
        if not set[player.id] and player.alive and player.tiles > 0 then
            local x, y = player:center()
            local capital = player.capital
            if Vision.inRadar(game, viewer, x, y) or (capital and not capital.dead and Vision.inRadar(game, viewer, capital.x, capital.y)) then
                set[player.id] = true
            end
        end
    end
    return set
end

function Vision.observes(game, viewer, player)
    if not viewer.alive or game.options.spectator then return true end
    local cache = game.observedCache
    local bucket = math.floor(game.tick / Config.visionRefreshTicks)
    if not cache or cache.bucket ~= bucket then
        cache = { bucket = bucket }
        game.observedCache = cache
    end
    local set = cache[viewer.id]
    if not set then
        set = computeObserved(game, viewer)
        cache[viewer.id] = set
    end
    return set[player.id] == true
end

function Vision.estimate(game, player)
    local bucket = math.floor(game.tick / Config.estimateTicks)
    local noise = ((player.id * 92821 + bucket * 68917) % 1000) / 500 - 1
    local value = player.troops * (1 + Config.estimateError * noise)
    if value <= 0 then return 0 end
    local magnitude = 10 ^ math.max(0, math.floor(math.log10(value)) - 1)
    return math.floor(value / magnitude + 0.5) * magnitude
end

function Vision.troopsText(game, viewer, player)
    if Vision.observes(game, viewer, player) then
        return Format.number(player.troops)
    end
    return "~" .. Format.number(Vision.estimate(game, player))
end

function Vision.beam(radar, tick)
    return ((tick + radar.id * 7) % Config.radarSweepTicks) / Config.radarSweepTicks * TAU
end

local function sweep(game, player)
    local radars = Vision.radars(game, player)
    if #radars == 0 then return end
    local step = TAU / Config.radarSweepTicks
    local echoes = game.echoes
    for _, radar in ipairs(radars) do
        local range = Vision.radarRange(game, radar)
        local beam = Vision.beam(radar, game.tick)
        local previous = beam - step
        for _, unit in ipairs(game.units) do
            if not unit.dead and not unit.owner:isFriendly(player) then
                local reach = unit.kind == "radar" and range * Config.radarDetectFactor or range
                local dx, dy = unit.x - radar.x, unit.y - radar.y
                if dx * dx + dy * dy <= reach * reach then
                    local angle = math.atan2(dy, dx) % TAU
                    if (angle - previous) % TAU <= step then
                        local echo = echoes[unit]
                        if not echo then
                            echo = {}
                            echoes[unit] = echo
                        end
                        echo.x, echo.y, echo.tick = unit.x, unit.y, game.tick
                    end
                end
            end
        end
    end
end

function Vision.step(game)
    if game.phase ~= "playing" then return end
    local human = game.human
    if not human.alive then return end
    sweep(game, human)
    for unit, echo in pairs(game.echoes) do
        if game.tick - echo.tick > Config.radarGhostTicks then
            game.echoes[unit] = nil
        end
    end
end

return Vision
