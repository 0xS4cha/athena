local GM = require("src.core.index")
local Style = require("src.modules.hud.style")

local Modal = { id = "settings", modal = true }
local Gear = { id = "gear" }

local GEAR_X, GEAR_Y, GEAR_SIZE = 16, 16, 32

local function buttons(hud)
    local list = {
        { label = "Resume", action = function() hud.settingsOpen = false end },
        { label = "Reset Panel Positions", action = function() hud:resetPositions() end }
    }
    if GM.Menu then
        list[#list + 1] = {
            label = "Back To Menu",
            action = function()
                hud.settingsOpen = false
                GM.Session:Stop()
                GM.Menu:Open()
            end
        }
    end
    list[#list + 1] = { label = "Quit Game", action = function() love.event.quit() end }
    return list
end

function Modal.visible(hud)
    return hud.settingsOpen == true
end

function Modal.size(hud)
    return 280, Style.headerHeight + 50 + #buttons(hud) * 44
end

function Modal.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function Modal.draw(hud, x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    Style.frame(x, y, w, h, "SETTINGS")
    Style.setColor(Style.colors.muted)
    love.graphics.setFont(Style.font(12))
    love.graphics.print("Drag panel headers to move them", x + 15, y + 36)
    for k, button in ipairs(buttons(hud)) do
        Style.button(x + 15, y + Style.headerHeight + 40 + (k - 1) * 44, w - 30, 34, button.label)
    end
end

function Modal.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    if not Style.inside(mx, my, x, y, w, h) then
        hud.settingsOpen = false
        return
    end
    for k, b in ipairs(buttons(hud)) do
        if Style.inside(mx, my, x + 15, y + Style.headerHeight + 40 + (k - 1) * 44, w - 30, 34) then
            b.action()
            return
        end
    end
end

function Modal.keyPressed(hud, key)
    if key == "escape" then
        hud.settingsOpen = not hud.settingsOpen
        return true
    end
    return false
end

function Gear.init(hud)
    hud.settingsOpen = false
    hud.gearRotation = 0
    hud.gearImage = love.graphics.newImage("assets/Icons/Gear.png")
end

function Gear.hit(_, mx, my)
    return Style.inside(mx, my, GEAR_X, GEAR_Y, GEAR_SIZE, GEAR_SIZE)
end

function Gear.think(hud, dt)
    local mx, my = love.mouse.getPosition()
    if Gear.hit(hud, mx, my) then
        hud.gearRotation = hud.gearRotation + dt * 2
    end
end

function Gear.draw(hud)
    local mx, my = love.mouse.getPosition()
    local cx, cy = GEAR_X + GEAR_SIZE / 2, GEAR_Y + GEAR_SIZE / 2
    if Gear.hit(hud, mx, my) then
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
    local img = hud.gearImage
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, cx, cy, hud.gearRotation, 24 / img:getWidth(), 24 / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2)
end

function Gear.mousePressed(hud, _, _, button)
    if button == 1 then
        hud.settingsOpen = not hud.settingsOpen
    end
end

local Settings = {
    id = "settingsRoot",
    init = function(hud)
        hud:add(Gear)
        hud:add(Modal)
    end,
    draw = function() end,
    visible = function() return false end
}

return Settings
