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

function Camera:update()
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
    
    self:clamp()
end

function Camera:zoom(factor, mouseX, mouseY)
    if self.mapW and self.mapH then
        local W, H = love.graphics.getDimensions()
        self.minScale = math.max(W / self.mapW, H / self.mapH)
    end

    local oldScale = self.scale
    self.scale = math.max(self.minScale, math.min(self.maxScale, self.scale * factor))
    
    if mouseX and mouseY then
        local worldX = mouseX - self.x * oldScale
        local worldY = mouseY - self.y * oldScale
        
        self.x = (mouseX - worldX * (self.scale / oldScale)) / self.scale
        self.y = (mouseY - worldY * (self.scale / oldScale)) / self.scale
    end
    
    self:clamp()
end

function Camera:clamp()
    if not self.mapW or not self.mapH then return end
    
    local W, H = love.graphics.getDimensions()
    
    local minScale = math.max(W / self.mapW, H / self.mapH)
    self.minScale = minScale
    if self.scale < minScale then
        self.scale = minScale
    end
    
    local minX = W / self.scale - self.mapW
    local minY = H / self.scale - self.mapH
    
    self.x = math.max(minX, math.min(0, self.x))
    self.y = math.max(minY, math.min(0, self.y))
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
