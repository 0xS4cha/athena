local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")

local Stats = {}

local floor = math.floor

function Stats.init(game)
    game.history = { ticks = {}, tiles = {}, troops = {}, gold = {} }
    game.counters = {}
end

function Stats.counters(game, player)
    local counters = game.counters[player.id]
    if not counters then
        counters = { captured = 0, attacks = 0, buildings = 0, nukes = 0, eliminations = 0, trade = 0, peakTiles = 0 }
        game.counters[player.id] = counters
    end
    return counters
end

function Stats.record(game)
    local history = game.history
    if history.ticks[#history.ticks] == game.tick then return end
    local tiles, troops, gold = {}, {}, {}
    for id, player in ipairs(game.players) do
        tiles[id] = player.tiles
        if player:isHuman() then
            troops[id] = floor(player.troops)
            gold[id] = floor(player.gold)
        else
            troops[id] = 0
            gold[id] = 0
        end
        if player.tiles > 0 then
            local counters = Stats.counters(game, player)
            if player.tiles > counters.peakTiles then counters.peakTiles = player.tiles end
        end
    end
    local n = #history.ticks + 1
    history.ticks[n] = game.tick
    history.tiles[n] = tiles
    history.troops[n] = troops
    history.gold[n] = gold
end

function Stats.started(game)
    Stats.record(game)
end

function Stats.step(game)
    if game.phase ~= "playing" or game.tick % Config.statsTicks ~= 0 then return end
    Stats.record(game)
end

function Stats.tileChanged(game, _, previous, id)
    if previous and id ~= 0 then
        local counters = game.counters[id]
        if counters then
            counters.captured = counters.captured + 1
        else
            Stats.counters(game, game.players[id]).captured = 1
        end
    end
end

function Stats.attackLaunched(game, attack)
    local counters = Stats.counters(game, attack.attacker)
    counters.attacks = counters.attacks + 1
end

function Stats.unitCompleted(game, unit)
    if not Units.isBuilding(unit.kind) then return end
    local counters = Stats.counters(game, unit.owner)
    counters.buildings = counters.buildings + 1
end

function Stats.nukeLaunched(game, _, player)
    local counters = Stats.counters(game, player)
    counters.nukes = counters.nukes + 1
end

function Stats.eliminated(game, _, by)
    if not by then return end
    local counters = Stats.counters(game, by)
    counters.eliminations = counters.eliminations + 1
end

function Stats.tradeCompleted(game, unit, _, gold)
    local counters = Stats.counters(game, unit.owner)
    counters.trade = counters.trade + floor(gold)
end

function Stats.gameEnded(game)
    Stats.record(game)
end

return Stats
