local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")
local T = require("tests.helpers")

local function expandedGame()
    local game = T.game({ bots = 0, nations = false, seed = 77 })
    for _ = 1, 160 do game:step() end
    game:pushIntent({ type = "attack", player = 1, target = 0, ratio = 1 })
    for _ = 1, 400 do game:step() end
    return game, game.players[1]
end

local function interiorTile(game, player)
    local map = game.map
    local cx, cy = player:center()
    return map:findNear(cx, cy, 40, function(i)
        return map.owner[i] == player.id and not player.borders[i] and Units.isSpaced(game, i)
    end)
end

local function blast(withBunker, offset)
    local game, human = expandedGame()
    local tile = T.expect(interiorTile(game, human), "interior tile")
    local bunker
    if withBunker then
        bunker = Units.add(game, human, "bunker", tile)
        Units.complete(game, bunker)
    end
    for _, unit in ipairs(Units.list(game, human, "capital")) do
        Units.remove(game, unit)
    end
    local x, y = game.map:coords(tile)
    human.troops = 1000000
    Nukes.detonate(game, game.players[2], x + 0.5 + offset, y + 0.5, Config.nukes.atom)
    return human, bunker
end

return {
    {
        name = "a bunker shelters the population and survives nearby blasts",
        run = function()
            local open = blast(false, 12)
            local sheltered, bunker = blast(true, 12)
            T.expect(open.troops < 1000000, "the blast kills troops")
            T.expect(sheltered.troops > open.troops, "the bunker saves troops")
            local lostOpen, lostSheltered = 1000000 - open.troops, 1000000 - sheltered.troops
            T.expect(lostSheltered < lostOpen * (1 - Config.units.bunker.shelter) * 1.2, "casualties reduced by the shelter ratio")
            T.expect(not bunker.dead, "the bunker survives a blast 12 tiles away")
            local _, hit = blast(true, 0)
            T.expect(hit.dead, "a direct hit destroys the bunker")
        end
    }
}
