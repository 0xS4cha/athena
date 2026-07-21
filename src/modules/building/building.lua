local Class = require("src.core.class")

--- @class Building
--- @field gridX number
--- @field gridY number
--- @field type string
--- @field name string
--- @field owner table
--- @field hoverProgress number
local Building = Class()

function Building:init(gridX, gridY, type, name, cell)
    self.gridX = gridX
    self.gridY = gridY
    self.type = type or "capital"
    self.name = name or "Unnamed City"
    self.cell = cell
    self.hoverProgress = 0
end

function Building:draw(cellSize)
    local r, g, b = 0.8, 0.8, 0.8
    if self.cell and self.cell:getOwner() then
        r = self.cell:getOwner().color[1] / 255
        g = self.cell:getOwner().color[2] / 255
        b = self.cell:getOwner().color[3] / 255
    end

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

    if self.type == "capital" then
        drawPixel(self.gridX, self.gridY, 1, 0.84, 0)
        drawPixel(self.gridX, self.gridY - 1, r, g, b)
        drawPixel(self.gridX, self.gridY + 1, r, g, b)
        drawPixel(self.gridX - 1, self.gridY, r, g, b)
        drawPixel(self.gridX + 1, self.gridY, r, g, b)
        drawPixel(self.gridX - 1, self.gridY - 1, r, g, b, 0.4)
        drawPixel(self.gridX + 1, self.gridY - 1, r, g, b, 0.4)
        drawPixel(self.gridX - 1, self.gridY + 1, r, g, b, 0.4)
        drawPixel(self.gridX + 1, self.gridY + 1, r, g, b, 0.4)
    elseif self.type == "fort" then
        drawPixel(self.gridX, self.gridY, r, g, b)
        local br, bg, bb = 0.12, 0.12, 0.12
        drawPixel(self.gridX - 1, self.gridY - 1, br, bg, bb)
        drawPixel(self.gridX, self.gridY - 1, br, bg, bb)
        drawPixel(self.gridX + 1, self.gridY - 1, br, bg, bb)
        drawPixel(self.gridX - 1, self.gridY, br, bg, bb)
        drawPixel(self.gridX + 1, self.gridY, br, bg, bb)
        drawPixel(self.gridX - 1, self.gridY + 1, br, bg, bb)
        drawPixel(self.gridX, self.gridY + 1, br, bg, bb)
        drawPixel(self.gridX + 1, self.gridY + 1, br, bg, bb)
    elseif self.type == "port" then
        drawPixel(self.gridX, self.gridY, r, g, b)
        local pr, pg, pb = 0.2, 0.5, 0.9
        drawPixel(self.gridX, self.gridY - 1, pr, pg, pb)
        drawPixel(self.gridX - 1, self.gridY, pr, pg, pb)
        drawPixel(self.gridX + 1, self.gridY, pr, pg, pb)
        drawPixel(self.gridX - 1, self.gridY + 1, pr, pg, pb)
        drawPixel(self.gridX + 1, self.gridY + 1, pr, pg, pb)
        drawPixel(self.gridX, self.gridY + 1, pr, pg, pb)
    end

    love.graphics.pop()
end

return Building
