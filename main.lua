local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ffi = require("ffi")
local ZONES = require("src.config.zone")

local function getZone(luminosity)
    for _, zone in ipairs(ZONES.Heightmap) do
        if luminosity >= zone.min and luminosity <= zone.max then
            return zone
        end
    end
    return ZONES.Heightmap[#ZONES.Heightmap]
end


local function processHeightmap(imageData)
    local pixels  = ffi.cast("uint8_t*", imageData:getFFIPointer())
    local w       = imageData:getWidth()
    local h       = imageData:getHeight()
    local output  = love.image.newImageData(w, h)
    local stats   = {}

    for _, zone in ipairs(ZONES.Heightmap) do
        stats[zone.name] = { count = 0, zone = zone }
    end

    for i = 0, w * h - 1 do
        local base = i * 4

        local lum  = pixels[base]
        local zone = getZone(lum)

        output:setPixel(
            i % w, math.floor(i / w),
            zone.r / 255,
            zone.g / 255,
            zone.b / 255,
            1
        )

        stats[zone.name].count = stats[zone.name].count + 1
    end

    return output, stats
end

    

function love.load()
    env:Load(".env")
    modules:Load("src/modules")
    GM:InitializeModules()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.10)

    local imgData  = love.image.newImageData("assets/maps/world/image.png")
    totalPixels    = imgData:getWidth() * imgData:getHeight()

    local t0       = love.timer.getTime()
    local outData  = {}
    outData, stats = processHeightmap(imgData)
    local elapsed  = (love.timer.getTime() - t0) * 1000

    sourceMap = love.graphics.newImage(imgData)
    colorMap  = love.graphics.newImage(outData)

    Logger:trace("Heightmap", string.format("\nTraitement : %.2f ms\n", elapsed))
    Logger:trace("Heightmap", string.format("%-20s  %-10s  %s", "Zone", "Pixels", "%"))
    Logger:trace("Heightmap", string.rep("-", 42))
    for _, zone in ipairs(ZONES.Heightmap) do
        local s = stats[zone.name]
        Logger:trace("Heightmap", string.format("%-20s  %-10d  %.1f%%", zone.name, s.count, s.count / totalPixels * 100))
    end
end


function love.update(dt)
    GM:Think()
end


function love.draw()
    local W, H   = love.graphics.getDimensions()
    local PAD    = 16
    local IMG_W  = (W - PAD * 3) / 2
    local IMG_H  = H - 180

    local function drawImage(img, x, y, maxW, maxH, label)
        local scale = math.min(maxW / img:getWidth(), maxH / img:getHeight())
        local dw, dh = img:getWidth() * scale, img:getHeight() * scale

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", x, y, maxW, maxH, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, x + (maxW - dw) / 2, y + (maxH - dh) / 2, 0, scale, scale)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", x, y, maxW, maxH, 4)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.print(label, x, y - 18)
    end

    drawImage(sourceMap, PAD,           PAD + 18, IMG_W, IMG_H, "Heightmap source")
    drawImage(colorMap,  PAD * 2 + IMG_W, PAD + 18, IMG_W, IMG_H, "Colored Map")

    local ly    = IMG_H + PAD * 2 + 24
    local swSize = 16
    local colW  = W / #ZONES.Heightmap

    for i, zone in ipairs(ZONES.Heightmap) do
        local x = (i - 1) * colW + PAD
        love.graphics.setColor(zone.r / 255, zone.g / 255, zone.b / 255)
        love.graphics.rectangle("fill", x, ly, swSize, swSize, 3)
        love.graphics.setColor(0.75, 0.75, 0.85)
        love.graphics.print(
            string.format("%s\n%.1f%%", zone.name,
                stats[zone.name].count / totalPixels * 100),
            x + swSize + 4, ly
        )
    end
end