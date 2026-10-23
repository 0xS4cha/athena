local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")

local Modal = { id = "settings", modal = true }
local Gear = { id = "gear" }

local GEAR_X, GEAR_Y, GEAR_SIZE = 16, 14, 42
local WIDTH = 320
local BUTTON_H = 44
local GAP = 12
local TOP = 64

local function buttons(hud)
    local list = {
        { label = "Resume", icon = "Play.png", action = function() hud.settingsOpen = false end },
        { label = "Reset Panel Positions", icon = "Restart.png", action = function() hud:resetPositions() end }
    }
    if GM.Menu then
        local advanced = GM.Menu.settings.advancedEvents
        list[#list + 1] = {
            label = "Advanced Events: " .. (advanced and "On" or "Off"),
            icon = "Book.png",
            action = function() GM.Menu:setOption("advancedEvents", not advanced) end
        }
    end
    if GM.Menu then
        list[#list + 1] = {
            label = "Back To Menu",
            icon = "Home.png",
            action = function()
                hud.settingsOpen = false
                GM.Session:Stop()
                GM.Menu:Open()
            end
        }
    end
    list[#list + 1] = { label = "Quit Game", icon = "Exit.png", danger = true, action = function() love.event.quit() end }
    return list
end

local function buttonRect(x, y, w, k)
    return x + 34, y + TOP + (k - 1) * (BUTTON_H + GAP), w - 58, BUTTON_H
end

function Modal.visible(hud)
    return hud.settingsOpen == true
end

function Modal.size(hud)
    return WIDTH, TOP + #buttons(hud) * (BUTTON_H + GAP) + 18
end

function Modal.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function Modal.draw(hud, x, y, w, h)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(0.02, 0.03, 0.06, 0.55 * Pixel.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
    Style.frame(x, y, w, h, "PAUSE MENU", { grip = false, accent = Style.colors.gold, cornerAlpha = 0.9 })
    Pixel.text("Drag panel headers to move them", x + 18, y + 34, 11, Style.colors.muted)
    local mx, my = love.mouse.getPosition()
    local age = hud:appeared(Modal)
    local base = Pixel.alpha
    for k, button in ipairs(buttons(hud)) do
        local bx, by, bw, bh = buttonRect(x, y, w, k)
        local e = Fx.outCubic(Fx.clamp(age * 4 - k * 0.35, 0, 1))
        Pixel.alpha = base * e
        local hot = hud.settingsFocus == k or Style.inside(mx, my, bx, by, bw, bh)
        Pixel.button("pause:" .. k, bx + math.floor((1 - e) * -30), by, bw, bh, button.label, {
            hot = hot,
            icon = button.icon,
            align = "left",
            size = 14,
            color = button.danger and Style.colors.bad or nil,
            primary = k == 1
        })
    end
    Pixel.alpha = base
end

function Modal.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    if not Style.inside(mx, my, x, y, w, h) then
        hud.settingsOpen = false
        return
    end
    for k, b in ipairs(buttons(hud)) do
        if Style.inside(mx, my, buttonRect(x, y, w, k)) then
            b.action()
            return
        end
    end
end

function Modal.keyPressed(hud, key)
    if key == "escape" then
        hud.settingsOpen = not hud.settingsOpen
        hud.settingsFocus = nil
        return true
    end
    if not hud.settingsOpen then
        return false
    end
    local list = buttons(hud)
    if key == "up" or key == "down" then
        local focus = hud.settingsFocus or (key == "down" and 0 or 2)
        hud.settingsFocus = (focus - 1 + (key == "down" and 1 or -1)) % #list + 1
        return true
    elseif (key == "return" or key == "kpenter") and hud.settingsFocus then
        list[hud.settingsFocus].action()
        return true
    end
    return false
end

function Gear.init(hud)
    hud.settingsOpen = false
    hud.gearRotation = 0
    hud.gearImage = love.graphics.newImage("assets/Icons/Gear.png")
    hud.gearImage:setFilter("nearest", "nearest")
end

function Gear.hit(_, mx, my)
    return Style.inside(mx, my, GEAR_X, GEAR_Y, GEAR_SIZE, GEAR_SIZE)
end

function Gear.think(hud, dt)
    local mx, my = love.mouse.getPosition()
    local speed = (Gear.hit(hud, mx, my) or hud.settingsOpen) and 3 or 0.25
    hud.gearRotation = hud.gearRotation + dt * speed
end

function Gear.draw(hud)
    local mx, my = love.mouse.getPosition()
    local hot = Pixel.ease("gear:hot", Gear.hit(hud, mx, my) or hud.settingsOpen, 16)
    local u = Pixel.unit
    Pixel.color(Pixel.colors.ink, 0.45)
    Pixel.block(GEAR_X + u * 2, GEAR_Y + u * 2, GEAR_SIZE, GEAR_SIZE)
    Pixel.color(Pixel.colors.ink)
    Pixel.block(GEAR_X, GEAR_Y, GEAR_SIZE, GEAR_SIZE)
    Pixel.color(Pixel.mix(Pixel.colors.raised, Pixel.colors.edge, hot * 0.7))
    Pixel.block(GEAR_X + u, GEAR_Y + u, GEAR_SIZE - u * 2, GEAR_SIZE - u * 2)
    love.graphics.setColor(1, 1, 1, 0.1 + 0.2 * hot)
    love.graphics.rectangle("fill", GEAR_X + u * 2, GEAR_Y + u, GEAR_SIZE - u * 4, u)
    Pixel.corners(GEAR_X, GEAR_Y, GEAR_SIZE, GEAR_SIZE, Style.colors.gold, hot)
    local img = hud.gearImage
    local cx, cy = GEAR_X + GEAR_SIZE / 2, GEAR_Y + GEAR_SIZE / 2
    local snapped = math.floor(hud.gearRotation / (math.pi / 8)) * (math.pi / 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, cx, cy, snapped, 26 / img:getWidth(), 26 / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2)
end

function Gear.mousePressed(hud, _, _, button)
    if button == 1 then
        hud.settingsOpen = not hud.settingsOpen
        hud.settingsFocus = nil
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
