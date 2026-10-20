local Style = require("src.modules.hud.style")

local Help = { id = "help", modal = true }

local LINES = {
    { "Left click", "Spawn / attack neighbour / send boat overseas" },
    { "Right click", "Context menu: build, nukes, diplomacy" },
    { "Right drag", "Move the camera" },
    { "Mouse wheel", "Zoom" },
    { "Space", "Start the game after choosing a spawn" },
    { "P", "Pause" },
    { "+ / -", "Change game speed" },
    { "1 2 3 4", "Toggle terrain, territories, units, names" },
    { "H", "Show or hide this help" },
    { "Escape", "Settings" }
}

function Help.visible(hud)
    return hud.helpOpen == true
end

function Help.size()
    return 520, Style.headerHeight + 30 + #LINES * 24
end

function Help.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function Help.draw(hud, x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    Style.frame(x, y, w, h, "CONTROLS")
    love.graphics.setFont(Style.font(13))
    for k, line in ipairs(LINES) do
        local ly = y + Style.headerHeight + 14 + (k - 1) * 24
        Style.setColor(Style.colors.gold)
        love.graphics.print(line[1], x + 20, ly)
        Style.setColor(Style.colors.text)
        love.graphics.print(line[2], x + 150, ly)
    end
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
