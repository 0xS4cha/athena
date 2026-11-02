local BuildBar = require("src.modules.hud.components.buildbar")
local Keybinds = require("src.modules.input.keybinds")
local Units = require("src.modules.game.systems.units")
local T = require("tests.helpers")

local function find(list, kind)
    for _, entry in ipairs(list) do
        if entry.kind == kind then return entry end
    end
end

return {
    {
        name = "the build bar lists the bound buildings and what can be paid",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            local human = game.players[1]
            game.human = human
            local city = "build:city"
            local list = BuildBar.entries(game)
            T.equal(find(list, "atom"), nil, "nukes are not buildings")
            T.equal(find(list, "city").key, Keybinds.label(Keybinds.get(city)), "shows the bound key")

            human.gold = Units.cost(game, human, "city") - 1
            T.expect(not find(BuildBar.entries(game), "city").affordable, "too expensive")
            human.gold = Units.cost(game, human, "city")
            T.expect(find(BuildBar.entries(game), "city").affordable, "affordable")

            T.expect(not find(BuildBar.entries(game), "city").active, "not armed")
            game.buildAim = { kind = "city" }
            T.expect(find(BuildBar.entries(game), "city").active, "armed")
            T.expect(not find(BuildBar.entries(game), "farm").active, "another building is not armed")
        end
    }
}
