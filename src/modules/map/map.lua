local GM = require("src.core.index")
local Class = require("src.core.class")
local LoadFile = require("src.core.loadFile")
local bit = require("bit")
local Country = require("src.modules.country.country")
local Cell = require("src.modules.map.cell")
local Flags = require("src.modules.hud.flags")

--- @class Map
--- @field cols number
--- @field rows number
--- @field mapData any
--- @field grid Cell[][]
local Map = Class()


--- @param map_path string
--- @param cellSize number
--- @return Map
function Map:init(map_path, cellSize)
    self.IS_LAND_BIT = 7
    self.SHORELINE_BIT = 6
    self.OCEAN_BIT = 5
    self.MAGNITUDE_MASK = 31
    self.cellSize = cellSize
    self.grid = {}

    self.mapData = {
        mapBin    = LoadFile:Bin(map_path .. "map.bin"),
        map4xBin  = LoadFile:Bin(map_path .. "map4x.bin"),
        map16xBin = LoadFile:Bin(map_path .. "map16x.bin"),
        manifest  = LoadFile:Json(map_path .. "manifest.json")
    }

    self.width = self.mapData.manifest["map"]["width"]
    self.height = self.mapData.manifest["map"]["height"]
    self.terrain = self.mapData.mapBin

    self.countries = {}

    self.outlineCells = {}

    self.layers = {
        terrain = true,
        political = true,
        buildings = true
    }

    self.chunkSize = 100
    self.chunks = {}
    self.numChunksX = math.ceil(self.width / self.chunkSize)
    self.numChunksY = math.ceil(self.height / self.chunkSize)

    for x = 1, self.width do
        self.grid[x] = {}
        for y = 1, self.height do
            self.grid[x][y] = Cell(x, y, self.cellSize, self:getTerrainAt(x, y), { self:getCellColor(x, y) })
        end
    end
    for cx = 1, self.numChunksX do
        self.chunks[cx] = {}
        for cy = 1, self.numChunksY do
            local c = love.graphics.newCanvas(self.chunkSize * self.cellSize, self.chunkSize * self.cellSize)
            c:setFilter("nearest", "nearest")
            self.chunks[cx][cy] = {
                canvas = c,
                isDirty = true,
                startX = (cx - 1) * self.chunkSize + 1,
                startY = (cy - 1) * self.chunkSize + 1,
                screenX = (cx - 1) * self.chunkSize * self.cellSize,
                screenY = (cy - 1) * self.chunkSize * self.cellSize
            }
        end
    end
end

--- @param cx number
--- @param cy number
--- @return void
function Map:updateChunk(cx, cy)
    local chunk = self.chunks[cx][cy]

    love.graphics.setCanvas(chunk.canvas)
    love.graphics.clear()

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.translate(-(chunk.startX - 1) * self.cellSize, -(chunk.startY - 1) * self.cellSize)

    local endX = math.min(chunk.startX + self.chunkSize - 1, self.width)
    local endY = math.min(chunk.startY + self.chunkSize - 1, self.height)
    for x = chunk.startX, endX do
        for y = chunk.startY, endY do
            self.grid[x][y]:draw()
        end
    end

    love.graphics.pop()
    love.graphics.setCanvas()
    chunk.isDirty = false
end

--- @return number
function Map:getWidth()
    return self.width
end

--- @return number
function Map:getHeight()
    return self.height
end

--- @param byte number
--- @return table
function Map:decodeTerrainByte(byte)
    local isLand       = bit.band(byte, bit.lshift(1, self.IS_LAND_BIT)) ~= 0
    local isShoreline  = bit.band(byte, bit.lshift(1, self.SHORELINE_BIT)) ~= 0
    local isOcean      = bit.band(byte, bit.lshift(1, self.OCEAN_BIT)) ~= 0
    local magnitude    = bit.band(byte, self.MAGNITUDE_MASK)

    local isImpassable = isLand and magnitude == 31

    return {
        isLand       = isLand,
        isShoreline  = isShoreline,
        isOcean      = isOcean,
        isImpassable = isImpassable,
        magnitude    = magnitude
    }
end

--- @param gx number
--- @param gy number
--- @return boolean
function Map:isValidCell(gx, gy)
    if gx >= 1 and gx <= self.width and gy >= 1 and gy <= self.height then
        return true
    end
    return false
