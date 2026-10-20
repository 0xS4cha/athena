local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")

local Strategist = {}

local MIN_TICK = 3000

local function enemyHasSilo(game, player)
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and not player:isAlliedWith(other) and other:unitCount("silo") > 0 then
            return true
        end
    end
    return false
end

local function chooseVictim(game, player, ctx)
    local land = game.map.landCount
    local best, bestScore
    for _, other in ipairs(game.players) do
        if other ~= player and other.alive and other.tiles > 0 and not player:isAlliedWith(other) and not other:isBot() then
            local score = -player:relation(other) + other.tiles / land * 300
            if not bestScore or score > bestScore then
                best, bestScore = other, score
            end
        end
    end
    if best and bestScore > 60 then return best end
    return nil
end

local function targetTile(game, victim)
    local cities = Units.list(game, victim, "city")
    if #cities > 0 then
        return cities[game.rng:random(#cities)].tile
    end
    local x, y = victim:center()
    return game.map:findNear(x, y, 30, function(i) return game.map.owner[i] == victim.id end)
end

function Strategist.behavior(game, player, ctx)
    if game.tick < MIN_TICK or game.options.difficulty == "easy" then return false end
    local rng = game.rng
    if rng:random() > 0.3 then return false end

    if player:unitCount("silo") == 0 then
        if player.gold > Units.cost(game, player, "silo") * 1.5 and rng:random() < 0.5 then
            local tile = player.spawnTile and game.map.owner[player.spawnTile] == player.id and player.spawnTile
            if not tile then
                local x, y = player:center()
                tile = game.map:findNear(x, y, 20, function(i) return game.map.owner[i] == player.id and Units.isSpaced(game, i) end)
            end
            if tile and Units.check(game, player, "silo", tile) then
                game:pushIntent({ type = "build", player = player.id, unit = "silo", tile = tile })
                return true
            end
        end
    end

    if player:unitCount("sam") < 1 + math.floor(player.tiles / 40000) and enemyHasSilo(game, player) and player.gold > Units.cost(game, player, "sam") then
        local cities = Units.list(game, player, "city")
        local anchor = cities[1] and cities[rng:random(#cities)].tile or player.spawnTile
        if anchor then
            local x, y = game.map:coords(anchor)
            local tile = game.map:findNear(x + rng:random(-8, 8), y + rng:random(-8, 8), 15, function(i)
                return game.map.owner[i] == player.id and Units.isSpaced(game, i)
            end)
            if tile and Units.check(game, player, "sam", tile) then
                game:pushIntent({ type = "build", player = player.id, unit = "sam", tile = tile })
                return true
            end
        end
    end

    local victim = chooseVictim(game, player, ctx)
    if not victim then return false end
    local tile = targetTile(game, victim)
    if not tile then return false end
    local reserve = 500000
    for _, kind in ipairs({ "mirv", "hydrogen", "atom" }) do
        local def = Config.nukes[kind]
        local allowed = kind ~= "mirv" or victim.tiles / game.map.landCount > 0.3
        if allowed and player.gold > def.cost + reserve and Nukes.check(game, player, kind, tile) then
            game:pushIntent({ type = "nuke", player = player.id, kind = kind, tile = tile })
            return true
        end
    end
    return false
end

return Strategist
