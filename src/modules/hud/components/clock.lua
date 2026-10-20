local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Icons = require("src.modules.hud.icons")

local Clock = { id = "clock" }

local W, H = 300, 34
local BUTTON = 34

local function rect()
    local sw = love.graphics.getWidth()
    return (sw - W) / 2, 16, W, H
end

local function buttons(x, y)
    local list = { { kind = "pause", x = x + 86, y = y + 5, w = 30, h = 24 } }
    for k, speed in ipairs(Config.speeds) do
        list[#list + 1] = { kind = "speed", index = k, label = "x" .. speed, x = x + 122 + (k - 1) * (BUTTON + 6), y = y + 5, w = BUTTON, h = 24 }
    end
    return list
end

function Clock.visible(hud)
    return hud:game().phase ~= "spawn"
end

function Clock.hit(hud, mx, my)
    return Style.inside(mx, my, rect())
end

function Clock.draw(hud)
    local game = hud:game()
    local x, y, w, h = rect()
    Style.box(x, y, w, h)
    love.graphics.setFont(Style.font(15))
    Style.setColor(game.paused and Style.colors.gold or Style.colors.text)
    love.graphics.print(Format.time(game.tick, Config.tickRate), x + 14, y + 8)
    for _, b in ipairs(buttons(x, y)) do
        if b.kind == "pause" then
            Style.button(b.x, b.y, b.w, b.h, "", { active = game.paused })
            local icon = Icons.get("PlayPause.png")
            if icon then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(icon, b.x + (b.w - 16) / 2, b.y + (b.h - 16) / 2)
            end
        else
            Style.button(b.x, b.y, b.w, b.h, b.label, { size = 11, active = game.speedIndex == b.index and not game.paused })
        end
    end
end

function Clock.mousePressed(hud, mx, my, button)
    if button ~= 1 then return end
    local game = hud:game()
    local x, y = rect()
    for _, b in ipairs(buttons(x, y)) do
        if Style.inside(mx, my, b.x, b.y, b.w, b.h) then
            if b.kind == "pause" then
                game.paused = not game.paused
            else
                game.speedIndex = b.index
                game.paused = false
            end
        end
    end
end

return Clock
