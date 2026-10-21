local ffi = require("ffi")
local bit = require("bit")
local Class = require("src.core.class")
local Config = require("src.config.game")
local Map = require("src.modules.map.map")
local GameConfig = require("src.config.game")

local band = bit.band
local floor = math.floor

local Renderer = Class()

local PALETTE_SIZE = 1024

local PALETTE_SHADER = [[
extern Image palette;
extern number count;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec4 p = Texel(tex, uv);
    if (p.a < 0.5) {
        return vec4(0.0);
    }
    float id = floor(p.r * 255.0 + 0.5) + floor(p.g * 255.0 + 0.5) * 256.0;
    vec4 c = Texel(palette, vec2((id + 0.5) / count, 0.5));
    if (p.b > 0.5) {
        return vec4(c.rgb * 0.7, 1.0) * color;
    }
    return c * color;
}
]]

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
    self.layers = { terrain = true, political = true, units = true, names = true, supply = false, threat = false, diplomacy = false }

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
    if self.idPtr then
        self:paintId(i)
        self.idDirty = true
    end
end

function Renderer:paintId(i)
    local ptr = self.idPtr
    local o = i * 4
    local id = self.map.owner[i]
    if id == 0 or id >= PALETTE_SIZE then
        ptr[o + 3] = 0
        return
    end
    ptr[o] = id % 256
    ptr[o + 1] = floor(id / 256)
    ptr[o + 2] = self.game.players[id].borders[i] and 255 or 0
    ptr[o + 3] = 255
end

function Renderer:buildIds()
    local map = self.map
    self.idData = love.image.newImageData(map.width, map.height)
    local ptr = ffi.cast("uint8_t*", self.idData:getFFIPointer())
    self.idPtr = ptr
    local owner = map.owner
    local players = self.game.players
    for i = 0, map.size - 1 do
        local id = owner[i]
        if id ~= 0 and id < PALETTE_SIZE then
            local o = i * 4
            ptr[o] = id % 256
            ptr[o + 1] = floor(id / 256)
            ptr[o + 2] = players[id].borders[i] and 255 or 0
            ptr[o + 3] = 255
        end
    end
    self.idImage = love.graphics.newImage(self.idData)
    self.idImage:setFilter("nearest", "nearest")
    self.paletteData = love.image.newImageData(PALETTE_SIZE, 1)
    self.paletteImage = love.graphics.newImage(self.paletteData)
    self.paletteImage:setFilter("nearest", "nearest")
    self.paletteShader = love.graphics.newShader(PALETTE_SHADER)
    self.idDirty = false
end

function Renderer:setPaletteColor(id, r, g, b, a)
    if not self.paletteData or id >= PALETTE_SIZE then return end
    self.paletteData:setPixel(id, 0, r, g, b, a)
    self.paletteDirty = true
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
    if name == "diplomacy" and self.layers.diplomacy and not self.idData then
        self:buildIds()
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
        if self.layers.diplomacy and self.idImage then
            if self.idDirty then
                self.idImage:replacePixels(self.idData)
                self.idDirty = false
            end
            if self.paletteDirty then
                self.paletteImage:replacePixels(self.paletteData)
                self.paletteDirty = false
            end
            love.graphics.setShader(self.paletteShader)
            self.paletteShader:send("palette", self.paletteImage)
            self.paletteShader:send("count", PALETTE_SIZE)
            love.graphics.draw(self.idImage, 0, 0)
            love.graphics.setShader()
        else
            love.graphics.draw(self.territoryImage, 0, 0)
        end
    end
end

return Renderer
