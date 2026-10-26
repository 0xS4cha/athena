local Config = require("src.config.game")
local Units = require("src.modules.game.systems.units")
local Nukes = require("src.modules.game.systems.nukes")
local Ships = require("src.modules.game.systems.ships")
local Vision = require("src.modules.game.systems.vision")
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
    },
    {
        name = "submarines stay hidden until detected and hunt trade ships",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            for _ = 1, 160 do game:step() end
            local a, b = game.players[1], game.players[2]
            local map = game.map
            local function water(x, y)
                return T.expect(map:findNear(x, y, 400, function(i) return map:isWater(i) and game.pathfinder.component[i] end), "water tile")
            end
            local function ship(owner, kind, tile)
                local unit = Units.add(game, owner, kind, tile, { path = { tile }, progress = 1 })
                Units.complete(game, unit)
                return unit
            end
            local seaTile = water(map.width / 2, map.height / 2)
            local sx, sy = map:coords(seaTile)
            local sub = ship(b, "submarine", seaTile)
            game:step()
            T.equal(sub.health, Config.units.submarine.health, "submarine health")
            T.expect(not Vision.live(game, a, sub), "submarine hidden from enemies")
            T.expect(Vision.live(game, b, sub), "submarine visible to its owner")

            local farTile = map:findNear(sx + 30, sy, 10, function(i) return map:isWater(i) end) or seaTile
            local hunter = ship(a, "warship", farTile)
            game:step()
            local far = math.sqrt((hunter.x - sub.x) ^ 2 + (hunter.y - sub.y) ^ 2) > Config.sonarRange
            if far then
                T.equal(Ships.nearestShip(game, hunter, 400), nil, "warship ignores an undetected submarine")
            end
            local closeTile = map:findNear(sx + 3, sy, 4, function(i) return map:isWater(i) end) or seaTile
            hunter.tile, hunter.x, hunter.y = closeTile, sub.x + 3, sub.y
            T.expect(Vision.live(game, a, sub), "sonar reveals a nearby submarine")
            T.equal(Ships.nearestShip(game, hunter, 400), sub, "warship hunts a detected submarine")
            Ships.strike(game, hunter, sub)
            T.equal(sub.health, Config.units.submarine.health - Config.units.warship.damage * Config.units.warship.antiSubmarine, "depth charges")

            local trade = ship(a, "trade", seaTile)
            game:step()
            T.equal(Ships.nearestShip(game, sub, 400), trade, "submarine targets trade ships first")
            Ships.strike(game, sub, trade)
            T.expect(trade.dead, "trade ship sunk instead of captured")
            T.expect(sub.revealedUntil > game.tick, "firing reveals the submarine")
        end
    }
}
