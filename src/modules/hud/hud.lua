local Class = require("src.core.class")
local GM = require("src.core.index")
local Flags = require("src.modules.hud.flags")

local Hud = Class()

function Hud:init()
    self.width = 200
    self.height = 145
    self.margin = 20
    self.hoveredLayerIdx = nil
end

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

function Hud:getPanelRect()
    local W, H = love.graphics.getDimensions()
    local x = W - self.width - self.margin
    local y = self.margin
    return x, y, self.width, self.height
end

function Hud:Draw()
    local map = GM.Game and GM.Game.Map
    if not map then return end

    local px, py, pw, ph = self:getPanelRect()
    local mx, my = love.mouse.getPosition()

    love.graphics.push("all")

    love.graphics.setColor(0.06, 0.08, 0.12, 0.85)
    love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)

    love.graphics.setColor(0.2, 0.4, 0.8, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 8, 8)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ATHENA LAYERS", px + 15, py + 15)

    love.graphics.setColor(0.2, 0.4, 0.8, 0.2)
    love.graphics.line(px + 15, py + 33, px + pw - 15, py + 33)

    local layersList = {
        { name = "Base Map",  state = map.layers.terrain,   key = "1" },
        { name = "Countries", state = map.layers.political, key = "2" },
        { name = "Buildings", state = map.layers.buildings, key = "3" }
    }

    self.hoveredLayerIdx = nil

    for i, item in ipairs(layersList) do
        local itemY = py + 32 + i * 26

        local isHovered = (mx >= px + 10 and mx <= px + pw - 10 and my >= itemY - 4 and my <= itemY + 18)
        if isHovered then
            self.hoveredLayerIdx = i
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", px + 10, itemY - 4, pw - 20, 22, 4, 4)
        end

        local cbSize = 10
        local cbX = px + 18
        local cbY = itemY + 2

        if item.state then
            love.graphics.setColor(0.1, 0.8, 0.5, 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        end
        love.graphics.rectangle("line", cbX, cbY, cbSize, cbSize, 2, 2)

        if item.state then
            love.graphics.setColor(0.1, 0.8, 0.5, 0.3)
            love.graphics.rectangle("fill", cbX + 2, cbY + 2, cbSize - 4, cbSize - 4, 1, 1)
        end

        love.graphics.setColor(0.9, 0.9, 0.95, 1)
        love.graphics.print(item.name, cbX + 20, cbY - 3)

        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        love.graphics.print("[" .. item.key .. "]", px + pw - 35, cbY - 3)
    end

    local worldX, worldY = GM.Building:GetWorldMouse()
    local cellX = math.floor(worldX + 1)
    local cellY = math.floor(worldY + 1)

    local W, H = love.graphics.getDimensions()

    if map:isValidCell(cellX, cellY) then
        local cell = map.grid[cellX][cellY]
        local infoText = string.format("Grid X:%d Y:%d", cellX, cellY)
        local territoryOwner = cell.owner
        local hasTerritoryFlag = territoryOwner and map.layers.political and territoryOwner.flag and territoryOwner.flag ~= ""

        if territoryOwner and map.layers.political then
            infoText = infoText .. " | Territory: " .. territoryOwner.name
        end

        local sh = H - 35
        local panelWidth = hasTerritoryFlag and 350 or 320
        love.graphics.setColor(0.06, 0.08, 0.12, 0.85)
        love.graphics.rectangle("fill", 15, sh, panelWidth, 24, 4, 4)
        love.graphics.setColor(0.2, 0.4, 0.8, 0.4)
        love.graphics.rectangle("line", 15, sh, panelWidth, 24, 4, 4)

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

            love.graphics.setColor(0.06, 0.08, 0.12, 0.92)
            love.graphics.rectangle("fill", tx, ty, tWidth, tHeight, 6, 6)

            love.graphics.setColor(0.25, 0.5, 0.9, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tx, ty, tWidth, tHeight, 6, 6)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(hoveredBuilding.name, tx + 12, ty + 10)

            local badgeText = hoveredBuilding.type:gsub("^%l", string.upper)
            local br, bg, bb = 0.5, 0.5, 0.5
            if hoveredBuilding.type == "capital" then
                br, bg, bb = 1, 0.8, 0.1
            elseif hoveredBuilding.type == "fort" then
                br, bg, bb = 0.8, 0.3, 0.3
            elseif hoveredBuilding.type == "port" then
                br, bg, bb = 0.2, 0.6, 1
            end

            love.graphics.setColor(br, bg, bb, 0.15)
            love.graphics.rectangle("fill", tx + 12, ty + 28, 55, 14, 3, 3)
            love.graphics.setColor(br, bg, bb, 0.8)
            love.graphics.rectangle("line", tx + 12, ty + 28, 55, 14, 3, 3)

            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(badgeText, tx + 17, ty + 28)

            if hoveredBuilding.owner then
                local oColor = hoveredBuilding.owner.color
                love.graphics.setColor(oColor[1] / 255, oColor[2] / 255, oColor[3] / 255, 1)
                love.graphics.print(hoveredBuilding.owner.name, tx + 12, ty + 48)
                self:drawFlag(hoveredBuilding.owner.flag, tx + tWidth - 32, ty + 8, 20)
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.print("No Owner", tx + 12, ty + 48)
            end
        end
    end

    love.graphics.pop()
end

function Hud:MousePressed(x, y, button, istouch, presses)
    if button ~= 1 then return end

    local map = GM.Game and GM.Game.Map
    if not map then return end

    local px, py, pw, ph = self:getPanelRect()
    local mx, my = love.mouse.getPosition()

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

return Hud
