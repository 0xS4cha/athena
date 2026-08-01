local Power = {}

function Power.draw(hud)
    local W, H = love.graphics.getDimensions()
    local px2, py2, pw2, ph2 = hud:getPowerRect()
    local mx, my = love.mouse.getPosition()

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
    love.graphics.rectangle("fill", px2 + 3, py2 + 3, pw2 - 6, hud.headerHeight - 2)
    love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
    love.graphics.line(px2 + 3, py2 + hud.headerHeight + 1, px2 + pw2 - 3, py2 + hud.headerHeight + 1)
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.print("POWER ALLOCATION", px2 + 10, py2 + 6)

    local sliders = {
        { name = "expansion", label = "Expansion", color = { 0.9, 0.5, 0.1 },   val = hud.powerAllocation.expansion, y = py2 + 52 },
        { name = "diplomacy", label = "Diplomacy", color = { 0.1, 0.6, 0.9 },   val = hud.powerAllocation.diplomacy, y = py2 + 97 },
        { name = "army",      label = "Army",      color = { 0.9, 0.25, 0.25 }, val = hud.powerAllocation.army,      y = py2 + 142 }
    }

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
        if isHovered or hud.sliderDragging == s.name then
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
end

function Power.mousePressed(hud, mx, my, _)
    local px2, py2, pw2, ph2 = hud:getPowerRect()
    local sliderX = px2 + 15
    local sliderWidth = pw2 - 30
    local sliders = {
        { name = "expansion", y = py2 + 52 },
        { name = "diplomacy", y = py2 + 97 },
        { name = "army",      y = py2 + 142 }
    }

    for _, s in ipairs(sliders) do
        if mx >= sliderX - 6 and mx <= sliderX + sliderWidth + 6 and my >= s.y - 8 and my <= s.y + 8 then
            hud.sliderDragging = s.name
            local pct = math.max(0, math.min(100, math.floor(((mx - sliderX) / sliderWidth) * 100 + 0.5)))
            hud:adjustSliders(s.name, pct)
            return true
        end
    end
    return false
end

return Power