end

--- @param px number
--- @param py number
--- @return boolean
function Map:isValidPixel(px, py)
    local gx = math.floor(px / self.cellSize) + 1
    local gy = math.floor(py / self.cellSize) + 1
    return self:isValidCell(gx, gy)
end

--- @param gx number
--- @param gy number
--- @return table?
function Map:getTerrainAt(gx, gy)
    if self:isValidCell(gx, gy) then
        local index = (gy - 1) * self.width + gx

        local byte = string.byte(self.terrain, index)
        return self:decodeTerrainByte(byte)
    end
    return nil
end

--- @param px number
--- @param py number
--- @return table?
function Map:getTerrainAtPixel(px, py)
    if not self:isValidPixel(px, py) then
        return nil
    end
    local gx = math.floor(px / self.cellSize) + 1
    local gy = math.floor(py / self.cellSize) + 1
    return self:getTerrainAt(gx, gy)
end

--- @param px number
--- @param py number
--- @return Cell?
function Map:getCellAtPixel(px, py)
    if self:isValidPixel(px, py) then
        local gx = math.floor(px / self.cellSize) + 1
        local gy = math.floor(py / self.cellSize) + 1
        return self.grid[gx][gy]
    end
    return nil
end

--- @param px number
--- @param py number
--- @return boolean
function Map:isLand(px, py)
    if not self:isValidPixel(px, py) then
        return false
    end
    local gx = math.floor(px / self.cellSize) + 1
    local gy = math.floor(py / self.cellSize) + 1
    local info = self:getTerrainAt(gx, gy)
    return info ~= nil and info.isLand
end

--- @param info table
--- @return number, number, number, number
function Map:getTerrainColor(info)
    if info.isImpassable then
        return 0, 0, 0, 0
    end

    if not info.isLand then
        if info.isShoreline then
            return 100, 143, 255, 0
        end

        local waterAdj = 1 - math.min(info.magnitude, 10)
        local r = math.max(70 + waterAdj, 0)
        local g = math.max(132 + waterAdj, 0)
        local b = math.max(180 + waterAdj, 0)
        return r, g, b, 0
    end

    if info.isShoreline then
        return 204, 203, 158, 255
    end

    local mag = info.magnitude
    if mag < 10 then
        local adj = 220 - 2 * mag
        return 190, adj, 138, 255
    elseif mag < 20 then
        local adj = 2 * mag
        return 200 + adj, 183 + adj, 138 + adj, 255
    else
        local adj = math.floor(230 + mag / 2)
        return adj, adj, adj, 255
    end
end

--- @param gx number
--- @param gy number
--- @return number, number, number, number
function Map:getCellColor(gx, gy)
    local info = self:getTerrainAt(gx, gy)
    if not info then return 0, 0, 0, 0 end
    return self:getTerrainColor(info)
end

--- @param x number
--- @param y number
--- @return boolean?
function Map:outlineAt(x, y)
    if not self.grid[x][y]:getOwner() then
        return nil
    end
    local owner  = self.grid[x][y]:getOwner().id
    local top    = y > 1 and self.grid[x][y - 1]:getOwner() and self.grid[x][y - 1]:getOwner().id == owner
    local bottom = y < self.height and self.grid[x][y + 1]:getOwner() and self.grid[x][y + 1]:getOwner().id == owner
    local left   = x > 1 and self.grid[x - 1][y]:getOwner() and self.grid[x - 1][y]:getOwner().id == owner
    local right  = x < self.width and self.grid[x + 1][y]:getOwner() and self.grid[x + 1][y]:getOwner().id == owner
    if top and bottom and left and right then
        return false
    else
        return true
    end
end

--- @param owner table
--- @param x number
--- @param y number
--- @param influence number?
--- @return void
function Map:addInfluence(owner, x, y, influence)
    if not influence then influence = 1 end

    self.grid[x][y]:addCountry(owner)
    self.grid[x][y].countries[owner] = self.grid[x][y].countries[owner] + influence

    self:updateOutlineStatus(x, y)
    if x > 1 then self:updateOutlineStatus(x - 1, y) end
    if x < self.width then self:updateOutlineStatus(x + 1, y) end
    if y > 1 then self:updateOutlineStatus(x, y - 1) end
    if y < self.height then self:updateOutlineStatus(x, y + 1) end

    local cx = math.floor((x - 1) / self.chunkSize) + 1
    local cy = math.floor((y - 1) / self.chunkSize) + 1
    self.chunks[cx][cy].isDirty = true
