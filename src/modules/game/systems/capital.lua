local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")

local Capital = {}

local BAD = { 0.95, 0.35, 0.3, 1 }
local GOOD = { 0.3, 0.85, 0.45, 1 }

function Capital.found(game, player, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local spot = map:findNear(x, y, Config.capitalSearch, function(i)
        return map.owner[i] == player.id and Units.isSpaced(game, i)
    end)
    if not spot then return nil end
    local unit = Units.add(game, player, "capital", spot)
    Units.complete(game, unit)
    player.capital = unit
    return unit
end

function Capital.started(game)
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.spawnTile then
            Capital.found(game, player, player.spawnTile)
        end
    end
end

function Capital.unitRemoved(game, unit)
    if unit.kind ~= "capital" then return end
    local owner = unit.owner
    if owner.capital == unit then
        owner.capital = nil
    end
    if not owner.alive then return end
    owner.capitalLostUntil = game.tick + Config.capitalLossTicks
    owner.troops = owner.troops * (1 - Config.capitalTroopLoss)
    local by = unit.capturedBy
    game:notify(owner, (by and (by.name .. " captured") or "You lost") .. " your capital! Growth and income are halved for 60s.", { color = BAD, duration = 300 })
    if by then
        game:notify(by, "You captured the capital of " .. owner.name .. "!", { color = GOOD })
        if owner:isNation() and by ~= game.human and owner ~= game.human then
            game:addEvent(by.name .. " captured the capital of " .. owner.name .. ".", { color = { 0.95, 0.6, 0.3, 1 } })
        end
    end
end

function Capital.step(game)
    if game.phase ~= "playing" or game.tick % 10 ~= 0 then return end
    for _, player in ipairs(game.players) do
        if player.alive and player.tiles > 0 and not player.capital and (player.capitalLostUntil or 0) <= game.tick then
            local cities = Units.list(game, player, "city")
            local anchor = cities[1] and cities[1].tile
            if not anchor then
                local x, y = player:center()
                anchor = game.map:tileAt(x, y)
            end
            if anchor and Capital.found(game, player, anchor) then
                game:notify(player, "A new capital has been founded.", { color = GOOD })
            end
        end
    end
end

return Capital
