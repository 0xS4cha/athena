local Interaction = require("src.modules.game.interaction")
local Keybinds = require("src.modules.input.keybinds")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Format = require("src.core.format")

local Hotkeys = {}

local function preview(hud)
    local game = hud:game()
    local camera = hud:camera()
    if not game or not camera or not game.buildAim then return nil end
    local mx, my = love.mouse.getPosition()
    return Interaction.buildPreview(game, game.map:tileAt(camera:toWorld(mx, my)))
end

function Hotkeys.visible(hud)
    return preview(hud) ~= nil
end

function Hotkeys.draw(hud)
    local current = preview(hud)
    if not current then return end
    local u = Pixel.unit
    local mx, my = love.mouse.getPosition()
    local color = current.ok and Style.colors.good or Style.colors.bad
    local title = string.upper(current.def.label) .. "  " .. Format.number(current.cost)
    local status = current.ok and "Left click to place  -  Shift: keep placing" or ("Cannot build: " .. current.reason)
    local hint = "Right click / Esc cancel"
    local small = Style.font(10)
    local w = math.max(Style.font(12):getWidth(title), small:getWidth(status), small:getWidth(hint)) + u * 10
    local h = 62
    local W, H = love.graphics.getDimensions()
    local x = mx + 18 + w > W and mx - w - 18 or mx + 18
    local y = math.min(H - h - 4, my + 18)
    Style.frame(x, y, w, h, nil, { accent = color, cornerAlpha = 1 })
    Pixel.text(title, x + u * 5, y + 6, 12, color)
    Pixel.text(status, x + u * 5, y + 26, 10, current.ok and Style.colors.text or Style.colors.bad)
    Pixel.text(hint, x + u * 5, y + 42, 10, Style.colors.muted)
end

function Hotkeys.keyPressed(hud, key)
    if hud.settingsOpen or hud.helpOpen then return false end
    local action = Keybinds.find(key)
    if not action then return false end
    hud.contextMenu:close()
    Interaction.hotkey(hud:game(), action)
    return true
end

return Hotkeys
