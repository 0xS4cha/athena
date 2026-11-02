local Synth = require("src.modules.audio.synth")
local Sounds = require("src.modules.audio.sounds")
local Cues = require("src.modules.audio.cues")
local Diplomacy = require("src.modules.game.systems.diplomacy")
local T = require("tests.helpers")

return {
    {
        name = "notes follow equal temperament",
        run = function()
            T.equal(math.floor(Synth.note("a4") + 0.5), 440, "a4")
            T.equal(math.floor(Synth.note("a5") + 0.5), 880, "a5")
            T.equal(math.floor(Synth.note("c4") + 0.5), 262, "c4")
            T.equal(math.floor(Synth.note("c#4") + 0.5), 277, "c#4")
        end
    },
    {
        name = "every sound renders audible, bounded and identical each time",
        run = function()
            for name, recipe in pairs(Sounds) do
                local samples, count = Synth.render(recipe)
                local again = Synth.render(recipe)
                T.equal(count, math.ceil(Synth.duration(recipe) * Synth.rate), name .. " length")
                local peak = 0
                for k = 0, count - 1 do
                    peak = math.max(peak, math.abs(samples[k]))
                    T.equal(samples[k], again[k], name .. " is deterministic")
                end
                T.expect(peak > 0.05, name .. " is silent")
                T.expect(peak <= 0.951, name .. " clips")
            end
        end
    },
    {
        name = "game events map to the sounds of the local player only",
        run = function()
            local game = T.game({ bots = 0, nations = false, humans = { { name = "A" }, { name = "B" }, { name = "C" } }, localSlot = 1 })
            local a, b, c = game.players[1], game.players[2], game.players[3]
            T.equal(Cues.resolve(game, "attackLaunched", { attacker = a, target = b }), "attack", "own attack")
            T.equal(Cues.resolve(game, "attackLaunched", { attacker = b, target = a }), "underAttack", "attacked")
            T.equal(Cues.resolve(game, "attackLaunched", { attacker = b, target = c }), nil, "foreign attack")
            T.equal(Cues.resolve(game, "unitCompleted", { owner = a, kind = "city" }), "build", "own building")
            T.equal(Cues.resolve(game, "unitCompleted", { owner = b, kind = "city" }), nil, "foreign building")
            game.winner = a
            T.equal(Cues.resolve(game, "gameEnded", a), "victory", "own win")
            game.winner = b
            T.equal(Cues.resolve(game, "gameEnded", b), "defeat", "foreign win")
            T.equal(Cues.resolve(game, "unknownEvent"), nil, "unknown event")
            game.human = nil
            T.equal(Cues.resolve(game, "gameEnded", a), nil, "no sound without a local player")
        end
    },
    {
        name = "the simulation reports events to its observer without changing the state",
        run = function()
            local function play(observe)
                local game = T.game({ bots = 0, nations = false, localSlot = 1 })
                local heard = {}
                if observe then
                    game.observer = function(name) heard[name] = true end
                end
                for _ = 1, 160 do game:step() end
                Diplomacy.form(game, game.players[1], game.players[2])
                Diplomacy.betray(game, game.players[2], game.players[1])
                for _ = 1, 20 do game:step() end
                return game:checksum(), heard
            end
            local plain = play(false)
            local observed, heard = play(true)
            T.equal(observed, plain, "state with and without an observer")
            T.expect(heard.started, "started")
            T.expect(heard.allianceFormed, "alliance formed")
            T.expect(heard.allianceBroken, "alliance broken")
        end
    }
}
