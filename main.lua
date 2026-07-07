local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ArgParser = require("src.core.args")
local ZONES = require("src.config.zone")
local Camera = require("src.core.camera")
local Heightmap = require("src.modules.map.heightmap")
local MapClass = require("src.modules.map.map")


local flags
local Map

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
    Map = MapClass(flags.map, 1)

    local W, H = love.graphics.getDimensions()
    local imgW, imgH = Map:getWidth(), Map:getHeight()
    local initialScale = math.max(W / imgW, H / imgH)
    
    camera = Camera()
    camera.mapW = imgW
    camera.mapH = imgH
    camera.scale = initialScale
    camera.x = (W - imgW * initialScale) / (2 * initialScale)
    camera.y = (H - imgH * initialScale) / (2 * initialScale)
    camera:clamp()

end

--- @param dt number
function love.update(dt)
    GM:Think()

    camera:update(dt)
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
    camera:apply()
    love.graphics.setColor(1, 1, 1)
    Map:draw(camera)
    GM:Draw()
    camera:clear()
end