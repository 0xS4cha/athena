local Personality = require("src.modules.ai.personality")
local T = require("tests.helpers")

return {
    {
        name = "nations get the same personality on every machine",
        run = function()
            local a = T.game({ bots = 0, seed = 1234 })
            local b = T.game({ bots = 0, seed = 1234, authority = false })
            local seen = {}
            for id, player in ipairs(a.players) do
                if player:isNation() then
                    T.expect(Personality.byId[player.personality], "nation without personality")
                    T.equal(b.players[id].personality, player.personality, "personality of " .. player.name)
                    seen[player.personality] = true
                end
            end
            local kinds = 0
            for _ in pairs(seen) do kinds = kinds + 1 end
            T.expect(kinds >= 3, "several personalities on one map")
            T.equal(Personality.of(a.players[1]).id, "balanced", "humans play balanced when the AI takes over")
        end
    }
}
