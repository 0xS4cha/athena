local Intents = require("src.net.intents")
local Units = require("src.modules.game.systems.units")
local T = require("tests.helpers")

local function playingGame()
    local game = T.game({ bots = 10, nations = false })
    for _ = 1, 160 do game:step() end
    T.equal(game.phase, "playing", "game phase")
    return game
end

return {
    {
        name = "rejects unknown and malformed intents",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            T.equal(Intents.sanitize(game, 1, nil), nil, "nil intent")
            T.equal(Intents.sanitize(game, 1, { type = "teleport" }), nil, "unknown type")
            T.equal(Intents.sanitize(game, 1, { type = "spawn", tile = "abc" }), nil, "string tile")
        end
    },
    {
        name = "forces the player to the sender slot and strips extra fields",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            local tile = game.map:findNear(game.map.width / 2, game.map.height / 2, 300, function(i) return game.map:isLand(i) end)
            local intent = T.expect(Intents.sanitize(game, 2, { type = "spawn", tile = tile, player = 1, troops = 1e9, gold = 5 }))
            T.equal(intent.player, 2, "player slot")
            T.equal(intent.troops, nil, "troops field")
            T.equal(intent.gold, nil, "gold field")
        end
    },
    {
        name = "quantizes ratios to thousandths",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            local intent = T.expect(Intents.sanitize(game, 1, { type = "troopRatio", ratio = 0.123456 }))
            T.equal(intent.ratio, 0.123, "quantized ratio")
            T.equal(Intents.sanitize(game, 1, { type = "troopRatio", ratio = 5 }).ratio, 1, "clamped ratio")
        end
    },
    {
        name = "applies game rules on the server state",
        run = function()
            local game = playingGame()
            local human = game.players[1]
            T.expect(human.spawned, "human spawned at the end of the spawn phase")
            local _, spawnReason = Intents.sanitize(game, 1, { type = "spawn", tile = 0 })
            T.equal(spawnReason, "Spawn phase is over", "late spawn")
            game:pushIntent({ type = "attack", player = 1, target = 0, ratio = 1 })
            for _ = 1, 150 do game:step() end
            local free
            for tile in pairs(human.borders) do
                if Units.isSpaced(game, tile) and (not free or tile < free) then free = tile end
            end
            T.expect(free, "a free tile in the human territory")
            local _, buildReason = Intents.sanitize(game, 1, { type = "build", unit = "city", tile = free })
            T.equal(buildReason, "No gold", "city without gold")
            local _, nukeReason = Intents.sanitize(game, 1, { type = "nuke", kind = "atom", tile = 0 })
            T.equal(nukeReason, "Needs silo", "nuke without silo")
            T.expect(Intents.sanitize(game, 1, { type = "attack", target = 0, ratio = 0.5 }), "attack on the bordering wilderness")
        end
    },
    {
        name = "refuses attacks on players without a shared border",
        run = function()
            local game = playingGame()
            local far
            for _, player in ipairs(game.players) do
                if player.id ~= 1 and player.alive and player.spawned and not require("src.modules.game.systems.attack").sharesBorder(game, game.players[1], player.id) then
                    far = player
                    break
                end
            end
            T.expect(far, "a player without a shared border")
            local _, reason = Intents.sanitize(game, 1, { type = "attack", target = far.id, ratio = 0.5 })
            T.equal(reason, "No shared border", "attack reason")
        end
    }
}
