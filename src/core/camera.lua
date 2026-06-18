local Class = require("src.core.class")

local Camera = Class()

function Camera:init()
    self.x = 0
    self.y = 0
    self.scale = 1
    self.isDragging = false
    self.lastMouseX = 0
    self.lastMouseY = 0

    self.minScale = 0.05
    self.maxScale = 10.0
end

function Camera:update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    
    if love.mouse.isDown(2) then
        if not self.isDragging then
            self.isDragging = true
            self.lastMouseX = mouseX
            self.lastMouseY = mouseY
        else
            local dx = mouseX - self.lastMouseX
            local dy = mouseY - self.lastMouseY
            
            self.x = self.x + dx / self.scale
            self.y = self.y + dy / self.scale
            
            self.lastMouseX = mouseX
            self.lastMouseY = mouseY
        end
    else
        self.isDragging = false
    end
end

function Camera:zoom(factor, mouseX, mouseY)
    local oldScale = self.scale
    self.scale = math.max(self.minScale, math.min(self.maxScale, self.scale * factor))
    
    if mouseX and mouseY then
        local worldX = mouseX - self.x * oldScale
        local worldY = mouseY - self.y * oldScale
        
        self.x = (mouseX - worldX * (self.scale / oldScale)) / self.scale
        self.y = (mouseY - worldY * (self.scale / oldScale)) / self.scale
    end
end

function Camera:apply()
    love.graphics.push()
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(self.x, self.y)
end

function Camera:clear()
    love.graphics.pop()
end

return Camera
