local Settings = {}

function Settings.draw(hud)
    local W, H = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local lx, ly, lw, lh = hud:getLayersRect()
    local px2, py2, pw2, ph2 = hud:getPowerRect()
    local mx3, my3, mw3, mh3 = hud:getMilitaryRect()

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
    if hud.gearImage then
        local imgW = hud.gearImage:getWidth()
        local imgH = hud.gearImage:getHeight()
        local scaleX = 24 / imgW
        local scaleY = 24 / imgH
        local rot = hud.gearRotation or 0
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hud.gearImage, cx, cy, rot, scaleX, scaleY, imgW / 2, imgH / 2)
    end
    love.graphics.pop()

    if hud.settingsOpen then
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
        love.graphics.rectangle("fill", sx + 3, sy + 3, sw - 6, hud.headerHeight - 2)
        love.graphics.setColor(0.2, 0.45, 0.8, 0.3)
        love.graphics.line(sx + 3, sy + hud.headerHeight + 1, sx + sw - 3, sy + hud.headerHeight + 1)
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
            if isHovered or hud.settingSliderDragging == s.name then
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
end

function Settings.mousePressed(hud, mx, my, button)
    local W, H = love.graphics.getDimensions()
    local lx, ly, lw, lh = hud:getLayersRect()
    local px2, py2, pw2, ph2 = hud:getPowerRect()
    local mx3, my3, mw3, mh3 = hud:getMilitaryRect()

    if mx >= 16 and mx <= 48 and my >= 16 and my <= 48 then
        hud.settingsOpen = not hud.settingsOpen
        return true
    end

    if hud.settingsOpen then
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        local btnX = sx + 15
        local btnY = sy + 320
        local btnW = sw - 30
        local btnH = 35

        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            hud.layersX = nil
            hud.layersY = nil
            hud.powerX = nil
            hud.powerY = nil
            hud.militaryX = nil
            hud.militaryY = nil
            hud:saveConfig()
            return true
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
                hud.settingSliderDragging = s.name
                local pct = math.max(0, math.min(1.0, (mx - sliderX) / sliderWidth))
                hud[s.name] = s.minVal + pct * (s.maxVal - s.minVal)
                hud:saveConfig()
                return true
            end
        end

        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then
            return true
        end
    end
    return false
end

return Settings
