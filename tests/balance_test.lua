local Config = require("src.config.game")
local Economy = require("src.modules.game.systems.economy")
local Rails = require("src.modules.game.systems.rails")
local Units = require("src.modules.game.systems.units")
local Yields = require("src.modules.game.yields")
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
    },
    {
        name = "farms have diminishing returns and need plains",
        run = function()
            local game, human = expandedGame()
            local plains = Config.biomes.plains.id
            human.cities = 0
            human.biomeTiles[plains] = Config.farmTiles * 100
            game.buildingCounts = { [human.id] = {} }
            local base = Economy.maxPopulation(game, human)
            game.buildingCounts[human.id].farm = 1
            T.expect(math.abs(Economy.maxPopulation(game, human) - base - Config.farmPopulation) < 1e-6, "the first farm pays in full")
            game.buildingCounts[human.id].farm = 4
            local four = Economy.maxPopulation(game, human) - base
            T.expect(four < 4 * Config.farmPopulation, "extra farms have diminishing returns")
            T.expect(four > Config.farmPopulation, "extra farms still help")

            human.biomeTiles[plains] = Config.farmTiles * 2
            T.equal(Economy.activeFarms(game, human), 2, "plains limit the working farms")
            human.biomeTiles[plains] = 1
            T.equal(Economy.activeFarms(game, human), 1, "the first farm always works")
            T.expect(Economy.maxPopulation(game, human) - base - Config.farmPopulation < 1e-6, "idle farms bring no population")
        end
    },
    {
        name = "mines have diminishing returns and need rich land",
        run = function()
            local game, human = expandedGame()
            local mountain, desert = Config.biomes.mountain.id, Config.biomes.desert.id
            local gold = Config.units.mine.gold
            human.biomeTiles[mountain], human.biomeTiles[desert] = Config.mineTiles * 50, Config.mineTiles * 50
            game.buildingCounts = { [human.id] = {} }
            T.equal(Economy.mineIncome(game, human), 0, "no mine, no income")
            game.buildingCounts[human.id] = { mine = 1, mineGold = gold * 1.5 }
            T.equal(Economy.mineIncome(game, human), gold * 1.5, "the first mine pays in full with its richness")
            game.buildingCounts[human.id] = { mine = 20, mineGold = gold * 20 }
            local twenty = Economy.mineIncome(game, human)
            T.expect(twenty < gold * 20 * 0.4, "twenty mines pay much less than twenty times one")
            T.expect(twenty > gold, "more mines still pay more")

            human.biomeTiles[mountain], human.biomeTiles[desert] = 0, Config.mineTiles * 2
            game.buildingCounts[human.id] = { mine = 2, mineGold = gold * 2 }
            local two = Economy.mineIncome(game, human)
            game.buildingCounts[human.id] = { mine = 20, mineGold = gold * 20 }
            T.expect(math.abs(Economy.mineIncome(game, human) - two) < 1e-9, "rich land limits the working mines")
            T.expect(Economy.saturated(human, "city") == false, "other buildings are never saturated")
            human.unitCounts.mine = 2
            T.expect(Economy.saturated(human, "mine"), "a mine beyond the limit is flagged")
            human.unitCounts.mine = 1
            T.expect(not Economy.saturated(human, "mine"), "a mine within the limit is not flagged")
        end
    },
    {
        name = "structure indicators add up to what the empire really earns",
        run = function()
            local game, human = expandedGame()
            local tiles = spacedTiles(game, human, 8)
            T.expect(#tiles == 8, "eight free tiles in the territory")
            local function build(kind, tile)
                local unit = Units.add(game, human, kind, tile)
                Units.complete(game, unit)
                return unit
            end
            local cities = { build("city", tiles[1]), build("city", tiles[2]) }
            local farm = build("farm", tiles[3])
            local mountainMine, desertMine = build("mine", tiles[4]), build("mine", tiles[5])
            mountainMine.richness, desertMine.richness = 1.5, 1
            local port, barracks = build("tradePort", tiles[6]), build("barracks", tiles[7])
            local factory = build("factory", tiles[8])
            human.biomeTiles[Config.biomes.plains.id] = Config.farmTiles * 10
            human.biomeTiles[Config.biomes.mountain.id] = Config.mineTiles * 10
            human.upkeepPaid = true
            Economy.countBuildings(game)

            local list = Yields.compute(game, human)
            local cityHousing, farmHousing = Economy.housing(game, human)
            local population = list[cities[1]].population + list[cities[2]].population + list[farm].population
            T.expect(math.abs(population - math.min(cityHousing + farmHousing, Economy.housingCapacity(human))) < 1e-6, "population adds up to the housing")
            T.equal(list[human.capital].population, Config.capitalPopulation, "capital population")

            T.expect(math.abs(list[mountainMine].gold + list[desertMine].gold - Economy.mineIncome(game, human) * Config.tickRate) < 1e-6, "mines add up to the mine income")
            T.expect(math.abs(list[mountainMine].gold / list[desertMine].gold - 1.5) < 1e-9, "a richer mine shows more gold")
            T.equal(list[barracks].gold, -Config.barracksUpkeep * Config.tickRate, "barracks show their upkeep")
            human.upkeepPaid = false
            T.equal(Yields.compute(game, human)[barracks], nil, "unpaid upkeep shows nothing")
            human.upkeepPaid = true

            T.equal(list[port], nil, "no estimate before the first delivery")
            port.tradeRoute = 120
            T.expect(Yields.compute(game, human)[port].gold > 0, "a port with a route shows an estimate")
            port.blockaded = true
            T.equal(Yields.compute(game, human)[port], nil, "a blockaded port earns nothing")

            T.expect(Rails.links(game, factory) > 0, "the factory is linked")
            T.equal(list[factory], nil, "unfinished rails earn nothing")
            for _, rail in ipairs(game.rails) do rail.built = #rail.tiles end
            T.expect(Yields.compute(game, human)[factory].gold > 0, "finished rails earn gold")
        end
    }
}
