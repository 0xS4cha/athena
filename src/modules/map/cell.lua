local GM = require("src.core.index")

local Class = require("src.core.class")

--- @class Cell
--- @field x number
--- @field y number
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
    self.x = x
    self.y = y
    self.size = size
    self.data = data
    self.color = color
    self.isOutline = nil
    self.screenX = (x - 1) * size
    self.screenY = (y - 1) * size
    self.countries = {}
    self.leaders = {}
end

function Cell:addCountry(owner)
    if self.countries[owner] then return self.countries[owner] end
    self.countries[owner] = 0
    self.leaders[#self.leaders + 1] = owner
    return 0
end

function Cell:sortOwner()
    table.sort(self.leaders, function(a, b)
        return self.countries[a] > self.countries[b]
    end)
end

function Cell:getOwner()
    if not self.leaders[1] then return false end
    return self.leaders[1]
end

function Cell:draw()
    local map = GM.Game.Map
    local drawTerrain = map.layers.terrain
    local drawPolitical = map.layers.political and self:getOwner()

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
            self.isOutline = map:outlineAt(self.x, self.y)
        end

        local r = self:getOwner().color[1] / 255
        local g = self:getOwner().color[2] / 255
        local b = self:getOwner().color[3] / 255

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
