local Class = require("src.core.class")
local GM = require("src.core.index")
local Flags = require("src.modules.hud.flags")
local ContextMenu = require("src.modules.hud.contextmenu")

local Hud = Class()

--- @return Hud
function Hud:init()
    self.width = 200
    self.height = 145
    self.margin = 20
    self.hoveredLayerIdx = nil
    self.headerHeight = 26
    self.contextMenu = ContextMenu()
    self.powerAllocation = {
        expansion = 34,
        diplomacy = 33,
        army = 33
    }
    self.sliderDragging = nil
end

--- @param flagKey string
--- @param x number
--- @param y number
--- @param size number
--- @return void
function Hud:drawFlag(flagKey, x, y, size)
    if not flagKey or flagKey == "" then
        return
    end

    local flag = Flags:Get(flagKey)
    if not flag then
        return
    end

    local flagWidth = flag:getWidth()
    local flagHeight = flag:getHeight()
    if flagWidth <= 0 or flagHeight <= 0 then
        return
    end

    local scale = math.min(size / flagWidth, size / flagHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(flag, x, y, 0, scale, scale)
end

--- @return number, number, number, number
function Hud:getPanelRect()
    local W, H = love.graphics.getDimensions()
    local x = W - self.width - self.margin
    local y = self.margin
    return x, y, self.width, self.height
end

--- @return void
function Hud:Draw()
    local map = GM.Game and GM.Game.Map
    if not map then return end

    local px, py, pw, ph = self:getPanelRect()
    local mx, my = love.mouse.getPosition()

    love.graphics.push("all")

    -- 1. Layers Panel (Pixel style double-border and dropshadow)
    -- Dropshadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", px + 3, py + 3, pw, ph)

    -- Main background
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py, pw, ph)

    -- Outer border (2px black)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph)

    -- Inner border (1px blue)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 2, py + 2, pw - 4, ph - 4)

    -- Header block
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", px + 3, py + 3, pw - 6, self.headerHeight - 2)

    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(px + 3, py + self.headerHeight + 1, px + pw - 3, py + self.headerHeight + 1)

    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("ATHENA LAYERS", px + 10, py + 6)

    local layersList = {
        { name = "Base Map",  state = map.layers.terrain,   key = "1" },
        { name = "Countries", state = map.layers.political, key = "2" },
        { name = "Buildings", state = map.layers.buildings, key = "3" }
    }

    self.hoveredLayerIdx = nil

    for i, item in ipairs(layersList) do
        local itemY = py + self.headerHeight + 8 + (i - 1) * 26

        local isHovered = (mx >= px + 4 and mx <= px + pw - 4 and my >= itemY - 2 and my <= itemY + 20)
        if isHovered then
            self.hoveredLayerIdx = i
            -- Neon teal hover highlight
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
            love.graphics.rectangle("fill", px + 4, itemY - 2, pw - 8, 22)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", px + 4, itemY - 2, pw - 8, 22)
        end

        local cbSize = 10
        local cbX = px + 14
        local cbY = itemY + 4

        if item.state then
            love.graphics.setColor(0.1, 0.75, 0.55, 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cbX, cbY, cbSize, cbSize)

        if item.state then
            love.graphics.setColor(0.1, 0.75, 0.55, 0.4)
            love.graphics.rectangle("fill", cbX + 2, cbY + 2, cbSize - 4, cbSize - 4)
        end

        if isHovered then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.95, 1)
        end
        love.graphics.print(item.name, cbX + 18, cbY - 3)

        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        love.graphics.print("[" .. item.key .. "]", px + pw - 28, cbY - 3)
    end

    -- 2. Cell Info Panel (Bottom-Left)
    local worldX, worldY = GM.Building:GetWorldMouse()
    local cellX = math.floor(worldX + 1)
    local cellY = math.floor(worldY + 1)

    local W, H = love.graphics.getDimensions()

    if map:isValidCell(cellX, cellY) then
        local cell = map.grid[cellX][cellY]
        local infoText = string.format("Grid X:%d Y:%d", cellX, cellY)
        local territoryOwner = cell:getOwner()
        local hasTerritoryFlag = territoryOwner and map.layers.political and territoryOwner.flag and
            territoryOwner.flag ~= ""
        if cell:getOwner() and map.layers.political then
            infoText = infoText .. " | Territory: " .. cell:getOwner().name
        end

        local sh = H - 35
        local panelWidth = hasTerritoryFlag and 350 or 320

        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", 15 + 3, sh + 3, panelWidth, 24)
        love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", 15, sh, panelWidth, 24)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 15, sh, panelWidth, 24)
        love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 17, sh + 2, panelWidth - 4, 20)

        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.print(infoText, 25, sh + 5)

        if hasTerritoryFlag then
            self:drawFlag(territoryOwner.flag, 15 + panelWidth - 22, sh + 4, 16)
        end
    end

    if map.layers.buildings then
        local hoveredBuilding = nil
        for _, b in ipairs(GM.Building.List) do
            if b.hoverProgress > 0.7 then
                hoveredBuilding = b
                break
            end
        end

        if hoveredBuilding then
            local tWidth = 180
            local tHeight = 75
            local tx = mx + 15
            local ty = my + 15

            if tx + tWidth > W then tx = mx - tWidth - 15 end
            if ty + tHeight > H then ty = my - tHeight - 15 end

            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.rectangle("fill", tx + 3, ty + 3, tWidth, tHeight)
            love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
            love.graphics.rectangle("fill", tx, ty, tWidth, tHeight)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", tx, ty, tWidth, tHeight)
            love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tx + 2, ty + 2, tWidth - 4, tHeight - 4)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(hoveredBuilding.name, tx + 12, ty + 10)

            local badgeText = hoveredBuilding.type:gsub("^%l", string.upper)
            local br, bg, bb = 0.5, 0.5, 0.5
            if hoveredBuilding.type == "capital" or hoveredBuilding.type == "city" then
                br, bg, bb = 1, 0.8, 0.1
            elseif hoveredBuilding.type == "fort" then
                br, bg, bb = 0.8, 0.3, 0.3
            elseif hoveredBuilding.type == "port" then
                br, bg, bb = 0.2, 0.6, 1
            end

            love.graphics.setColor(br, bg, bb, 0.15)
            love.graphics.rectangle("fill", tx + 12, ty + 28, 55, 14)
            love.graphics.setColor(br, bg, bb, 0.8)
            love.graphics.rectangle("line", tx + 12, ty + 28, 55, 14)

            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(badgeText, tx + 17, ty + 28)

            if hoveredBuilding.cell and hoveredBuilding.cell:getOwner() then
                local oColor = hoveredBuilding.cell:getOwner().color
                love.graphics.setColor(oColor[1] / 255, oColor[2] / 255, oColor[3] / 255, 1)
                love.graphics.print(hoveredBuilding.cell:getOwner().name, tx + 12, ty + 48)
                self:drawFlag(hoveredBuilding.cell:getOwner().flag, tx + tWidth - 32, ty + 8, 20)
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.print("No Owner", tx + 12, ty + 48)
            end
        end
    end

    local py2 = py + ph + self.margin
    local ph2 = 170
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", px + 3, py2 + 3, pw, ph2)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py2, pw, ph2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py2, pw, ph2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 2, py2 + 2, pw - 4, ph2 - 4)
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", px + 3, py2 + 3, pw - 6, self.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(px + 3, py2 + self.headerHeight + 1, px + pw - 3, py2 + self.headerHeight + 1)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("POWER ALLOCATION", px + 10, py2 + 6)
    local sliders = {
        { name = "expansion", label = "Expansion", color = {0.9, 0.5, 0.1}, val = self.powerAllocation.expansion, y = py2 + 52 },
        { name = "diplomacy", label = "Diplomacy", color = {0.1, 0.6, 0.9}, val = self.powerAllocation.diplomacy, y = py2 + 97 },
        { name = "army", label = "Army", color = {0.9, 0.25, 0.25}, val = self.powerAllocation.army, y = py2 + 142 }
    }
    local mx, my = love.mouse.getPosition()
    for _, s in ipairs(sliders) do
        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.print(s.label, px + 15, s.y - 17)
        local valStr = s.val .. "%"
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 1)
        love.graphics.print(valStr, px + pw - 15 - love.graphics.getFont():getWidth(valStr), s.y - 17)
        love.graphics.setColor(0.05, 0.06, 0.09, 1)
        love.graphics.rectangle("fill", px + 15, s.y - 2, pw - 30, 4)
        love.graphics.setColor(0.15, 0.2, 0.3, 1)
        love.graphics.rectangle("line", px + 15, s.y - 2, pw - 30, 4)
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.8)
        love.graphics.rectangle("fill", px + 15, s.y - 2, (s.val / 100) * (pw - 30), 4)
        local hx = px + 15 + (s.val / 100) * (pw - 30)
        local hw, hh = 8, 12
        local isHovered = mx >= px + 15 - 6 and mx <= px + pw - 15 + 6 and my >= s.y - 8 and my <= s.y + 8
        if isHovered or self.sliderDragging == s.name then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
            love.graphics.setColor(s.color[1], s.color[2], s.color[3], 1)
            love.graphics.rectangle("line", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
        else
            love.graphics.setColor(0.8, 0.8, 0.85, 1)
            love.graphics.rectangle("fill", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
            love.graphics.setColor(0.4, 0.5, 0.6, 1)
            love.graphics.rectangle("line", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
        end
    end

    if self.contextMenu then
        self.contextMenu:update()
        self.contextMenu:draw()
    end

    love.graphics.pop()
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function Hud:MousePressed(x, y, button, istouch, presses)
    if self.contextMenu then
        local wasVisible = self.contextMenu.visible
        self.contextMenu:MousePressed(x, y, button, istouch, presses)
        if wasVisible then
            return
        end
    end

    if button ~= 1 then return end

    local px, py, pw, ph = self:getPanelRect()
    local py2 = py + ph + self.margin
    local mx, my = love.mouse.getPosition()
    local sliderX = px + 15
    local sliderWidth = pw - 30
    local sliders = {
        { name = "expansion", y = py2 + 52 },
        { name = "diplomacy", y = py2 + 97 },
        { name = "army", y = py2 + 142 }
    }
    for _, s in ipairs(sliders) do
        if mx >= sliderX - 6 and mx <= sliderX + sliderWidth + 6 and my >= s.y - 8 and my <= s.y + 8 then
            self.sliderDragging = s.name
            local pct = math.max(0, math.min(100, math.floor(((mx - sliderX) / sliderWidth) * 100 + 0.5)))
            self:adjustSliders(s.name, pct)
            return
        end
    end

    local map = GM.Game and GM.Game.Map
    if not map then return end

    if mx >= px and mx <= px + pw and my >= py and my <= py + ph then
        if self.hoveredLayerIdx then
            local layersList = { "terrain", "political", "buildings" }
            local layerKey = layersList[self.hoveredLayerIdx]
            if layerKey then
                map:toggleLayer(layerKey)
            end
        end
    end
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function Hud:MouseReleased(x, y, button, istouch, presses)
    if self.contextMenu then
        self.contextMenu:MouseReleased(x, y, button, istouch, presses)
    end
    if button == 1 then
        self.sliderDragging = nil
    end
end

--- @param key string
--- @param scancode string?
--- @param isrepeat boolean?
--- @return void
function Hud:KeyPressed(key, scancode, isrepeat)
    local map = GM.Game and GM.Game.Map
    if not map then return end

    if key == "1" then
        map:toggleLayer("terrain")
    elseif key == "2" then
        map:toggleLayer("political")
    elseif key == "3" then
        map:toggleLayer("buildings")
    end
end

function Hud:adjustSliders(changedKey, newValue)
    newValue = math.max(0, math.min(100, newValue))
    local keys = {"expansion", "diplomacy", "army"}
    local otherKeys = {}
    for _, k in ipairs(keys) do
        if k ~= changedKey then
            table.insert(otherKeys, k)
        end
    end
    local otherSum = 0
    for _, k in ipairs(otherKeys) do
        otherSum = otherSum + self.powerAllocation[k]
    end
    self.powerAllocation[changedKey] = newValue
    local remaining = 100 - newValue
    if otherSum > 0 then
        local val1 = math.floor((self.powerAllocation[otherKeys[1]] / otherSum) * remaining + 0.5)
        local val2 = remaining - val1
        self.powerAllocation[otherKeys[1]] = val1
        self.powerAllocation[otherKeys[2]] = val2
    else
        local val1 = math.floor(remaining / 2)
        local val2 = remaining - val1
        self.powerAllocation[otherKeys[1]] = val1
        self.powerAllocation[otherKeys[2]] = val2
    end
end

function Hud:Think(dt)
    if self.sliderDragging then
        if not love.mouse.isDown(1) then
            self.sliderDragging = nil
            return
        end
        local mx, my = love.mouse.getPosition()
        local px, py, pw, ph = self:getPanelRect()
        local sliderX = px + 15
        local sliderWidth = pw - 30
        local pct = math.max(0, math.min(100, math.floor(((mx - sliderX) / sliderWidth) * 100 + 0.5)))
        self:adjustSliders(self.sliderDragging, pct)
    end
end

return Hud
