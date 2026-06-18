local Class = require("src.core.class")
--- @class Cell
--- @field gridX number
--- @field gridY number
--- @field size number
--- @field screenX number
--- @field screenY number
--- @field owner table?
--- @field troops number
local Cell = Class()

--- @param x number
--- @param y number
--- @param size number
function Cell:init(x, y, size)
    self.gridX = x
    self.gridY = y
    self.size = size
    
    self.screenX = (x - 1) * size
    self.screenY = (y - 1) * size

    self.owner = nil
    self.troops = 0
end

function Cell:draw()
    if self.owner then
        love.graphics.setColor(self.owner.color[1], self.owner.color[2], self.owner.color[3], 0.8)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end

    love.graphics.rectangle("fill", self.screenX, self.screenY, self.size - 1, self.size - 1)

    if self.owner or self.troops > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(self.troops), self.screenX + 4, self.screenY + 4)
    end
end

return Cell