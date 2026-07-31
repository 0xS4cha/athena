local GM = require("src.core.index")
local bfs = require("src.modules.algorithms.bfs")

GM.Roads = {}
GM.Roads.List = {}

GM.Modules:Register("Roads", 65)

function GM.Roads:Initialize()
    self.List = {}
end

function GM.Roads:ConnectBuilding(newBuilding)
    local map = GM.Game and GM.Game.Map
    if not map then return end

    local newOwner = nil
    if newBuilding.cell and newBuilding.cell.getOwner then
        newOwner = newBuilding.cell:getOwner()
    end
    if not newOwner then return end

    local nearestBuilding = nil
    local minDist = math.huge

    for _, b in ipairs(GM.Building.List) do
        if b ~= newBuilding then
            local bOwner = nil
            if b.cell and b.cell.getOwner then
                bOwner = b.cell:getOwner()
            end
            if bOwner and bOwner.id == newOwner.id then
                local dx = b.x - newBuilding.x
                local dy = b.y - newBuilding.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < minDist then
                    minDist = dist
                    nearestBuilding = b
                end
            end
        end
    end

    if nearestBuilding then
        local startCell = map.grid[newBuilding.x][newBuilding.y]
        local goalCell = map.grid[nearestBuilding.x][nearestBuilding.y]

        local function isWalkable(cell)
            return cell.data and cell.data.isLand
        end

        local path = bfs(startCell, goalCell, isWalkable, map)
        if not path then
            path = bfs(startCell, goalCell, nil, map)
        end

        if path then
            table.insert(self.List, {
                path = path,
                progress = 1,
                speed = 25,
                startX = newBuilding.x,
                startY = newBuilding.y,
                endX = nearestBuilding.x,
                endY = nearestBuilding.y
            })
        end
    end
end

function GM.Roads:RemoveRoadsForBuilding(x, y)
    for i = #self.List, 1, -1 do
        local r = self.List[i]
        if (r.startX == x and r.startY == y) or (r.endX == x and r.endY == y) then
            table.remove(self.List, i)
        end
    end
end

function GM.Roads:Think(dt)
    dt = dt or love.timer.getDelta()
    for _, road in ipairs(self.List) do
        if road.progress < #road.path then
            road.progress = math.min(#road.path, road.progress + dt * road.speed)
        end
    end
end

function GM.Roads:Draw()
    local map = GM.Game and GM.Game.Map
    if not map or #self.List == 0 then return end
    if not GM.Camera then return end

    GM.Camera:apply()

    local cellSize = map.cellSize or 1

    for _, road in ipairs(self.List) do
        local limit = math.floor(road.progress)
        for i = 1, limit do
            local cell = road.path[i]

            local r, g, b = 0.45, 0.45, 0.45

            love.graphics.setColor(r, g, b, 0.8)
            love.graphics.rectangle("fill", (cell.x - 1) * cellSize, (cell.y - 1) * cellSize, cellSize, cellSize)
        end
    end

    GM.Camera:clear()
end

return GM.Roads
