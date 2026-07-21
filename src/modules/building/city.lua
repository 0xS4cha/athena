local Class = require("src.core.class")

--- @class City
--- @field type string
local City = Class()

function City:init()
    self.type = "city"
end

return City