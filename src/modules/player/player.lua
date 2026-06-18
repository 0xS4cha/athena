local Class = require("src.core.class")

--- @class Player
--- @field name string
--- @field country table?
Player = Class()

--- @param player_data table
function Player:init(player_data)
    self.name = player_data.name or ""
    self.country = player_data.country or nil
end