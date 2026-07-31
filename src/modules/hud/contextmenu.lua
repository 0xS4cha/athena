local Class = require("src.core.class")
local GM = require("src.core.index")

local ContextMenu = Class()

function ContextMenu:init()
    self.visible = false
    self.x = 0
    self.y = 0
    self.cellX = 0
    self.cellY = 0
    self.items = {}
    self.icons = {}
    self.hoveredIdx = nil
    self.width = 190
    self.height = 100
    self.itemHeight = 28
    self.headerHeight = 26
    self.pressedX = 0
    self.pressedY = 0
    self.isRightPressed = false
end

function ContextMenu:getIcon(name)
    if not self.icons[name] then
        local success, img = pcall(love.graphics.newImage, "assets/Icons/" .. name)
        if success then
            img:setFilter("nearest", "nearest")
            self.icons[name] = img
        else
            self.icons[name] = false
        end
    end
    return self.icons[name]
end

function ContextMenu:open(mx, my, cellX, cellY)
    local map = GM.Game and GM.Game.Map
    if not map or not map:isValidCell(cellX, cellY) then return end
    
    self.cellX = cellX
    self.cellY = cellY
    self.x = mx
    self.y = my
    self.visible = true
    
    local cell = map.grid[cellX][cellY]
    local terrain = cell.data
    local owner = cell:getOwner()
    
    local existingBuilding = nil
    if GM.Building and GM.Building.List then
        for _, b in ipairs(GM.Building.List) do
            if b.x == cellX and b.y == cellY then
                existingBuilding = b
                break
            end
        end
    end
    
    self.items = {}
    
    if GM.PlayerCountry then
        table.insert(self.items, {
            label = "Claim Cell",
            icon = "Trophy.png",
            action = function()
                GM.PlayerCountry:claimCell(cellX, cellY)
            end
        })
    end
    
    if owner then
        table.insert(self.items, {
            label = "Clear Influence",
            icon = "Unlocked.png",
            action = function()
                map:clearInfluence(cellX, cellY)
            end
        })
    end
    
    if not existingBuilding then
        if terrain.isLand then
            table.insert(self.items, {
                label = "Build Capital",
                icon = "Home.png",
                action = function()
                    GM.Building:SpawnBuilding(cellX, cellY, "city", "Capital", cell)
                end
            })
            table.insert(self.items, {
                label = "Build Village",
                icon = "Hammer.png",
                action = function()
                    GM.Building:SpawnBuilding(cellX, cellY, "village", "Village", cell)
                end
            })
            table.insert(self.items, {
                label = "Build Fort",
                icon = "Wrench.png",
                action = function()
                    GM.Building:SpawnBuilding(cellX, cellY, "fort", "Fort", cell)
                end
            })
        else
            table.insert(self.items, {
                label = "Build Port",
                icon = "CatchingNet.png",
                action = function()
                    GM.Building:SpawnBuilding(cellX, cellY, "port", "Port", cell)
                end
            })
        end
    else
        table.insert(self.items, {
            label = "Destroy Building",
            icon = "Trashbin.png",
            action = function()
                if GM.Building and GM.Building.DestroyBuildingAt then
                    GM.Building:DestroyBuildingAt(cellX, cellY)
                end
            end
        })
    end
    
    table.insert(self.items, {
        label = "Close Menu",
        icon = "Exit.png",
        action = function()
            self.visible = false
        end
    })
    
    self.width = 195
    self.height = self.headerHeight + (#self.items * self.itemHeight) + 8
    
    local winW, winH = love.graphics.getDimensions()
    if self.x + self.width > winW then
        self.x = winW - self.width - 10
    end
    if self.y + self.height > winH then
        self.y = winH - self.height - 10
    end
    
    self.hoveredIdx = nil
end

function ContextMenu:update(dt)
    if not self.visible then return end
    
    local mx, my = love.mouse.getPosition()
    self.hoveredIdx = nil
    
    if mx >= self.x and mx <= self.x + self.width and
       my >= self.y and my <= self.y + self.height then
        
        local localY = my - (self.y + self.headerHeight + 4)
        if localY >= 0 then
            local idx = math.floor(localY / self.itemHeight) + 1
            if idx >= 1 and idx <= #self.items then
                self.hoveredIdx = idx
            end
        end
    end
end

function ContextMenu:draw()
    if not self.visible or #self.items == 0 then return end
    
    love.graphics.push("all")
    
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", self.x + 3, self.y + 3, self.width, self.height)
    
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 2, self.y + 2, self.width - 4, self.height - 4)
    
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", self.x + 3, self.y + 3, self.width - 6, self.headerHeight - 2)
    
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(self.x + 3, self.y + self.headerHeight + 1, self.x + self.width - 3, self.y + self.headerHeight + 1)
    
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print(string.format("TILE [%d, %d]", self.cellX, self.cellY), self.x + 10, self.y + 6)
    
    local startY = self.y + self.headerHeight + 4
    for i, item in ipairs(self.items) do
        local itemY = startY + (i - 1) * self.itemHeight
        
        if self.hoveredIdx == i then
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
            love.graphics.rectangle("fill", self.x + 4, itemY, self.width - 8, self.itemHeight)
            
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", self.x + 4, itemY, self.width - 8, self.itemHeight)
        end
        
        local icon = self:getIcon(item.icon)
        if icon then
            love.graphics.setColor(1, 1, 1, 1)
            local iconY = itemY + (self.itemHeight - icon:getHeight()) / 2
            love.graphics.draw(icon, self.x + 10, math.floor(iconY))
        end
        
        if self.hoveredIdx == i then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.85, 1)
        end
        love.graphics.print(item.label, self.x + 32, itemY + 7)
    end
    
    love.graphics.pop()
end

function ContextMenu:MousePressed(x, y, button, istouch, presses)
    if button == 2 then
        self.isRightPressed = true
        self.pressedX = x
        self.pressedY = y
    end
    
    if not self.visible then return end
    
    if button == 1 then
        if self.hoveredIdx and self.items[self.hoveredIdx] then
            local act = self.items[self.hoveredIdx].action
            self.visible = false
            if act then act() end
        else
            self.visible = false
        end
    elseif button == 2 then
        if x < self.x or x > self.x + self.width or y < self.y or y > self.y + self.height then
            self.visible = false
        end
    end
end

function ContextMenu:MouseReleased(x, y, button, istouch, presses)
    if button == 2 then
        self.isRightPressed = false
        
        local dx = x - self.pressedX
        local dy = y - self.pressedY
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < 6 then
            if GM.Building and GM.Building.GetWorldMouse then
                local worldX, worldY = GM.Building:GetWorldMouse()
                local cellX = math.floor(worldX + 1)
                local cellY = math.floor(worldY + 1)
                self:open(x, y, cellX, cellY)
            end
        end
    end
end

return ContextMenu
