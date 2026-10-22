local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Title = require("src.modules.menu.title")

local Root = { id = "root" }

local function margin()
    local W = love.graphics.getWidth()
    return math.max(40, math.floor(W * 0.05))
end

local function titleY()
    local _, H = love.graphics.getDimensions()
    return math.floor(H * 0.1)
end

function Root.build(menu)
    local M = margin()
    local _, th = Title.size()
    local y = titleY() + th + 64
    local w = 380
    local s = menu.settings
    local map = menu:current()
    local summary = string.format("%s  -  %d bots  -  %s", map and map.name or "?", s.bots, s.difficulty:sub(1, 1):upper() .. s.difficulty:sub(2))
    local list = {
        { id = "play", label = "PLAY", sublabel = summary, icon = "Play.png", primary = true, h = 74, press = function() menu:switch("play", 1) end },
        { id = "multiplayer", label = "MULTIPLAYER", icon = "Team.png", h = 54, press = function() menu:switch("multiplayer", 1) end },
        { id = "howto", label = "HOW TO PLAY", icon = "Book.png", h = 54, press = function() menu:switch("howto", 1) end },
        { id = "settings", label = "SETTINGS", icon = "Gear.png", h = 54, press = function() menu:switch("settings", 1) end },
        { id = "quit", label = "QUIT", icon = "Exit.png", h = 54, press = function() love.event.quit() end }
    }
    for _, element in ipairs(list) do
        element.x, element.y, element.w = M + 24, y, w
        y = y + element.h + 16
    end
    return list
end

local function drawLive(menu, x, y, w)
    local bg = menu.background
    local stats = bg.stats
    if not bg.game or not stats then return end
    local u = UI.unit
    local rows = #bg.feed
    local h = 150 + rows * 22
    y = y - h
    UI.panel(x, y, w, h, { fill = { 0.04, 0.05, 0.09, 0.82 }, accent = UI.colors.bad, cornerAlpha = 0.6 })

    local time = love.timer.getTime()
    UI.color(UI.colors.bad, time % 1.2 < 0.8 and 1 or 0.25)
    UI.block(x + u * 5, y + u * 5, u * 4, u * 4, u)
    UI.text("LIVE", x + u * 12, y + u * 3, 13, UI.colors.bad)
    local name = string.upper(bg.mapName or "")
    local font = Style.font(13)
    UI.text(name, x + w - u * 5 - font:getWidth(name), y + u * 3, 13, UI.colors.text)
    local summary = string.format("%d nations  -  %d tribes  -  %s", stats.nations, stats.tribes, Format.time(bg.game.tick, Config.tickRate))
    UI.text(summary, x + u * 5, y + u * 3 + 24, 11, UI.colors.muted)

    local ly = y + 62
    local top = stats.leaders[1] and stats.leaders[1].tiles or 1
    for k = 1, 3 do
        local player = stats.leaders[k]
        if player then
            local share = player.tiles / math.max(1, stats.land)
            local c = player.color
            UI.color(UI.colors.ink)
            love.graphics.rectangle("fill", x + u * 5, ly + 3, u * 4, u * 4)
            UI.color(c)
            love.graphics.rectangle("fill", x + u * 5 + 2, ly + 5, u * 4 - 4, u * 4 - 4)
            local label = player.name
            local small = Style.font(11)
            while small:getWidth(label) > w * 0.42 and #label > 3 do
                label = label:sub(1, -2)
            end
            UI.text(label, x + u * 11, ly, 11, k == 1 and UI.colors.gold or UI.colors.text)
            local barX = x + math.floor(w * 0.52)
            local barW = w - (barX - x) - u * 18
            UI.color(UI.colors.ink, 0.9)
            love.graphics.rectangle("fill", barX, ly + 4, barW, u * 3)
            UI.color(c)
            local shown = UI.ease("live:" .. k, player.tiles / top, 4)
            love.graphics.rectangle("fill", barX, ly + 4, math.floor(barW * Fx.clamp(shown, 0, 1) / u) * u, u * 3)
            local pct = Format.percent(share)
            UI.text(pct, x + w - u * 5 - small:getWidth(pct), ly, 11, UI.colors.muted)
            ly = ly + 22
        end
    end

    UI.color(UI.colors.edge, 0.25)
    love.graphics.rectangle("fill", x + u * 4, ly + 6, w - u * 8, u)
    ly = ly + 16
    for k, item in ipairs(bg.feed) do
        local age = time - item.time
        local slide = math.floor((1 - Fx.outCubic(age * 3)) * 40 / u) * u
        local text = item.text
        local small = Style.font(11)
        while small:getWidth(text) > w - u * 12 and #text > 3 do
            text = text:sub(1, -2)
        end
        local fade = (k == 1 and 1 or 0.85 - k * 0.12) * math.min(1, age * 4)
        UI.color(item.color, fade)
        love.graphics.rectangle("fill", x + u * 5 + slide, ly + 6, u, u)
        UI.text(text, x + u * 8 + slide, ly, 11, item.color, fade)
        ly = ly + 22
    end
end

function Root.draw(menu, elements, p)
    local W, H = love.graphics.getDimensions()
    local M = margin()
    local time = love.timer.getTime()
    local intro = Fx.clamp((time - menu.openTime) / 1.4, 0, 1)
    local _, th = Title.size()
    local ty = titleY()
    UI.alpha = Fx.outCubic(p)
    Title.draw(M, ty, math.min(intro, p * 2), time, UI.alpha)
    Title.tagline(M + 6, ty + th + 6, (time - menu.openTime - 0.8) / 1.3, 1)

    for k, element in ipairs(elements) do
        local e = menu:stagger(p, k + 1)
        UI.alpha = e
        local dx = math.floor((1 - e) * -40)
        UI.button(element.id, element.x + dx, element.y, element.w, element.h, element.label, {
            hot = menu.focus == element.id,
            primary = element.primary,
            sublabel = element.sublabel,
            icon = element.icon,
            align = "left",
            size = element.primary and 22 or 16,
            hint = element.primary and "ENTER" or nil
        })
    end

    UI.alpha = Fx.outCubic(p)
    UI.text("v1.0  -  UP / DOWN to navigate, ENTER to select", M + 24, H - 40, 11, UI.colors.muted, 0.7)
    local liveW = math.min(400, math.floor(W * 0.3))
    UI.alpha = menu:stagger(p, 6)
    local slide = math.floor((1 - UI.alpha) * 60)
    drawLive(menu, W - M - liveW + slide, H - M, liveW)
    UI.alpha = 1
end

function Root.keyPressed(menu, key)
    if key == "return" or key == "kpenter" then
        if not menu.focus then
            menu:switch("play", 1)
            return true
        end
    end
    return false
end

return Root
