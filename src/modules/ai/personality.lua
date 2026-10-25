local Hash = require("src.core.hash")

local Personality = {}

Personality.list = {
    {
        id = "warlord", tag = "Aggressive", label = "Warlord", icon = "Skull.png",
        aggression = 1.5, caution = 0.7, greed = 0.8, diplomacy = 0.6, loyalty = 0.7, nuclear = 1.6, lending = 0.5, opportunism = 1.1
    },
    {
        id = "merchant", tag = "Trader", label = "Merchant", icon = "Coin.png",
        aggression = 0.75, caution = 1.0, greed = 1.6, diplomacy = 1.3, loyalty = 1.0, nuclear = 0.6, lending = 1.8, opportunism = 0.8
    },
    {
        id = "guardian", tag = "Defensive", label = "Guardian", icon = "Locked.png",
        aggression = 0.65, caution = 1.7, greed = 1.1, diplomacy = 1.1, loyalty = 1.3, nuclear = 0.8, lending = 0.9, opportunism = 0.8
    },
    {
        id = "diplomat", tag = "Coalition builder", label = "Diplomat", icon = "Team.png",
        aggression = 0.9, caution = 1.0, greed = 1.0, diplomacy = 1.8, loyalty = 1.5, nuclear = 0.7, lending = 1.2, opportunism = 0.9
    },
    {
        id = "opportunist", tag = "Treacherous", label = "Opportunist", icon = "MagnifyingGlass.png",
        aggression = 1.2, caution = 0.9, greed = 1.1, diplomacy = 1.0, loyalty = 0.4, nuclear = 1.2, lending = 0.8, opportunism = 1.8
    }
}

Personality.balanced = {
    id = "balanced", tag = "Balanced", label = "Balanced", icon = "Sun.png",
    aggression = 1, caution = 1, greed = 1, diplomacy = 1, loyalty = 1, nuclear = 1, lending = 1, opportunism = 1
}

Personality.byId = {}
for _, personality in ipairs(Personality.list) do
    Personality.byId[personality.id] = personality
end

function Personality.pick(game, player)
    local h = Hash.combine(Hash.combine(math.floor(game.seed) % 4294967296, player.id), 0x51ed)
    return Personality.list[h % #Personality.list + 1].id
end

function Personality.of(player)
    return Personality.byId[player.personality] or Personality.balanced
end

return Personality
