local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ArgParser = require("src.core.args")
local Camera = require("src.core.camera")
local Map = require("src.modules.map.map")
local Country = require("src.modules.country.country")

local json = require("libs.json.json")
local astar = require("src.modules.algorithms.astar")

local flags
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
    GM.Game = {Map = Map(flags.map, 1)}
    GM.Game.Map:RegisterCountry(Country(nil, nil, "France", "fr"), {x = 945, y = 233, radius = 40})
    GM.Game.Map:FillCountries(40)
    local W, H = love.graphics.getDimensions()
    local imgW, imgH = GM.Game.Map:getWidth(), GM.Game.Map:getHeight()
    local initialScale = math.max(W / imgW, H / imgH)
    
    camera = Camera()
    camera.mapW = imgW
    camera.mapH = imgH
    camera.scale = initialScale
    camera.x = (W - imgW * initialScale) / (2 * initialScale)
    camera.y = (H - imgH * initialScale) / (2 * initialScale)
    camera:clamp()
    
    GM.Camera = camera
    GM.Building:GenerateBuildings(GM.Game.Map)
    print(json.encode(astar(
            GM.Game.Map:getCellAtPixel(10, 201),
            GM.Game.Map:getCellAtPixel(201, 10),
            function(cell) return not cell.data.isOcean end,
            GM.Game.Map
        )))
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
    GM.Game.Map:draw(camera)
    if GM.Building and GM.Building.Draw then
        GM.Building:Draw()
    end
    camera:clear()

    for _, moduleName in pairs(GM.Modules.HasFunction.Draw) do
        if moduleName ~= "Building" and moduleName ~= "Map" then
            GM[moduleName]:Draw()
        end
    end
end

function love.keypressed(key, scancode, isrepeat)
    if GM.KeyPressed then
        GM:KeyPressed(key, scancode, isrepeat)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if GM.MousePressed then
        GM:MousePressed(x, y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if GM.MouseReleased then
        GM:MouseReleased(x, y, button, istouch, presses)
    end
end
