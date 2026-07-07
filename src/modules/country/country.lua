local GM = require("src.core.index")
local uuid = require("src.core.uuid")
local Class = require("src.core.class")

local Country = Class()



function Country:init(player)
    self.player = player
    self.color = {math.random(0, 255), math.random(0, 255), math.random(0, 255)}
    self.id = uuid.getUUID()
end

function Country:claimCell(x, y)
    GM.Game.Map:setOwner(self, x, y)
end


return Country