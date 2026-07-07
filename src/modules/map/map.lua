local GM = require("src.core.index")
local Class = require("src.core.class")
local LoadFile = require("src.core.LoadFile")

--- @class Map
--- @field cols number
--- @field rows number 
--- @field mapData any
--- @field grid Cell[][]
local Map = Class()


--- @param map_path string
function Map:init(map_path)
    self.IS_LAND_BIT = 7
    self.SHORELINE_BIT = 6
    self.OCEAN_BIT = 5
    self.MAGNITUDE_MASK = 31

    self.grid = {}

    self.mapData = {
        mapBin      = LoadFile:Bin(map_path .. "map.bin"),
        map4xBin    = LoadFile:Bin(map_path .. "map4x.bin"),
        map16xBin   = LoadFile:Bin(map_path .. "map16x.bin"),
        manifest    = LoadFile:Json(map_path .. "manifest.json")
    }
    self.width = self.mapData.manifest["map"]["width"]
    self.height = self.mapData.manifest["map"]["height"]
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