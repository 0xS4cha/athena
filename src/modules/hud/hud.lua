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
    self.layersX = nil
    self.layersY = nil
    self.powerX = nil
    self.powerY = nil
    self.militaryX = nil
    self.militaryY = nil
    self.settingsOpen = false
    self.settingSliderDragging = nil
    self.draggingPanel = nil
    self.gearRotation = 0
    self.gearImage = love.graphics.newImage("assets/Icons/Gear.png")
    self:loadConfig()
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
    return self:getLayersRect()
end

--- @return void
function Hud:Draw()
    local map = GM.Game and GM.Game.Map
    if not map then return end

    local W, H = love.graphics.getDimensions()
    local lx, ly, lw, lh = self:getLayersRect()
    local px, py, pw, ph = lx, ly, lw, lh
    local px2, py2, pw2, ph2 = self:getPowerRect()
    local mx, my = love.mouse.getPosition()

    love.graphics.push("all")

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", px + 3, py + 3, pw, ph)

    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py, pw, ph)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph)

    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 2, py + 2, pw - 4, ph - 4)

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

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", px2 + 3, py2 + 3, pw2, ph2)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", px2, py2, pw2, ph2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px2, py2, pw2, ph2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px2 + 2, py2 + 2, pw2 - 4, ph2 - 4)
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", px2 + 3, py2 + 3, pw2 - 6, self.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(px2 + 3, py2 + self.headerHeight + 1, px2 + pw2 - 3, py2 + self.headerHeight + 1)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("POWER ALLOCATION", px2 + 10, py2 + 6)
    local sliders = {
        { name = "expansion", label = "Expansion", color = { 0.9, 0.5, 0.1 },   val = self.powerAllocation.expansion, y = py2 + 52 },
        { name = "diplomacy", label = "Diplomacy", color = { 0.1, 0.6, 0.9 },   val = self.powerAllocation.diplomacy, y = py2 + 97 },
        { name = "army",      label = "Army",      color = { 0.9, 0.25, 0.25 }, val = self.powerAllocation.army,      y = py2 + 142 }
    }
    local mx, my = love.mouse.getPosition()
    for _, s in ipairs(sliders) do
        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.print(s.label, px2 + 15, s.y - 17)
        local valStr = s.val .. "%"
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 1)
        love.graphics.print(valStr, px2 + pw2 - 15 - love.graphics.getFont():getWidth(valStr), s.y - 17)
        love.graphics.setColor(0.05, 0.06, 0.09, 1)
        love.graphics.rectangle("fill", px2 + 15, s.y - 2, pw2 - 30, 4)
        love.graphics.setColor(0.15, 0.2, 0.3, 1)
        love.graphics.rectangle("line", px2 + 15, s.y - 2, pw2 - 30, 4)
        love.graphics.setColor(s.color[1], s.color[2], s.color[3], 0.8)
        love.graphics.rectangle("fill", px2 + 15, s.y - 2, (s.val / 100) * (pw2 - 30), 4)
        local hx = px2 + 15 + (s.val / 100) * (pw2 - 30)
        local hw, hh = 8, 12
        local isHovered = mx >= px2 + 15 - 6 and mx <= px2 + pw2 - 15 + 6 and my >= s.y - 8 and my <= s.y + 8
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

    love.graphics.push("all")
    local cx, cy = 32, 32
    local gearHovered = mx >= 16 and mx <= 48 and my >= 16 and my <= 48
    if gearHovered then
        love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
        love.graphics.circle("fill", cx, cy, 16)
        love.graphics.setColor(0.2, 0.45, 0.8, 1)
        love.graphics.circle("line", cx, cy, 16)
    else
        love.graphics.setColor(0.06, 0.08, 0.12, 0.85)
        love.graphics.circle("fill", cx, cy, 16)
        love.graphics.setColor(0.2, 0.45, 0.8, 0.4)
        love.graphics.circle("line", cx, cy, 16)
    end
    if self.gearImage then
        local imgW = self.gearImage:getWidth()
        local imgH = self.gearImage:getHeight()
        local scaleX = 24 / imgW
        local scaleY = 24 / imgH
        local rot = self.gearRotation or 0
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.gearImage, cx, cy, rot, scaleX, scaleY, imgW / 2, imgH / 2)
    end
    love.graphics.pop()

    local mx3, my3, mw3, mh3 = self:getMilitaryRect()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", mx3 + 3, my3 + 3, mw3, mh3)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", mx3, my3, mw3, mh3)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mx3, my3, mw3, mh3)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", mx3 + 2, my3 + 2, mw3 - 4, mh3 - 4)
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", mx3 + 3, my3 + 3, mw3 - 6, self.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(mx3 + 3, my3 + self.headerHeight + 1, mx3 + mw3 - 3, my3 + self.headerHeight + 1)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("MILITARY OPERATIONS", mx3 + 10, my3 + 6)

    local citizensCount = GM.Battalions and GM.Battalions.citizens or 0
    local soldiersCount = GM.Battalions and GM.Battalions.soldiers or 0
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("Citizens: " .. math.floor(citizensCount), mx3 + 15, my3 + 40)
    love.graphics.print("Soldiers: " .. math.floor(soldiersCount), mx3 + 15, my3 + 60)

    local isSelected = false
    local hasPotential = false
    if GM.Battalions and GM.Battalions.List then
        for _, b in ipairs(GM.Battalions.List) do
            if b.selected then
                isSelected = true
                if b.potentialTarget then
                    hasPotential = true
                end
                break
            end
        end
    end

    local btn1X = mx3 + 15
    local btn1Y = my3 + 90
    local btn1W = mw3 - 30
    local btn1H = 24
    local btn1Hover = mx >= btn1X and mx <= btn1X + btn1W and my >= btn1Y and my <= btn1Y + btn1H
    if btn1Hover then
        love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
    else
        love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    end
    love.graphics.rectangle("fill", btn1X, btn1Y, btn1W, btn1H)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.rectangle("line", btn1X, btn1Y, btn1W, btn1H)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    local btn1Text = "CREATE BATTALION (10 S)"
    love.graphics.print(btn1Text, btn1X + (btn1W - love.graphics.getFont():getWidth(btn1Text)) / 2, btn1Y + 5)

    local btn2X = mx3 + 15
    local btn2Y = my3 + 120
    local btn2W = mw3 - 30
    local btn2H = 24
    local btn2Hover = mx >= btn2X and mx <= btn2X + btn2W and my >= btn2Y and my <= btn2Y + btn2H
    if isSelected then
        if btn2Hover then
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
        else
            love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
        end
    else
        love.graphics.setColor(0.05, 0.05, 0.05, 0.5)
    end
    love.graphics.rectangle("fill", btn2X, btn2Y, btn2W, btn2H)
    love.graphics.setColor(0.2, 0.45, 0.8, isSelected and 0.6 or 0.2)
    love.graphics.rectangle("line", btn2X, btn2Y, btn2W, btn2H)
    love.graphics.setColor(isSelected and 0.9 or 0.4, isSelected and 0.9 or 0.4, isSelected and 0.95 or 0.4, 1)
    local btn2Text = "SPLIT BATTALION"
    love.graphics.print(btn2Text, btn2X + (btn2W - love.graphics.getFont():getWidth(btn2Text)) / 2, btn2Y + 5)

    local btn3X = mx3 + 15
    local btn3Y = my3 + 150
    local btn3W = mw3 - 30
    local btn3H = 24
    local btn3Hover = mx >= btn3X and mx <= btn3X + btn3W and my >= btn3Y and my <= btn3Y + btn3H
    if isSelected and hasPotential then
        if btn3Hover then
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
        else
            love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
        end
    else
        love.graphics.setColor(0.05, 0.05, 0.05, 0.5)
    end
    love.graphics.rectangle("fill", btn3X, btn3Y, btn3W, btn3H)
    love.graphics.setColor(0.2, 0.45, 0.8, (isSelected and hasPotential) and 0.6 or 0.2)
    love.graphics.rectangle("line", btn3X, btn3Y, btn3W, btn3H)
    love.graphics.setColor((isSelected and hasPotential) and 0.9 or 0.4, (isSelected and hasPotential) and 0.9 or 0.4, (isSelected and hasPotential) and 0.95 or 0.4, 1)
    local btn3Text = "LAUNCH MOVEMENT"
    love.graphics.print(btn3Text, btn3X + (btn3W - love.graphics.getFont():getWidth(btn3Text)) / 2, btn3Y + 5)

    if self.settingsOpen then
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", sx + 3, sy + 3, sw, sh)
        love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, sw, sh)
        love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", sx + 2, sy + 2, sw - 4, sh - 4)
        love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
        love.graphics.rectangle("fill", sx + 3, sy + 3, sw - 6, self.headerHeight - 2)
        love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
        love.graphics.line(sx + 3, sy + self.headerHeight + 1, sx + sw - 3, sy + self.headerHeight + 1)
        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.print("SETTINGS", sx + 10, sy + 6)
        love.graphics.setColor(0.6, 0.7, 0.8, 1)
        love.graphics.print("Drag panel headers to move them", sx + 15, sy + 35)
        local settingsSliders = {
            { name = "layersX", label = "Layers Panel X", minVal = 0, maxVal = W - lw, currentVal = lx, y = sy + 80 },
            { name = "layersY", label = "Layers Panel Y", minVal = 0, maxVal = H - lh, currentVal = ly, y = sy + 120 },
            { name = "powerX", label = "Power Panel X", minVal = 0, maxVal = W - pw2, currentVal = px2, y = sy + 160 },
            { name = "powerY", label = "Power Panel Y", minVal = 0, maxVal = H - ph2, currentVal = py2, y = sy + 200 },
            { name = "militaryX", label = "Military Panel X", minVal = 0, maxVal = W - mw3, currentVal = mx3, y = sy + 240 },
            { name = "militaryY", label = "Military Panel Y", minVal = 0, maxVal = H - mh3, currentVal = my3, y = sy + 280 }
        }
        for _, s in ipairs(settingsSliders) do
            love.graphics.setColor(0.9, 0.9, 0.95, 1)
            love.graphics.print(s.label, sx + 15, s.y - 17)
            local valStr = tostring(math.floor(s.currentVal))
            love.graphics.setColor(0.2, 0.6, 0.9, 1)
            love.graphics.print(valStr, sx + sw - 15 - love.graphics.getFont():getWidth(valStr), s.y - 17)
            love.graphics.setColor(0.05, 0.06, 0.09, 1)
            love.graphics.rectangle("fill", sx + 15, s.y - 2, sw - 30, 4)
            love.graphics.setColor(0.15, 0.2, 0.3, 1)
            love.graphics.rectangle("line", sx + 15, s.y - 2, sw - 30, 4)
            local pct = (s.currentVal - s.minVal) / (s.maxVal - s.minVal)
            love.graphics.setColor(0.2, 0.6, 0.9, 0.8)
            love.graphics.rectangle("fill", sx + 15, s.y - 2, pct * (sw - 30), 4)
            local hx = sx + 15 + pct * (sw - 30)
            local hw, hh = 8, 12
            local isHovered = mx >= sx + 15 - 6 and mx <= sx + sw - 15 + 6 and my >= s.y - 8 and my <= s.y + 8
            if isHovered or self.settingSliderDragging == s.name then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
                love.graphics.setColor(0.2, 0.6, 0.9, 1)
                love.graphics.rectangle("line", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
            else
                love.graphics.setColor(0.8, 0.8, 0.85, 1)
                love.graphics.rectangle("fill", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
                love.graphics.setColor(0.4, 0.5, 0.6, 1)
                love.graphics.rectangle("line", hx - hw / 2, s.y - hh / 2, hw, hh, 2, 2)
            end
        end
        local btnX = sx + 15
        local btnY = sy + 320
        local btnW = sw - 30
        local btnH = 35
        local btnHovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        if btnHovered then
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
        else
            love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
            love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
        end
        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        local btnText = "RESET POSITIONS"
        love.graphics.print(btnText, btnX + (btnW - love.graphics.getFont():getWidth(btnText)) / 2, btnY + 10)
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

    local mx, my = love.mouse.getPosition()

    if mx >= 16 and mx <= 48 and my >= 16 and my <= 48 then
        self.settingsOpen = not self.settingsOpen
        return
    end

    local W, H = love.graphics.getDimensions()
    local lx, ly, lw, lh = self:getLayersRect()
    local px2, py2, pw2, ph2 = self:getPowerRect()

    local mx3, my3, mw3, mh3 = self:getMilitaryRect()

    if self.settingsOpen then
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        local btnX = sx + 15
        local btnY = sy + 320
        local btnW = sw - 30
        local btnH = 35
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            self.layersX = nil
            self.layersY = nil
            self.powerX = nil
            self.powerY = nil
            self.militaryX = nil
            self.militaryY = nil
            self:saveConfig()
            return
        end
        local settingsSliders = {
            { name = "layersX", minVal = 0, maxVal = W - lw,  y = sy + 80 },
            { name = "layersY", minVal = 0, maxVal = H - lh,  y = sy + 120 },
            { name = "powerX",  minVal = 0, maxVal = W - pw2, y = sy + 160 },
            { name = "powerY",  minVal = 0, maxVal = H - ph2, y = sy + 200 },
            { name = "militaryX", minVal = 0, maxVal = W - mw3, y = sy + 240 },
            { name = "militaryY", minVal = 0, maxVal = H - mh3, y = sy + 280 }
        }
        local sliderX = sx + 15
        local sliderWidth = sw - 30
        for _, s in ipairs(settingsSliders) do
            if mx >= sliderX - 6 and mx <= sliderX + sliderWidth + 6 and my >= s.y - 8 and my <= s.y + 8 then
                self.settingSliderDragging = s.name
                local pct = math.max(0, math.min(1.0, (mx - sliderX) / sliderWidth))
                self[s.name] = s.minVal + pct * (s.maxVal - s.minVal)
                self:saveConfig()
                return
            end
        end
        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
            return
        end
    end

    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + self.headerHeight then
        self.draggingPanel = "layers"
        self.dragOffsetX = mx - lx
        self.dragOffsetY = my - ly
        return
    end

    if mx >= px2 and mx <= px2 + pw2 and my >= py2 and my <= py2 + self.headerHeight then
        self.draggingPanel = "power"
        self.dragOffsetX = mx - px2
        self.dragOffsetY = my - py2
        return
    end

    if mx >= mx3 and mx <= mx3 + mw3 and my >= my3 and my <= my3 + self.headerHeight then
        self.draggingPanel = "military"
        self.dragOffsetX = mx - mx3
        self.dragOffsetY = my - my3
        return
    end

    local btn1X = mx3 + 15
    local btn1Y = my3 + 90
    local btn1W = mw3 - 30
    local btn1H = 24
    if mx >= btn1X and mx <= btn1X + btn1W and my >= btn1Y and my <= btn1Y + btn1H then
        if GM.Battalions and GM.Battalions.soldiers >= 10 then
            GM.Battalions.soldiers = GM.Battalions.soldiers - 10
            local sx, sy = GM.PlayerCountry.capitalX, GM.PlayerCountry.capitalY
            for _, b in ipairs(GM.Building.List) do
                if b.cell and b.cell:getOwner() == GM.PlayerCountry then
                    sx, sy = b.x, b.y
                    break
                end
            end
            GM.Battalions:Spawn(sx, sy, 10)
        end
        return
    end

    local btn2X = mx3 + 15
    local btn2Y = my3 + 120
    local btn2W = mw3 - 30
    local btn2H = 24
    if mx >= btn2X and mx <= btn2X + btn2W and my >= btn2Y and my <= btn2Y + btn2H then
        local selectedBat = nil
        if GM.Battalions and GM.Battalions.List then
            for _, b in ipairs(GM.Battalions.List) do
                if b.selected then
                    selectedBat = b
                    break
                end
            end
        end
        if selectedBat then
            GM.Battalions:Split(selectedBat)
        end
        return
    end

    local btn3X = mx3 + 15
    local btn3Y = my3 + 150
    local btn3W = mw3 - 30
    local btn3H = 24
    if mx >= btn3X and mx <= btn3X + btn3W and my >= btn3Y and my <= btn3Y + btn3H then
        local selectedBat = nil
        if GM.Battalions and GM.Battalions.List then
            for _, b in ipairs(GM.Battalions.List) do
                if b.selected then
                    selectedBat = b
                    break
                end
            end
        end
        if selectedBat and selectedBat.potentialTarget then
            selectedBat.path = selectedBat.pathPreview
            selectedBat.pathIndex = 1
            selectedBat.moving = true
            selectedBat.targetX = selectedBat.potentialTarget.x
            selectedBat.targetY = selectedBat.potentialTarget.y
            selectedBat.potentialTarget = nil
            selectedBat.pathPreview = nil
        end
        return
    end

    local sliderX = px2 + 15
    local sliderWidth = pw2 - 30
    local sliders = {
        { name = "expansion", y = py2 + 52 },
        { name = "diplomacy", y = py2 + 97 },
        { name = "army",      y = py2 + 142 }
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

    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then
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
        if self.sliderDragging or self.settingSliderDragging or self.draggingPanel then
            self:saveConfig()
        end
        self.sliderDragging = nil
        self.settingSliderDragging = nil
        self.draggingPanel = nil
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
    local keys = { "expansion", "diplomacy", "army" }
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

function Hud:getLayersRect()
    local W, H = love.graphics.getDimensions()
    local x = self.layersX or (W - self.width - self.margin)
    local y = self.layersY or self.margin
    return x, y, self.width, self.height
end

function Hud:getPowerRect()
    local W, H = love.graphics.getDimensions()
    local lx, ly, lw, lh = self:getLayersRect()
    local x = self.powerX or (W - self.width - self.margin)
    local y = self.powerY or (ly + lh + self.margin)
    return x, y, self.width, 170
end

function Hud:getMilitaryRect()
    local W, H = love.graphics.getDimensions()
    local px, py, pw, ph = self:getPowerRect()
    local x = self.militaryX or (W - self.width - self.margin)
    local y = self.militaryY or (py + ph + self.margin)
    return x, y, self.width, 180
end

function Hud:isMouseOver()
    local mx, my = love.mouse.getPosition()
    local lx, ly, lw, lh = self:getLayersRect()
    local px2, py2, pw2, ph2 = self:getPowerRect()
    local mx3, my3, mw3, mh3 = self:getMilitaryRect()
    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then return true end
    if mx >= px2 and mx <= px2 + pw2 and my >= py2 and my <= py2 + ph2 then return true end
    if mx >= mx3 and mx <= mx3 + mw3 and my >= my3 and my <= my3 + mh3 then return true end
    if self.settingsOpen then
        local W, H = love.graphics.getDimensions()
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then return true end
    end
    if mx >= 16 and mx <= 48 and my >= 16 and my <= 48 then return true end
    return false
end

function Hud:saveConfig()
    local data = string.format("layersX=%d\nlayersY=%d\npowerX=%d\npowerY=%d\nmilitaryX=%d\nmilitaryY=%d\n",
        math.floor(self.layersX or -1),
        math.floor(self.layersY or -1),
        math.floor(self.powerX or -1),
        math.floor(self.powerY or -1),
        math.floor(self.militaryX or -1),
        math.floor(self.militaryY or -1))
    love.filesystem.write("hud_config.txt", data)
end

function Hud:loadConfig()
    if love.filesystem.getInfo("hud_config.txt") then
        local content = love.filesystem.read("hud_config.txt")
        if content then
            for line in string.gmatch(content, "[^\r\n]+") do
                local key, val = string.match(line, "([^=]+)=([^=]+)")
                if key and val then
                    val = tonumber(val)
                    if val and val >= 0 then
                        if key == "layersX" then
                            self.layersX = val
                        elseif key == "layersY" then
                            self.layersY = val
                        elseif key == "powerX" then
                            self.powerX = val
                        elseif key == "powerY" then
                            self.powerY = val
                        elseif key == "militaryX" then
                            self.militaryX = val
                        elseif key == "militaryY" then
                            self.militaryY = val
                        end
                    end
                end
            end
        end
    end
end

function Hud:Think(dt)
    local mx, my = love.mouse.getPosition()
    local gearHovered = mx >= 16 and mx <= 48 and my >= 16 and my <= 48
    if gearHovered then
        self.gearRotation = (self.gearRotation or 0) + dt * 2
    end

    if self.draggingPanel then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.draggingPanel = nil
            return
        end
        if self.draggingPanel == "layers" then
            self.layersX = mx - self.dragOffsetX
            self.layersY = my - self.dragOffsetY
        elseif self.draggingPanel == "power" then
            self.powerX = mx - self.dragOffsetX
            self.powerY = my - self.dragOffsetY
        elseif self.draggingPanel == "military" then
            self.militaryX = mx - self.dragOffsetX
            self.militaryY = my - self.dragOffsetY
        end
    elseif self.settingSliderDragging then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.settingSliderDragging = nil
            return
        end
        local W, H = love.graphics.getDimensions()
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        local sliderX = sx + 15
        local sliderWidth = sw - 30
        local pct = math.max(0, math.min(1.0, (mx - sliderX) / sliderWidth))

        local lx, ly, lw, lh = self:getLayersRect()
        local px, py, pw, ph = self:getPowerRect()
        local mx3, my3, mw3, mh3 = self:getMilitaryRect()

        if self.settingSliderDragging == "layersX" then
            self.layersX = pct * (W - lw)
        elseif self.settingSliderDragging == "layersY" then
            self.layersY = pct * (H - lh)
        elseif self.settingSliderDragging == "powerX" then
            self.powerX = pct * (W - pw)
        elseif self.settingSliderDragging == "powerY" then
            self.powerY = pct * (H - ph)
        elseif self.settingSliderDragging == "militaryX" then
            self.militaryX = pct * (W - mw3)
        elseif self.settingSliderDragging == "militaryY" then
            self.militaryY = pct * (H - mh3)
        end
    elseif self.sliderDragging then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.sliderDragging = nil
            return
        end
        local px2, py2, pw2, ph2 = self:getPowerRect()
        local sliderX = px2 + 15
        local sliderWidth = pw2 - 30
        local pct = math.max(0, math.min(100, math.floor(((mx - sliderX) / sliderWidth) * 100 + 0.5)))
        self:adjustSliders(self.sliderDragging, pct)
    end
end

return Hud
