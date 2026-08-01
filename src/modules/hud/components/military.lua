local GM = require("src.core.index")

local Military = {}

function Military.draw(hud)
    local W, H = love.graphics.getDimensions()
    local mx3, my3, mw3, mh3 = hud:getMilitaryRect()
    local mx, my = love.mouse.getPosition()

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
    love.graphics.rectangle("fill", mx3 + 3, my3 + 3, mw3 - 6, hud.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(mx3 + 3, my3 + hud.headerHeight + 1, mx3 + mw3 - 3, my3 + hud.headerHeight + 1)
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
    love.graphics.setColor((isSelected and hasPotential) and 0.9 or 0.4, (isSelected and hasPotential) and 0.9 or 0.4,
        (isSelected and hasPotential) and 0.95 or 0.4, 1)
    local btn3Text = "LAUNCH MOVEMENT"
    love.graphics.print(btn3Text, btn3X + (btn3W - love.graphics.getFont():getWidth(btn3Text)) / 2, btn3Y + 5)
end

function Military.mousePressed(hud, mx, my, _)
    local mx3, my3, mw3, mh3 = hud:getMilitaryRect()

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
        return true
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
        return true
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
        return true
    end
    return false
end

return Military
