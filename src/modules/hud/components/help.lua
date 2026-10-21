local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")

local Help = { id = "help", modal = true }

local LINES = {
    { "Left click", "Spawn / attack neighbour / send boat overseas" },
    { "Right click", "Context menu: build, nukes, diplomacy" },
    { "Right drag", "Move the camera" },
    { "Mouse wheel", "Zoom" },
    { "Space", "Start the game after choosing a spawn" },
    { "P", "Pause" },
    { "+ / -", "Change game speed" },
    { "1 - 5", "Toggle terrain, territories, units, names, supply" },
    { "6 / 7", "Threat map / diplomatic map" },
    { "H", "Show or hide this help" },
    { "Escape", "Settings" }
}

Help.lines = LINES

function Help.visible(hud)
    return hud.helpOpen == true
end

function Help.size()
    return 600, Style.headerHeight + 40 + #LINES * 30
end

function Help.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function Help.draw(hud, x, y, w, h)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(0.02, 0.03, 0.06, 0.5 * Pixel.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
    Style.frame(x, y, w, h, "CONTROLS", { grip = false, accent = Style.colors.gold, cornerAlpha = 0.9 })
    local u = Pixel.unit
    local age = hud:appeared(Help)
    local base = Pixel.alpha
    local font = Style.font(12)
    local keyW = 0
    for _, line in ipairs(LINES) do
        keyW = math.max(keyW, font:getWidth(line[1]) + u * 8)
    end
    for k, line in ipairs(LINES) do
        local e = Fx.outCubic(Fx.clamp(age * 5 - k * 0.25, 0, 1))
        Pixel.alpha = base * e
        local ly = y + Style.headerHeight + 18 + (k - 1) * 30
        local lx = x + 24 + math.floor((1 - e) * -20)
        local kw = font:getWidth(line[1]) + u * 6
        local kx = lx + keyW - kw
        Pixel.color(Pixel.colors.ink, 0.9)
        Pixel.block(kx, ly, kw, 24, u)
        Pixel.color(Pixel.colors.raised)
        Pixel.block(kx + u, ly + u, kw - 2 * u, 24 - 3 * u, u)
        love.graphics.setColor(1, 1, 1, 0.15 * Pixel.alpha)
        love.graphics.rectangle("fill", kx + 2 * u, ly + u, kw - 4 * u, u)
        Pixel.text(line[1], kx + u * 3, ly + 2, 12, Style.colors.gold)
        Pixel.text(line[2], lx + keyW + 16, ly + 2, 13, Style.colors.text)
    end
    Pixel.alpha = base
end

function Help.mousePressed(hud)
    hud.helpOpen = false
end

function Help.keyPressed(hud, key)
    if key == "h" then
        hud.helpOpen = not hud.helpOpen
        return true
    end
    if key == "escape" and hud.helpOpen then
        hud.helpOpen = false
        return true
    end
    return false
end

return Help
