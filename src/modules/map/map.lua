local GM = require("src.core.index")
local Class = require("src.core.class")
local LoadFile = require("src.core.loadFile")
local bit = require("bit")
local Country = require("src.modules.country.country")
local Cell = require("src.modules.map.cell")

--- @class Map
--- @field cols number
--- @field rows number 
--- @field mapData any
--- @field grid Cell[][]
local Map = Class()


--- @param map_path string
function Map:init(map_path, cellSize)
    self.IS_LAND_BIT = 7
    self.SHORELINE_BIT = 6
    self.OCEAN_BIT = 5
    self.MAGNITUDE_MASK = 31
    self.cellSize = cellSize
    self.grid = {}

    self.mapData = {
        mapBin      = LoadFile:Bin(map_path .. "map.bin"),
        map4xBin    = LoadFile:Bin(map_path .. "map4x.bin"),
        map16xBin   = LoadFile:Bin(map_path .. "map16x.bin"),
        manifest    = LoadFile:Json(map_path .. "manifest.json")
    }
    self.width = self.mapData.manifest["map"]["width"]
    self.height = self.mapData.manifest["map"]["height"]
    self.terrain = self.mapData.mapBin
    self.countries = {}

    self.chunkSize = 100
    self.chunks = {}
    self.numChunksX = math.ceil(self.width / self.chunkSize)
    self.numChunksY = math.ceil(self.height / self.chunkSize)

    for x = 1, self.width do
        self.grid[x] = {}
        for y = 1, self.height do
            self.grid[x][y] = Cell(x, y, self.cellSize, self:getTerrainAt(x, y), {self:getCellColor(x, y)})
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

function Map:updateChunk(cx, cy)
    local chunk = self.chunks[cx][cy]
    
    love.graphics.setCanvas(chunk.canvas)
    love.graphics.clear()

    -- Ensure chunk baking is done in canvas-local space only.
    -- Without this reset, world camera transforms can leak into the canvas.
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
function Map:decodeTerrainByte(byte)
    local isLand        = bit.band(byte, bit.lshift(1, self.IS_LAND_BIT)) ~= 0
    local isShoreline   = bit.band(byte, bit.lshift(1, self.SHORELINE_BIT)) ~= 0
    local isOcean       = bit.band(byte, bit.lshift(1, self.OCEAN_BIT)) ~= 0
    local magnitude     = bit.band(byte, self.MAGNITUDE_MASK)

    local isImpassable  = isLand and magnitude == 31

    return {
        isLand          = isLand,
        isShoreline     = isShoreline,
        isOcean         = isOcean,
        isImpassable    = isImpassable,
        magnitude       = magnitude
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
--- @return any
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
--- @return any
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
--- @return number r, number g, number b, number a
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

function Map:getCellColor(gx, gy)
    local info = self:getTerrainAt(gx, gy)
    if not info then return 0, 0, 0, 0 end
    return self:getTerrainColor(info)
end

--- @param y number
--- @param x number
--- @return boolean?
function Map:outlineAt(x, y)
    if not self.grid[x][y].owner then
        return nil
    end
    local owner     = self.grid[x][y].owner.id
    local top       = y > 1 and self.grid[x][y - 1].owner and self.grid[x][y - 1].owner.id == owner
    local bottom    = y < self.height and self.grid[x][y + 1].owner and self.grid[x][y + 1].owner.id == owner
    local left      = x > 1 and self.grid[x - 1][y].owner and self.grid[x - 1][y].owner.id == owner
    local right     = x < self.width and self.grid[x + 1][y].owner and self.grid[x + 1][y].owner.id == owner
    if top and bottom and left and right then
        return false
    else
        return true
    end
end

function Map:setOwner(owner, x, y)
    self.grid[x][y].owner = owner
    -- self.grid[x][y].isOutline = nil

    -- if x > 1 then 
    --     self.grid[x-1][y].isOutline = nil
    -- end
    -- if x < self.width then self.grid[x+1][y].isOutline = nil end
    -- if y > 1 then self.grid[x][y-1].isOutline = nil end
    -- if y < self.height then self.grid[x][y+1].isOutline = nil end
    local cx = math.floor((x - 1) / self.chunkSize) + 1
    local cy = math.floor((y - 1) / self.chunkSize) + 1
    self.chunks[cx][cy].isDirty = true
end

function Map:RegisterCountry(Country, params)
    table.insert(self.countries, Country)
    local offset_radius = params.radius - 1

    for i = 1, params.radius * 2 do
        for j = 1, params.radius * 2 do
            local dx = i - offset_radius - 1
            local dy = j - offset_radius - 1

            if dx * dx + dy * dy <= offset_radius * offset_radius + 1 then
                local x = params.x + dx
                local y = params.y + dy

                if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
                    self:setOwner(Country, math.floor(x + 0.5), math.floor(y + 0.5))
                end
            end
        end
    end
end

function Map:FillCountries()
    for i = 1, #self.mapData.manifest["nations"] do
        local nation = self.mapData.manifest["nations"][i]
        self:RegisterCountry(Country(nil, true), {x = nation["coordinates"][1], y = nation["coordinates"][2], radius = 4})
    end
end

function Map:draw(camera)
    local W, H = love.graphics.getDimensions()
    
    local left      = (0 / camera.scale - camera.x)
    local right     = (W / camera.scale - camera.x)
    local top       = (0 / camera.scale - camera.y)
    local bottom    = (H / camera.scale - camera.y)
    
    local pixelChunkSize = self.chunkSize * self.cellSize
    
    local startCx = math.max(1, math.floor(left / pixelChunkSize) + 1)
    local endCx   = math.min(self.numChunksX, math.ceil(right / pixelChunkSize))
    local startCy = math.max(1, math.floor(top / pixelChunkSize) + 1)
    local endCy   = math.min(self.numChunksY, math.ceil(bottom / pixelChunkSize))
    
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