local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ArgParser = require("src.core.args")
local ZONES = require("src.config.zone")
local Camera = require("src.core.camera")
local Heightmap = require("src.modules.map.heightmap")


local flags
local totalPixels
local stats
local sourceMap
local colorMap
local camera

--- @param args string[]
function love.load(args)
    env:Load(".env")
    modules:Load("src/modules")
    
    local parser = ArgParser.new()
    parser:add_argument("heightmap", { short = "h", default = false, type = "boolean" })
    parser:add_argument("map", { default = "assets/maps/world/", type = "value" })
    flags = parser:parse(args)
    
    GM:InitializeModules()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.10)

    local imgData = love.image.newImageData(flags.map)
    totalPixels = imgData:getWidth() * imgData:getHeight()

    local t0 = love.timer.getTime()
    local outData
    outData, stats = Heightmap.Process(imgData)
    local elapsed = (love.timer.getTime() - t0) * 1000

    sourceMap = love.graphics.newImage(imgData)
    sourceMap:setFilter("nearest", "nearest")
    colorMap  = love.graphics.newImage(outData)
    colorMap:setFilter("nearest", "nearest")
    

    local W, H = love.graphics.getDimensions()
    local imgW, imgH = imgData:getWidth(), imgData:getHeight()
    local initialScale = math.max(W / imgW, H / imgH)
    
    camera = Camera()
    camera.mapW = imgW
    camera.mapH = imgH
    camera.scale = initialScale
    camera.x = (W - imgW * initialScale) / (2 * initialScale)
    camera.y = (H - imgH * initialScale) / (2 * initialScale)
    camera:clamp()

    if flags.heightmap then
        Logger:trace("Heightmap", string.format("\nTraitement : %.2f ms\n", elapsed))
        Logger:trace("Heightmap", string.format("%-20s  %-10s  %s", "Zone", "Pixels", "%"))
        Logger:trace("Heightmap", string.rep("-", 42))
        for _, zone in ipairs(ZONES.Heightmap) do
            local s = stats[zone.name]
            Logger:trace("Heightmap", string.format("%-20s  %-10d  %.1f%%", zone.name, s.count, s.count / totalPixels * 100))
        end
    end
end

--- @param dt number
function love.update(dt)
    GM:Think()

    if not flags.heightmap then
        camera:update(dt)
    end
end

--- @param x number
--- @param y number
function love.wheelmoved(x, y)
    if not flags or flags.heightmap then return end
    local mouseX, mouseY = love.mouse.getPosition()
    if y > 0 then
        camera:zoom(1.1, mouseX, mouseY)
    elseif y < 0 then
        camera:zoom(0.9, mouseX, mouseY)
    end
end

function love.draw()
    local W, H   = love.graphics.getDimensions()
    local PAD    = 16

    --- @param img love.Image
    --- @param x number
    --- @param y number
    --- @param maxW number
    --- @param maxH number
    --- @param label string?
    local function drawImage(img, x, y, maxW, maxH, label)
        local scale = math.min(maxW / img:getWidth(), maxH / img:getHeight())
        local dw, dh = img:getWidth() * scale, img:getHeight() * scale

        local drawX = x + (maxW - dw) / 2
        local drawY = y + (maxH - dh) / 2

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", x, y, maxW, maxH, 4)

        love.graphics.setScissor(x, y, maxW, maxH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, drawX, drawY, 0, scale, scale)
        love.graphics.setScissor()

        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", x, y, maxW, maxH, 4)
        
        if label then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.print(label, x, y - 18)
        end
    end

    if flags.heightmap then
        local IMG_W  = (W - PAD * 3) / 2
        local IMG_H  = H - 180

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
    else
        camera:apply()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(colorMap, 0, 0)
        
        GM:Draw()
        camera:clear()
    end
end