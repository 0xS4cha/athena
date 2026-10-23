local Style = require("src.modules.hud.style")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")
local WordArt = require("src.modules.hud.wordart")

local Banner = { id = "banner" }

local SPLASH_SECONDS = 2.4

local function centered(text, y, size, color, options)
    options = options or {}
    local font = Style.font(size)
    local W = love.graphics.getWidth()
    local w = font:getWidth(text) + 48
    local h = font:getHeight() + 16
    local x = math.floor((W - w) / 2)
    Style.box(x, y, w, h, { corners = options.corners, accent = options.accent })
    Pixel.text(text, x + 24, y + 8, size, color or Style.colors.text)
    return y + h + 8, x, w, h
end

local function drawNetwork(game, y, time)
    local status = game.lockstep and game.lockstep:status()
    if not status then return y end
    local on = time % 1.2 < 0.8
    return centered(status, y, 16, on and Style.colors.gold or Style.colors.muted, { corners = true, accent = Style.colors.gold })
end

local function drawSpawn(game, time)
    local u = Pixel.unit
    local seconds = math.ceil(game.spawnTicksLeft / Config.tickRate)
    local y = centered("Choose your starting location", 16, 18, Style.colors.text, { corners = true, accent = Style.colors.gold })
    local prefix, suffix, color
    if game.human.spawned then
        prefix, suffix, color = "Starting in ", "s  -  press SPACE to start now", Style.colors.good
    else
        prefix, suffix, color = "Click on the map to spawn  -  ", "s", Style.colors.gold
    end
    local font = Style.font(13)
    local big = Style.font(20)
    local numW = big:getWidth("00")
    local W = love.graphics.getWidth()
    local w = font:getWidth(prefix) + numW + font:getWidth(suffix) + 48
    local h = 52
    local x = math.floor((W - w) / 2)
    Style.box(x, y, w, h)
    Pixel.text(prefix, x + 24, y + 11, 13, color)
    Pixel.text(suffix, x + 24 + font:getWidth(prefix) + numW, y + 11, 13, color)
    local fraction = ((Config.tickRate - game.spawnTicksLeft % Config.tickRate) % Config.tickRate + game.accumulator * Config.tickRate) / Config.tickRate
    local pulse = 1 + 0.35 * (1 - Fx.outCubic(fraction * 3))
    local label = tostring(seconds)
    love.graphics.push()
    love.graphics.translate(x + 24 + font:getWidth(prefix) + numW / 2, y + 6 + big:getHeight() / 2)
    love.graphics.scale(pulse, pulse)
    Pixel.shadowText(label, -big:getWidth(label) / 2, -big:getHeight() / 2, 20, seconds <= 3 and Style.colors.bad or Style.colors.gold)
    love.graphics.pop()
    local total = game.spawnTicksTotal or Config.spawnSeconds * Config.tickRate
    Pixel.meter("banner:spawn", x + u * 4, y + h - u * 6, w - u * 8, u * 3, game.spawnTicksLeft / total, color, { instant = true })
    centered("Press H for controls", y + h + 10, 12, Style.colors.muted)
    local bob = math.floor(math.sin(time * 5) + 0.5) * u
    Pixel.color(Style.colors.gold)
    Pixel.arrow(math.floor(W / 2), y + h + 54 + bob, 4, 1)
end

function Banner.draw(hud)
    local game = hud:game()
    local time = love.timer.getTime()
    if game.phase == "spawn" then
        hud.splashAt = nil
        drawSpawn(game, time)
        drawNetwork(game, 230, time)
        return
    end
    if game.phase == "playing" and game.human.spawned and not hud.splashAt then
        hud.splashAt = game.tick < 30 and time or time - SPLASH_SECONDS
    end
    local splash = hud.splashAt and time - hud.splashAt or SPLASH_SECONDS
    if splash < SPLASH_SECONDS then
        local W, H = love.graphics.getDimensions()
        local scale = math.max(4, math.floor(H / 150))
        local w, h = WordArt.size("CONQUER!", 22, scale)
        local alpha = Fx.clamp((SPLASH_SECONDS - splash) / 0.5, 0, 1)
        WordArt.draw("CONQUER!", (W - w) / 2, H * 0.3 - h / 2, { size = 22, scale = scale, progress = splash / 0.8, alpha = alpha })
        Pixel.alpha = alpha
        local sub = "Expand your territory"
        local font = Style.font(16)
        Pixel.shadowText(sub, (W - font:getWidth(sub)) / 2, H * 0.3 + h / 2 + 4, 16, Style.colors.text, Fx.clamp((splash - 0.6) * 3, 0, 1))
        Pixel.alpha = 1
    end
    local y = 66
    if game.paused then
        local on = time % 1.2 < 0.8
        y = centered("PAUSED  -  press P to resume", y, 16, on and Style.colors.gold or Style.colors.muted, { corners = true, accent = Style.colors.gold })
    end
    y = drawNetwork(game, y, time)
    Banner.drawNukeAlerts(game, y, time)
end

function Banner.drawNukeAlerts(game, y, time)
    local live = {}
    for _, nuke in ipairs(game.nukeAlerts or {}) do
        if not nuke.dead then
            live[#live + 1] = nuke
        end
    end
    if #live == 0 then return end
    local u = Pixel.unit
    local W = love.graphics.getWidth()
    local rows = math.min(3, #live)
    local w, h = 360, 40 + rows * 22
    local x = math.floor((W - w) / 2)
    local blink = time % 0.6 < 0.35
    Style.box(x, y, w, h, { corners = true, accent = Style.colors.bad })
    Pixel.color(Style.colors.bad, blink and 1 or 0.35)
    Pixel.block(x + u * 2, y + u * 2, w - u * 4, 28, u)
    Pixel.icon("Skull.png", x + 14, y + 10, 16)
    Pixel.text("NUKE INCOMING", x + 38, y + 8, 16, blink and Pixel.colors.ink or Style.colors.text)
    for k = 1, rows do
        local nuke = live[k]
        local ry = y + 38 + (k - 1) * 22
        local left = math.max(0, nuke.duration - nuke.elapsed) / Config.tickRate
        local label = string.format("%s  -  %s", Config.nukes[nuke.nukeKind].label, nuke.owner.name)
        Pixel.text(label, x + 16, ry, 12, Style.colors.text)
        local count = string.format("%.1fs", left)
        Pixel.text(count, x + w - 16 - Style.font(14):getWidth(count), ry - 2, 14, Style.colors.bad)
    end
end

function Banner.keyPressed(hud, key)
    local game = hud:game()
    if key == "space" and game.phase == "spawn" then
        game:submit({ type = "start", player = game.human.id })
        return true
    end
    return false
end

return Banner