end

--- @param x number
--- @param y number
--- @return void
function Map:clearInfluence(x, y)
    if not self:isValidCell(x, y) then return end
    local cell = self.grid[x][y]
    
    cell.countries = {}
    cell.leaders = {}
    cell.isOutline = nil
    cell.outlineOwnerId = nil
    
    self:updateOutlineStatus(x, y)
    if x > 1 then self:updateOutlineStatus(x - 1, y) end
    if x < self.width then self:updateOutlineStatus(x + 1, y) end
    if y > 1 then self:updateOutlineStatus(x, y - 1) end
    if y < self.height then self:updateOutlineStatus(x, y + 1) end

    local cx = math.floor((x - 1) / self.chunkSize) + 1
    local cy = math.floor((y - 1) / self.chunkSize) + 1
    self.chunks[cx][cy].isDirty = true
end

--- @param x number
--- @param y number
--- @return void
function Map:updateOutlineStatus(x, y)
    if not self:isValidCell(x, y) then return end
    local cell = self.grid[x][y]
    local ownerObj = cell:getOwner()

    if cell.outlineOwnerId and (not ownerObj or ownerObj.id ~= cell.outlineOwnerId) then
        local oldList = self.outlineCells[cell.outlineOwnerId]
        if oldList then oldList[cell] = nil end
        cell.outlineOwnerId = nil
    end

    if not ownerObj then
        cell.isOutline = nil
        return
    end

    local isOut = self:outlineAt(x, y)
    cell.isOutline = isOut

    self.outlineCells[ownerObj.id] = self.outlineCells[ownerObj.id] or {}
    if isOut then
        self.outlineCells[ownerObj.id][cell] = true
        cell.outlineOwnerId = ownerObj.id
    else
        self.outlineCells[ownerObj.id][cell] = nil
        cell.outlineOwnerId = nil
    end
end

