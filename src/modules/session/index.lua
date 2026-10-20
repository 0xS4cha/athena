local GM = require("src.core.index")
local Camera = require("src.core.camera")
local Game = require("src.modules.game.game")
local Interaction = require("src.modules.game.interaction")

GM.Session = {}
GM.State = "menu"

GM.Modules:Register("Session", 40)

function GM.Session:Initialize()
    self.Game = nil
    self.Camera = nil
end

function GM.Session:Start(options)
    self:Stop()
    local game = Game(options)
    local map = game.map
    local W, H = love.graphics.getDimensions()
    local camera = Camera()
    camera.mapW = map.width
    camera.mapH = map.height
    camera.scale = math.max(W / map.width, H / map.height)
    camera.x = (W - map.width * camera.scale) / (2 * camera.scale)
    camera.y = (H - map.height * camera.scale) / (2 * camera.scale)
    camera:clamp()

    self.Game = game
    self.Camera = camera
    GM.Camera = camera
    GM.State = "game"
    return game
end

function GM.Session:Stop()
    self.Game = nil
    self.Camera = nil
    GM.Camera = nil
    GM.State = "menu"
    collectgarbage()
end

function GM.Session:Think(dt)
    if not self.Game then return end
    self.Camera:update(dt)
    self.Game:update(dt)
end

function GM.Session:Draw()
    if not self.Game then return end
    self.Camera:apply()
    self.Game.renderer:draw()
    self.Camera:clear()
end

function GM.Session:WheelMoved(_, y)
    if not self.Camera then return end
    local mx, my = love.mouse.getPosition()
    if GM.Hud and GM.Hud:Captures(mx, my) then return end
    if y > 0 then
        self.Camera:zoom(1.1, mx, my)
    elseif y < 0 then
        self.Camera:zoom(0.9, mx, my)
    end
end

function GM.Session:KeyPressed(key)
    local game = self.Game
    if not game then return end
    if key == "p" then
        game.paused = not game.paused
    elseif key == "=" or key == "kp+" then
        game:changeSpeed(1)
    elseif key == "-" or key == "kp-" then
        game:changeSpeed(-1)
    end
end

function GM.Session:MousePressed(x, y, button)
    if not self.Game or button ~= 1 then return end
    if GM.Hud and GM.Hud:Captures(x, y) then return end
    local wx, wy = self.Camera:toWorld(x, y)
    local tile = self.Game.map:tileAt(wx, wy)
    if tile then
        Interaction.click(self.Game, tile)
    end
end

function GM.Session:WorldMouse()
    if not self.Camera then return 0, 0 end
    local mx, my = love.mouse.getPosition()
    return self.Camera:toWorld(mx, my)
end

function GM.Session:HoveredTile()
    if not self.Game then return nil end
    local wx, wy = self:WorldMouse()
    return self.Game.map:tileAt(wx, wy)
end

return GM.Session
