local GM = require("src.core.index")
local Building = require("src.modules.building.building")

GM.Building = {}
GM.Building.List = {}

GM.Modules:Register("Building", 60)

function GM.Building:Initialize()
    self.List = {}
end

function GM.Building:SpawnBuilding(gridX, gridY, type, name, cell)
    local b = Building(gridX, gridY, type, name, cell)
    table.insert(self.List, b)
    return b
end

function GM.Building:GenerateBuildings(map)
    self.List = {}

    for _, country in ipairs(map.countries) do
        if country.capitalX and country.capitalY then
            local capitalName = country.name .. " Capital"
            self:SpawnBuilding(country.capitalX, country.capitalY, "capital", capitalName, map.grid[country.capitalX][country.capitalY])
        end
    end

    for _, country in ipairs(map.countries) do
        local ownedCells = {}
        local shorelineCells = {}
        for x = 1, map.width, 2 do
            for y = 1, map.height, 2 do
                local cell = map.grid[x][y]
                if cell and cell.owner == country then
                    local isCapital = (x == country.capitalX and y == country.capitalY)
                    if not isCapital then
                        if cell.data and cell.data.isLand then
                            table.insert(ownedCells, { x = x, y = y })

                            local isAdjacentToWater = false
                            local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
                            for _, d in ipairs(dirs) do
                                local nx, ny = x + d[1], y + d[2]
                                if map:isValidCell(nx, ny) then
                                    local neighbor = map.grid[nx][ny]
                                    if neighbor.data and not neighbor.data.isLand then
                                        isAdjacentToWater = true
                                        break
                                    end
                                end
                            end
                            if isAdjacentToWater then
                                table.insert(shorelineCells, { x = x, y = y })
                            end
                        end
                    end
                end
            end
        end

        if #ownedCells > 0 then
            local numForts = math.min(2, #ownedCells)
            for f = 1, numForts do
                local idx = math.random(1, #ownedCells)
                local pos = ownedCells[idx]
                table.remove(ownedCells, idx)

                local name = "Fort " .. country.name .. " " .. string.char(64 + f)
                self:SpawnBuilding(pos.x, pos.y, "fort", name, map.grid[pos.x][pos.y])
            end
        end

        if #shorelineCells > 0 then
            local pos = shorelineCells[math.random(1, #shorelineCells)]
            local name = "Port of " .. country.name
            self:SpawnBuilding(pos.x, pos.y, "port", name, map.grid[pos.x][pos.y])
        end
    end
end

function GM.Building:GetWorldMouse()
    if not GM.Camera then return 0, 0 end
    local mx, my = love.mouse.getPosition()
    local worldX = (mx / GM.Camera.scale) - GM.Camera.x
    local worldY = (my / GM.Camera.scale) - GM.Camera.y
    return worldX, worldY
end

function GM.Building:Think()
    local worldX, worldY = self:GetWorldMouse()

    for _, b in ipairs(self.List) do
        local dx = worldX - b.gridX
        local dy = worldY - b.gridY
        local dist = math.sqrt(dx * dx + dy * dy)

        local hoverDist = 12 / (GM.Camera and GM.Camera.scale or 1)
        hoverDist = math.max(4, math.min(16, hoverDist))

        if dist <= hoverDist then
            b.hoverProgress = math.min(1.0, b.hoverProgress + 0.12)
        else
            b.hoverProgress = math.max(0.0, b.hoverProgress - 0.12)
        end
    end
end

function GM.Building:Draw()
    if GM.Game and GM.Game.Map and GM.Game.Map.layers.buildings then
        local map = GM.Game.Map
        for _, b in ipairs(self.List) do
            b:draw(map.cellSize)
        end
    end
end
