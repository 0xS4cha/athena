local Class = require("src.core.class")

Player = Class()

function Player:init(player_data)
    self.name = player_data.name or ""
    self.country = player_data.country or nil
end