--- @param owner table
--- @return table[]
function Map:GetTerritoryOutline(owner)
    if not owner then return {} end
    local set = self.outlineCells[owner.id]
    if not set then return {} end

    local result = {}
    for cell in pairs(set) do
        result[#result + 1] = cell
    end
    return result
end

--- @param layerName string
--- @return void
function Map:toggleLayer(layerName)
    if self.layers[layerName] ~= nil then
        self.layers[layerName] = not self.layers[layerName]
        self:dirtyAllChunks()
    end
end

--- @return void
function Map:dirtyAllChunks()
    for cx = 1, self.numChunksX do
        for cy = 1, self.numChunksY do
            self.chunks[cx][cy].isDirty = true
        end
    end
end

--- @param Country table
--- @param params table
--- @return void
function Map:RegisterCountry(Country, params)
    table.insert(self.countries, Country)
    Country.capitalX = params.x
    Country.capitalY = params.y

    Flags:Load(Country.flag)
    local offset_radius = params.radius - 1
    for i = 1, params.radius * 2 do
        for j = 1, params.radius * 2 do
            local dx = i - offset_radius - 1
            local dy = j - offset_radius - 1

            if dx * dx + dy * dy <= offset_radius * offset_radius + 1 then
                local x = params.x + dx
                local y = params.y + dy

                if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
                    self:addInfluence(Country, math.floor(x + 0.5), math.floor(y + 0.5))
                end
            end
        end
    end
end

--- @param radius number
--- @return void
function Map:FillCountries(radius)
    for i = 1, #self.mapData.manifest["nations"] do
        local nation = self.mapData.manifest["nations"][i]
        if nation["coordinates"] then
            local name = nation["name"]
            local flag = nation["flag"]
            self:RegisterCountry(Country(nil, true, name, flag),
                { x = nation["coordinates"][1], y = nation["coordinates"][2], radius = radius })
        end
    end
end

--- @param camera table
--- @return void
function Map:draw(camera)
    local W, H           = love.graphics.getDimensions()

    local left           = (0 / camera.scale - camera.x)
    local right          = (W / camera.scale - camera.x)
    local top            = (0 / camera.scale - camera.y)
    local bottom         = (H / camera.scale - camera.y)

    local pixelChunkSize = self.chunkSize * self.cellSize

    local startCx        = math.max(1, math.floor(left / pixelChunkSize) + 1)
    local endCx          = math.min(self.numChunksX, math.ceil(right / pixelChunkSize))
    local startCy        = math.max(1, math.floor(top / pixelChunkSize) + 1)
    local endCy          = math.min(self.numChunksY, math.ceil(bottom / pixelChunkSize))

    for cx = startCx, endCx do
        for cy = startCy, endCy do
            local chunk = self.chunks[cx][cy]
            if chunk.isDirty then
                self:updateChunk(cx, cy)
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(chunk.canvas, chunk.screenX, chunk.screenY)
            -- love.graphics.setColor(1, 1, 1, 0.5)
            -- love.graphics.rectangle("line", chunk.screenX, chunk.screenY, self.cellSize * self.chunkSize, self.cellSize * self.chunkSize)
        end
    end
end

--- @return void
function GM.Map:Initialize()
    self.Class = Map
end

--- @return void
function GM.Map:Draw()
end

--- @return void
function GM.Map:Think(dt)
    dt = dt or love.timer.getDelta()
    local map = GM.Game and GM.Game.Map
    if not map then return end

    self.expansionTimer = (self.expansionTimer or 0) + dt
    if self.expansionTimer >= 3.0 then
        self.expansionTimer = 0
        local player = GM.PlayerCountry
        if player and GM.Hud and GM.Hud.Instance then
            local allocation = GM.Hud.Instance.powerAllocation.expansion or 0
            if allocation > 0 then
                local cellsToExpand = math.floor(allocation / 5) + 1
                local candidates = {}
                for x = 1, map.width do
                    for y = 1, map.height do
                        local cell = map.grid[x][y]
                        if cell:getOwner() == player then
                            local neighbors = {
                                {x = x - 1, y = y},
                                {x = x + 1, y = y},
                                {x = x, y = y - 1},
                                {x = x, y = y + 1}
                            }
                            for _, n in ipairs(neighbors) do
                                if map:isValidCell(n.x, n.y) then
                                    local nCell = map.grid[n.x][n.y]
                                    if nCell.data.isLand and nCell:getOwner() ~= player and not nCell.data.isImpassable then
                                        table.insert(candidates, nCell)
                                    end
                                end
                            end
                        end
                    end
                end
                for i = 1, math.min(cellsToExpand, #candidates) do
                    local idx = math.random(1, #candidates)
                    local target = candidates[idx]
                    table.remove(candidates, idx)
                    map:addInfluence(player, target.x, target.y, 1.0)
                end
            end
        end
    end

    self.aiExpansionTimer = (self.aiExpansionTimer or 0) + dt
    if self.aiExpansionTimer >= 4.0 then
        self.aiExpansionTimer = 0
        for _, country in ipairs(map.countries) do
            if country.isAI then
                local candidates = {}
                for x = 1, map.width do
                    for y = 1, map.height do
                        local cell = map.grid[x][y]
                        if cell:getOwner() == country then
                            local neighbors = {
                                {x = x - 1, y = y},
                                {x = x + 1, y = y},
                                {x = x, y = y - 1},
                                {x = x, y = y + 1}
                            }
                            for _, n in ipairs(neighbors) do
                                if map:isValidCell(n.x, n.y) then
                                    local nCell = map.grid[n.x][n.y]
                                    if nCell.data.isLand and nCell:getOwner() ~= country and not nCell.data.isImpassable then
                                        local protected = false
                                        if GM.Battalions and GM.Battalions.List then
                                            for _, bat in ipairs(GM.Battalions.List) do
                                                local dx = n.x - bat.x
                                                local dy = n.y - bat.y
                                                if dx*dx + dy*dy <= 4 then
                                                    protected = true
                                                    break
                                                end
                                            end
                                        end
                                        if not protected then
                                            table.insert(candidates, nCell)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if #candidates > 0 then
                    local target = candidates[math.random(1, #candidates)]
                    map:addInfluence(country, target.x, target.y, 1.0)
                end
            end
        end
    end
end

return Map
