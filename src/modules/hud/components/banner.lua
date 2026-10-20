local Style = require("src.modules.hud.style")
local Config = require("src.config.game")

local Banner = { id = "banner" }

local function centered(text, y, size, color)
    local font = Style.font(size)
    love.graphics.setFont(font)
    local W = love.graphics.getWidth()
    local w = font:getWidth(text) + 40
    local h = font:getHeight() + 14
    local x = (W - w) / 2
    Style.box(x, y, w, h)
    Style.setColor(color or Style.colors.text)
    love.graphics.print(text, x + 20, y + 7)
    return y + h + 6
end

function Banner.draw(hud)
    local game = hud:game()
    local y = 16
    if game.phase == "spawn" then
        local seconds = math.ceil(game.spawnTicksLeft / Config.tickRate)
        y = centered("Choose your starting location", y, 18)
        if game.human.spawned then
            centered(string.format("Starting in %ds  -  press SPACE to start now", seconds), y, 13, Style.colors.good)
        else
            centered(string.format("Click on the map to spawn  -  %ds", seconds), y, 13, Style.colors.gold)
        end
        return
    end
    if game.paused then
        y = centered("PAUSED  -  press P to resume", y, 16, Style.colors.gold)
    elseif game:speed() > 1 then
        y = centered(string.format("Speed x%d", game:speed()), y, 13, Style.colors.muted)
    end
end

function Banner.keyPressed(hud, key)
    local game = hud:game()
    if key == "space" and game.phase == "spawn" then
        game:pushIntent({ type = "start", player = game.human.id })
        return true
    end
    return false
end

return Banner
