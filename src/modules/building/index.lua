---@diagnostic disable: undefined-global
local GM = require("src.core.index")
local bfs = require("src.modules.algorithms.bfs")
local json = require("libs.json.json")
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
    local toExpansion = {}

    for i, b in ipairs(self.List) do
        b:think(dt, context)

        if b._shouldTransform then
            table.insert(toTransform, i)
            b._shouldTransform = nil
        end

        if b._shouldExpansion then
            table.insert(toExpansion, i)
            b._shouldExpansion = nil
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

    for _, idx in ipairs(toExpansion) do
        local building = self.List[idx]
        if building and building.type == "city" then
            local pool = bfs(
                GM.Game.Map:getCellAtPixel(building.x, building.y),
                nil,
                function(cell)
                    if cell.x == building.x + 1 then
                        print(cell:getOwner())
                    end
                    if not GM.Game.Map:isValidCell(cell.x, cell.y) or not cell:getOwner() or not cell:getOwner().id or cell:getOwner().id ~= building.cell:getOwner().id then 
                        return false
                    end
                    return true
                end,
                GM.Game.Map
            )
            print(pool, json.encode(pool))
            local cell = takeRandomCell(pool)
            if not cell then goto continue end
            self:SpawnBuilding(cell.x, cell.y, "village", "capitalName", cell)
            Logger:info("Building", building.name .. " expanded !")
            ::continue::
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
