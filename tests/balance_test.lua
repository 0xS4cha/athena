local Config = require("src.config.game")
local Economy = require("src.modules.game.systems.economy")
local Rails = require("src.modules.game.systems.rails")
local Units = require("src.modules.game.systems.units")
local T = require("tests.helpers")

local function expandedGame()
    local game = T.game({ bots = 0, nations = false })
    for _ = 1, 160 do game:step() end
    T.equal(game.phase, "playing", "game phase")
    game:pushIntent({ type = "attack", player = 1, target = 0, ratio = 1 })
    for _ = 1, 400 do game:step() end
    return game, game.players[1]
end

local function spacedTiles(game, player, count)
    local map = game.map
    local tiles = {}
    for i = 0, map.size - 1 do
        if map.owner[i] == player.id and not player.borders[i] and Units.isSpaced(game, i) then
            tiles[#tiles + 1] = i
            game.buildingAt[i] = true
            if #tiles == count then break end
        end
    end
    for _, tile in ipairs(tiles) do game.buildingAt[tile] = nil end
    return tiles
end

return {
    {
        name = "cities have diminishing returns and stop at the housing capacity",
        run = function()
            local game, human = expandedGame()
            human.cities = 0
            local base = Economy.maxPopulation(game, human)
            human.cities = 2
            local two = Economy.maxPopulation(game, human)
            T.expect(two - base < 2 * Config.cityPopulation, "second city has diminishing returns")
            T.expect(not human.crowded, "two cities fit in the housing capacity")
            human.cities = 80
            local many = Economy.maxPopulation(game, human)
            T.expect(human.crowded, "eighty cities overflow the housing capacity")
            T.expect(many - base <= Economy.housingCapacity(human) + 1, "population capped by housing")
        end
    },
    {
        name = "a factory only links to its nearest stations",
        run = function()
            local game, human = expandedGame()
            local tiles = spacedTiles(game, human, 8)
            T.expect(#tiles == 8, "eight free tiles in the territory")
            for k = 1, 6 do
                Units.complete(game, Units.add(game, human, "city", tiles[k]))
            end
            local factory = Units.add(game, human, "factory", tiles[7])
            Units.complete(game, factory)
            T.expect(Rails.links(game, factory) > 0, "the factory is linked")
            T.expect(Rails.links(game, factory) <= Config.railLinks, "links capped")
            Units.complete(game, Units.add(game, human, "tradePort", tiles[8]))
            T.expect(Rails.links(game, factory) <= Config.railLinks, "a new station does not exceed the cap")
        end
    },
    {
        name = "train income has diminishing returns with the network size",
        run = function()
            local rail = { tiles = {} }
            for k = 1, 60 do rail.tiles[k] = k end
            local single = Rails.trainGold(rail, 1)
            T.equal(single, Config.trainGold + 60 * Config.trainGoldPerTile, "one rail pays in full")
            local total = Rails.trainGold(rail, 40) * 40
            T.expect(total < single * 40 * 0.3, "forty rails pay much less than forty times one")
            T.expect(total > single, "a bigger network still pays more")
        end
    },
    {
        name = "territory far from cities and the capital earns less gold",
        run = function()
            local points = { 0, 0 }
            T.equal(Economy.efficiencyAt(points, Config.adminRange - 1, 0), 1, "close territory is fully administered")
            local half = Economy.efficiencyAt(points, Config.adminRange + Config.adminFalloff / 2, 0)
            T.expect(math.abs(half - 0.5) < 1e-9, "efficiency falls with the distance")
            T.equal(Economy.efficiencyAt(points, 5000, 0), Config.adminFloor, "efficiency has a floor")
            T.equal(Economy.efficiencyAt({}, 0, 0), nil, "no administrative center")

            local game, human = expandedGame()
            Economy.refreshAdministration(game)
            T.expect(human.adminPoints and #human.adminPoints >= 2, "the capital administers the land")
            T.expect(human.administration > Config.adminFloor and human.administration <= 1, "administration in range")
            human.administration = 1
            local full = Economy.goldRate(game, human)
            human.administration = 0.5
            T.expect(math.abs(Economy.goldRate(game, human) - full * 0.5) < 1e-9, "gold scales with the administration")
        end
    }
}
