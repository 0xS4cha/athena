local GM = require("src.core.index")

local Layers = {}

function Layers.draw(hud)
    local map = GM.Game and GM.Game.Map
    if not map then return end

    local W, H = love.graphics.getDimensions()
    local lx, ly, lw, lh = hud:getLayersRect()
    local mx, my = love.mouse.getPosition()

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", lx + 3, ly + 3, lw, lh)
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", lx, ly, lw, lh)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", lx, ly, lw, lh)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", lx + 2, ly + 2, lw - 4, lh - 4)
    love.graphics.setColor(0.1, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", lx + 3, ly + 3, lw - 6, hud.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(lx + 3, ly + hud.headerHeight + 1, lx + lw - 3, ly + hud.headerHeight + 1)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("ATHENA LAYERS", lx + 10, ly + 6)

    local layersList = {
        { name = "Base Map",  state = map.layers.terrain,   key = "1" },
        { name = "Countries", state = map.layers.political, key = "2" },
        { name = "Buildings", state = map.layers.buildings, key = "3" }
    }

    hud.hoveredLayerIdx = nil

    for i, item in ipairs(layersList) do
        local itemY = ly + hud.headerHeight + 8 + (i - 1) * 26
        local isHovered = (mx >= lx + 4 and mx <= lx + lw - 4 and my >= itemY - 2 and my <= itemY + 20)
        if isHovered then
            hud.hoveredLayerIdx = i
            love.graphics.setColor(0.1, 0.65, 0.55, 0.8)
            love.graphics.rectangle("fill", lx + 4, itemY - 2, lw - 8, 22)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", lx + 4, itemY - 2, lw - 8, 22)
        end

        local cbSize = 10
        local cbX = lx + 14
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
        love.graphics.print("[" .. item.key .. "]", lx + lw - 28, cbY - 3)
    end

    local worldX, worldY = GM.Building:GetWorldMouse()
    local cellX = math.floor(worldX + 1)
    local cellY = math.floor(worldY + 1)

    if map:isValidCell(cellX, cellY) then
        local cell = map.grid[cellX][cellY]
        local infoText = string.format("Grid X:%d Y:%d", cellX, cellY)
        local territoryOwner = cell:getOwner()
        local hasTerritoryFlag = territoryOwner and map.layers.political and territoryOwner.flag and territoryOwner.flag ~= ""
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
            hud:drawFlag(territoryOwner.flag, 15 + panelWidth - 22, sh + 4, 16)
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
                hud:drawFlag(hoveredBuilding.cell:getOwner().flag, tx + tWidth - 32, ty + 8, 20)
            else
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.print("No Owner", tx + 12, ty + 48)
            end
        end
    end
end

function Layers.mousePressed(hud, mx, my, button)
    local lx, ly, lw, lh = hud:getLayersRect()
    local map = GM.Game and GM.Game.Map
    if not map then return false end

    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then
        if hud.hoveredLayerIdx then
            local layersList = { "terrain", "political", "buildings" }
            local layerKey = layersList[hud.hoveredLayerIdx]
            if layerKey then
                map:toggleLayer(layerKey)
            end
        end
        return true
    end
    return false
end

return Layers
