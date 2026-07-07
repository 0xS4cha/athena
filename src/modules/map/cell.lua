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
function Cell:init(x, y, size, data, color)
    self.gridX = x
    self.gridY = y
    self.size = size
    self.data = data
    self.color = color

    self.screenX = (x - 1) * size
    self.screenY = (y - 1) * size

    self.owner = nil
    self.troops = 0
end

function Cell:draw()
    if self.owner then
        love.graphics.setColor(self.owner.color[1], self.owner.color[2], self.owner.color[3], 0.8)
    else
        love.graphics.setColor(self.color[1] / 255, self.color[2] / 255, self.color[3] / 255, 1)
    end
    love.graphics.rectangle("fill", self.screenX, self.screenY, self.size, self.size)
end

return Cell