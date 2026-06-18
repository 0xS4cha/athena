local ffi = require("ffi")
local ZONES = require("src.config.zone")

local Heightmap = {}


local zoneLUT = {}

local function getZone(luminosity)
    for _, zone in ipairs(ZONES.Heightmap) do
        if luminosity >= zone.min and luminosity <= zone.max then
            return zone
        end
    end
    return ZONES.Heightmap[#ZONES.Heightmap]
end

for i = 0, 255 do
    zoneLUT[i] = getZone(i)
end

function Heightmap.Process(imageData)
    local w = imageData:getWidth()
    local h = imageData:getHeight()
    local output = love.image.newImageData(w, h)
    
    local inputPixels = ffi.cast("uint8_t*", imageData:getFFIPointer())
    local outputPixels = ffi.cast("uint8_t*", output:getFFIPointer())
    
    local stats = {}
    for _, zone in ipairs(ZONES.Heightmap) do
        stats[zone.name] = { count = 0, zone = zone }
    end
    
    for i = 0, w * h - 1 do
        local base = i * 4
        local lum = inputPixels[base]
        local zone = zoneLUT[lum]
        
        outputPixels[base]     = zone.r
        outputPixels[base + 1] = zone.g
        outputPixels[base + 2] = zone.b
        outputPixels[base + 3] = 255
        
        stats[zone.name].count = stats[zone.name].count + 1
    end
    
    return output, stats
end

return Heightmap
