local ffi = require("ffi")
local bit = require("bit")
local Class = require("src.core.class")
local Config = require("src.config.game")
local Map = require("src.modules.map.map")
local GameConfig = require("src.config.game")

local band = bit.band
local floor = math.floor

local Renderer = Class()

local function terrainColor(byte, latitude)
    local isLand = band(byte, 128) ~= 0
    local isShore = band(byte, 64) ~= 0
    local mag = band(byte, 31)

    if not isLand then
        if isShore then
            return 100, 143, 255
        end
        local adj = 1 - math.min(mag, 10)
        return math.max(70 + adj, 0), math.max(132 + adj, 0), math.max(180 + adj, 0)
    end

    local biome = Map.classify(byte, latitude)
    if biome == Config.biomes.snow.id then
        local v = 228 + math.min(mag, 27) % 7 * 3
        return v, math.min(255, v + 6), 255
    elseif biome == Config.biomes.mountain.id then
        local v = 118 + (mag - Config.mountainMagnitude) * 7
        return v + 12, v, v - 14
    elseif biome == Config.biomes.desert.id then
        local d = mag - Config.desertMagnitude
        return 228 - d * 2, 206 - d * 3, 140 - d * 4
    end
    if isShore then
        return 204, 203, 158
    end
    return 150 - mag * 4, 205 - mag * 3, 110 - mag * 2
end

Renderer.terrainColor = terrainColor

function Renderer.preview(path, manifest)
    local info = manifest.map16x or manifest.map
    local file = manifest.map16x and "map16x.bin" or "map.bin"
    local raw = love.filesystem.read(path .. file)
    if not raw then return nil end
    local w, h = info.width, info.height
    local data = love.image.newImageData(w, h)
    local ptr = ffi.cast("uint8_t*", data:getFFIPointer())
    for i = 0, math.min(#raw, w * h) - 1 do
        local r, g, b = terrainColor(raw:byte(i + 1), (math.floor(i / w) + 0.5) / h)
        ptr[i * 4], ptr[i * 4 + 1], ptr[i * 4 + 2], ptr[i * 4 + 3] = r, g, b, 255
    end
    local image = love.graphics.newImage(data)
    image:setFilter("linear", "linear")
    data:release()
    return image
end

function Renderer:init(game)
    self.game = game
    self.map = game.map
    self.layers = { terrain = true, political = true, units = true, names = true, supply = false, threat = false }

    local map = self.map
    local w, h = map.width, map.height
    local terrainData = love.image.newImageData(w, h)
    local plainData = love.image.newImageData(w, h)
    local tp = ffi.cast("uint8_t*", terrainData:getFFIPointer())
    local pp = ffi.cast("uint8_t*", plainData:getFFIPointer())
    local terrain = map.terrain

    for i = 0, map.size - 1 do
        local byte = terrain[i]
        local r, g, b = terrainColor(byte, (math.floor(i / w) + 0.5) / h)
        local o = i * 4
        tp[o], tp[o + 1], tp[o + 2], tp[o + 3] = r, g, b, 255
        if band(byte, 128) ~= 0 then
            pp[o], pp[o + 1], pp[o + 2] = 38, 38, 43
        else
            pp[o], pp[o + 1], pp[o + 2] = 15, 20, 31
        end
        pp[o + 3] = 255
    end

    self.terrainImage = love.graphics.newImage(terrainData)
    self.terrainImage:setFilter("nearest", "nearest")
    self.plainImage = love.graphics.newImage(plainData)
    self.plainImage:setFilter("nearest", "nearest")
    terrainData:release()
    plainData:release()

    self.territoryData = love.image.newImageData(w, h)
    self.territoryPtr = ffi.cast("uint8_t*", self.territoryData:getFFIPointer())
    self.territoryImage = love.graphics.newImage(self.territoryData)
    self.territoryImage:setFilter("nearest", "nearest")
    self.dirty = false
end

function Renderer:paintTile(i)
    local map = self.map
    local ptr = self.territoryPtr
    local o = i * 4
    local id = map.owner[i]

    if id == 0 then
        local f = map.fallout[i]
        if f >= GameConfig.scorchedFallout then
            local n = (i * 2654435761) % 7
            ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3] = 38 + n * 3, 32 + n * 2, 28 + n, 215
        elseif f > 0 then
            ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3] = 110, 190, 50, 40 + floor(f * 0.6)
        else
            ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3] = 0, 0, 0, 0
        end
    else
        local player = self.game.players[id]
        local c = player.color255
        if player.borders[i] then
            ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3] = floor(c[1] * 0.7), floor(c[2] * 0.7), floor(c[3] * 0.7), 255
        else
            ptr[o], ptr[o + 1], ptr[o + 2], ptr[o + 3] = c[1], c[2], c[3], 120
        end
    end
    self.dirty = true
end

function Renderer:repaintAll()
    for i = 0, self.map.size - 1 do
        self:paintTile(i)
    end
end

function Renderer:toggleLayer(name)
    if self.layers[name] ~= nil then
        self.layers[name] = not self.layers[name]
    end
end

function Renderer:draw()
    if self.dirty then
        self.territoryImage:replacePixels(self.territoryData)
        self.dirty = false
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.layers.terrain and self.terrainImage or self.plainImage, 0, 0)
    if self.layers.political then
        love.graphics.draw(self.territoryImage, 0, 0)
    end
end

return Renderer
