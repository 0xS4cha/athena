---@diagnostic disable: undefined-global
local GM = require("src.core.index")
local Building = require("src.modules.building.building")
local BuildingTypes = {
    capital = require("src.modules.building.city"),
    fort = require("src.modules.building.fort"),
    port = require("src.modules.building.port"),
    village = require("src.modules.building.village")
}

GM.Building = {}
GM.Building.List = {}
GM.Building.Types = BuildingTypes

GM.Modules:Register("Building", 60)

function GM.Building:Initialize()
    self.List = {}
end

function GM.Building:RegisterType(name, definition)
    self.Types[name] = definition
end

function GM.Building:GetTypeDefinition(type)
    return self.Types[type] or self.Types.capital
end

function GM.Building:SpawnBuilding(x, y, type, name, cell)
    local definition = self:GetTypeDefinition(type)
    local b = Building(x, y, type, name, cell, definition)
    table.insert(self.List, b)
    return b
end

local function reserveCell(occupied, x, y)
    occupied[x] = occupied[x] or {}
    occupied[x][y] = true
end

local function isReserved(occupied, x, y)
    return occupied[x] and occupied[x][y]
end

local function collectCountryCells(map, country, occupied)
    local ownedCells = {}
    local shorelineCells = {}
    local dirs = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }

    for x = 1, map.width do
        for y = 1, map.height do
            local cell = map.grid[x] and map.grid[x][y]
            if cell and cell.owner == country and cell.data and cell.data.isLand and not isReserved(occupied, x, y) then
                table.insert(ownedCells, { x = x, y = y })

                local isAdjacentToWater = false
                for _, d in ipairs(dirs) do
                    local nx, ny = x + d[1], y + d[2]
                    if map:isValidCell(nx, ny) then
                        local neighbor = map.grid[nx][ny]
                        if neighbor and neighbor.data and not neighbor.data.isLand and not isReserved(occupied, nx, ny) then
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

    return ownedCells, shorelineCells
end

local function takeRandomCell(pool)
    if #pool == 0 then
        return nil
    end

    local index = math.random(1, #pool)
    local pos = pool[index]
    table.remove(pool, index)
    return pos
end

function GM.Building:GenerateBuildings(map)
    self.List = {}
    local occupied = {}

    for _, country in ipairs(map.countries) do
        if country.capitalX and country.capitalY then
            local capitalName = country.name .. " Capital"
            local capitalCell = map.grid[country.capitalX] and map.grid[country.capitalX][country.capitalY]
            self:SpawnBuilding(country.capitalX, country.capitalY, "city", capitalName, capitalCell)
            reserveCell(occupied, country.capitalX, country.capitalY)
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

function GM.Building:Think(dt)
    dt = dt or love.timer.getDelta()
    local worldX, worldY = self:GetWorldMouse()
    local context = {
        camera = GM.Camera,
        mouse = { x = worldX, y = worldY },
        map = GM.Game and GM.Game.Map or nil,
        deltaTime = dt
    }

    local toTransform = {}

    for i, b in ipairs(self.List) do
        b:think(dt, context)

        if b._shouldTransform then
            table.insert(toTransform, i)
            b._shouldTransform = nil
        end

        local dx = worldX - b.x
        local dy = worldY - b.y
        local dist = math.sqrt(dx * dx + dy * dy)

        local hoverDist = 12 / (GM.Camera and GM.Camera.scale or 1)
        hoverDist = math.max(4, math.min(16, hoverDist))

        if dist <= hoverDist then
            b.hoverProgress = math.min(1.0, b.hoverProgress + 0.12)
        else
            b.hoverProgress = math.max(0.0, b.hoverProgress - 0.12)
        end
    end

    for _, idx in ipairs(toTransform) do
        local building = self.List[idx]
        if building and building.type == "village" then
            local cityDef = self:GetTypeDefinition("city")
            building:transform("city", cityDef)
            Logger:info("Building", building.name .. " upgraded to City!")
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
