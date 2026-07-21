local GM = require("src.core.index")

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
    self.isOutline = nil
    self.screenX = (x - 1) * size
    self.screenY = (y - 1) * size

    self.owner = nil
end

function Cell:getOwner()
    if not self.owner then return false end
    return self.owner
end

function Cell:draw()
    local map = GM.Game.Map
    local drawTerrain = map.layers.terrain
    local drawPolitical = map.layers.political and self.owner

    if drawTerrain then
        love.graphics.setColor(self.color[1] / 255, self.color[2] / 255, self.color[3] / 255, 1)
    else
        if self.data.isImpassable then
            love.graphics.setColor(0, 0, 0, 0)
        elseif self.data.isLand then
            love.graphics.setColor(0.15, 0.15, 0.17, 1)
        else
            love.graphics.setColor(0.06, 0.08, 0.12, 1)
        end
    end
    love.graphics.rectangle("fill", self.screenX, self.screenY, self.size, self.size)

    if drawPolitical then
        if self.isOutline == nil then
            self.isOutline = map:outlineAt(self.gridX, self.gridY)
        end

        local r = self.owner.color[1] / 255
        local g = self.owner.color[2] / 255
        local b = self.owner.color[3] / 255

        if self.isOutline then
            love.graphics.setColor(r, g, b, 1.0)
            love.graphics.rectangle("fill", self.screenX, self.screenY, self.size, self.size)
        else
            love.graphics.setColor(r, g, b, 0.35)
            love.graphics.rectangle("fill", self.screenX, self.screenY, self.size, self.size)
        end
    end
end

return Cell
