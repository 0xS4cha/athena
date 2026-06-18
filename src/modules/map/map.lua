local GM = require("src.core.index")
local Class = require("src.core.class")
local Cell = require("src.modules.map.cell")

--- @class Map
--- @field cols number
--- @field rows number 
--- @field cellSize number
--- @field grid Cell[][]
local Map = Class()


--- @param cols number
--- @param rows number
--- @param cellSize number
function Map:init(cols, rows, cellSize)
    self.cols = cols
    self.rows = rows
    self.cellSize = cellSize
    self.grid = {}

    for x = 1, cols do
        self.grid[x] = {}
        for y = 1, rows do
            self.grid[x][y] = Cell(x, y, cellSize)
        end
    end
end

--- @param px number
--- @param py number
--- @return Cell?
function Map:getCellAtPixel(px, py)
    local gx = math.floor(px / self.cellSize) + 1
    local gy = math.floor(py / self.cellSize) + 1

    if gx >= 1 and gx <= self.cols and gy >= 1 and gy <= self.rows then
        return self.grid[gx][gy]
    end
    return nil
end

--- @param cell Cell
--- @return Cell[]
function Map:getNeighbors(cell)
    local neighbors = {}
    local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    
    for _, dir in ipairs(directions) do
        local nx = cell.gridX + dir[1]
        local ny = cell.gridY + dir[2]
        if nx >= 1 and nx <= self.cols and ny >= 1 and ny <= self.rows then
            table.insert(neighbors, self.grid[nx][ny])
        end
    end
    return neighbors
end

--- @param attackerCell Cell
--- @param targetCell Cell
function Map:interact(attackerCell, targetCell)
    if not attackerCell or not targetCell or attackerCell == targetCell then return end
    if attackerCell.owner == nil or attackerCell.troops <= 1 then return end

    local isNeighbor = false
    for _, n in ipairs(self:getNeighbors(attackerCell)) do
        if n == targetCell then isNeighbor = true; break end
    end
    if not isNeighbor then return end

    local invadingTroops = attackerCell.troops - 1
    attackerCell.troops = 1

    if targetCell.owner == attackerCell.owner then
        targetCell.troops = targetCell.troops + invadingTroops
    else
        if invadingTroops > targetCell.troops then
            targetCell.owner = attackerCell.owner
            targetCell.troops = invadingTroops - targetCell.troops
        else
            targetCell.troops = targetCell.troops - invadingTroops
        end
    end
end

function Map:updateIncomes()
    for x = 1, self.cols do
        for y = 1, self.rows do
            local cell = self.grid[x][y]
            if cell.owner then
                cell.troops = cell.troops + 1
            end
        end
    end
end

function Map:draw()
    for x = 1, self.cols do
        for y = 1, self.rows do
            self.grid[x][y]:draw()
        end
    end
end

function GM.Map:Initialize()
    self.Class = Map
end

function GM.Map:Draw()
    if self.Instance then
        self.Instance:draw()
    end
end

function GM.Map:Think()
    if self.Instance and GM.TickSecond then
        self.Instance:updateIncomes()
    end
end

return Map