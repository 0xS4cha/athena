---@diagnostic disable: undefined-global
local Class = require("src.core.class")

--- @class Building
--- @field gridX number
--- @field gridY number
--- @field type string
--- @field name string
--- @field owner table
--- @field hoverProgress number
--- @field definition table
--- @field state table
local Building = Class()

function Building:init(gridX, gridY, type, name, cell, definition)
    self.gridX = gridX
    self.gridY = gridY
    self.type = type or "capital"
    self.name = name or "Unnamed Building"
    self.cell = cell
    self.hoverProgress = 0
    self.definition = definition or {}
    self.state = {}
end

function Building:getOwnerColor()
    if self.cell and self.cell:getOwner() then
        local owner = self.cell:getOwner()
        return owner.color[1] / 255, owner.color[2] / 255, owner.color[3] / 255
    end

    local definitionColor = self.definition.color or { 0.8, 0.8, 0.8 }
    return definitionColor[1], definitionColor[2], definitionColor[3]
end

function Building:think(dt, context)
    if self.definition and self.definition.think then
        self.definition.think(self, dt or 0, context or {})
    end
end

function Building:draw(cellSize)
    local r, g, b = self:getOwnerColor()

    if self.hoverProgress > 0 then
        local mix = self.hoverProgress * 0.5
        r = r * (1 - mix) + mix
        g = g * (1 - mix) + mix
        b = b * (1 - mix) + mix
    end

    local function drawPixel(gx, gy, pr, pg, pb, pa)
        love.graphics.setColor(pr, pg, pb, pa or 1)
        love.graphics.rectangle("fill", (gx - 1) * cellSize, (gy - 1) * cellSize, cellSize, cellSize)
    end

    love.graphics.push("all")

    local outline = self.definition.outline
    drawPixel(self.gridX, self.gridY, r, g, b)
    drawPixel(self.gridX - 1, self.gridY - 1, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX, self.gridY - 1, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX + 1, self.gridY - 1, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX - 1, self.gridY, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX + 1, self.gridY, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX - 1, self.gridY + 1, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX, self.gridY + 1, outline[1], outline[2], outline[3], outline[4] or 1)
    drawPixel(self.gridX + 1, self.gridY + 1, outline[1], outline[2], outline[3], outline[4] or 1)

    love.graphics.pop()
end

return Building
