local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")

local Clock = { id = "clock" }

local W, H = 330, 42
local PAUSE = 36

local function labels()
    local list = {}
    for k, speed in ipairs(Config.speeds) do
        list[k] = "x" .. speed
    end
    return list
end

function Clock.size()
    return W, H
end

function Clock.position(_, w, _, sw)
    return math.floor((sw - w) / 2), 14
end

local function layout(x, y)
    local pause = { x = x + 92, y = y + 6, w = PAUSE, h = H - 12 }
    local speeds = { x = pause.x + PAUSE + 8, y = y + 6, h = H - 12 }
    speeds.w = x + W - 8 - speeds.x
    return pause, speeds
end

function Clock.visible(hud)
    return hud:game().phase ~= "spawn"
end

function Clock.draw(hud, x, y)
    local game = hud:game()
    local u = Pixel.unit
    Style.box(x, y, W, H, { corners = true })
    local blink = game.paused and love.timer.getTime() % 1 < 0.5
    Pixel.text(Format.time(game.tick, Config.tickRate), x + u * 5, y + 7, 15, blink and Style.colors.gold or Style.colors.text, blink and 1 or nil)
    local second = (game.tick % Config.tickRate + game.accumulator * Config.tickRate) / Config.tickRate
    Pixel.color(Pixel.colors.ink, 0.8)
    love.graphics.rectangle("fill", x + u * 5, y + H - u * 4, 62, u)
    Pixel.color(game.paused and Style.colors.gold or Style.colors.troops)
    love.graphics.rectangle("fill", x + u * 5, y + H - u * 4, math.floor(62 * math.min(1, second) / u) * u, u)

    local pause, speeds = layout(x, y)
    Style.button(pause.x, pause.y, pause.w, pause.h, "", { id = "clock:pause", active = game.paused, color = Style.colors.gold, icon = "PlayPause.png", iconSize = 18 })
    Pixel.segments("clock:speed", speeds.x, speeds.y, speeds.w, speeds.h, labels(), game.speedIndex, {
        hot = Style.inside(love.mouse.getX(), love.mouse.getY(), speeds.x, speeds.y, speeds.w, speeds.h),
        color = game.paused and Pixel.colors.raised or Pixel.colors.hover,
        size = 11
    })
end

function Clock.mousePressed(hud, mx, my, button, x, y)
    if button ~= 1 then return end
    local game = hud:game()
    if game.lockstep then return end
    local pause, speeds = layout(x, y)
    if Style.inside(mx, my, pause.x, pause.y, pause.w, pause.h) then
        game.paused = not game.paused
    elseif Style.inside(mx, my, speeds.x, speeds.y, speeds.w, speeds.h) then
        local count = #Config.speeds
        game.speedIndex = math.max(1, math.min(count, math.floor((mx - speeds.x) / (speeds.w / count)) + 1))
        game.paused = false
    end
end

return Clock
