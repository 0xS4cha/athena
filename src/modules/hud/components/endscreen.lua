local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")
local WordArt = require("src.modules.hud.wordart")

local EndScreen = { id = "endscreen", modal = true }

local WIDTH = 440
local TITLE_SCALE = 3
local STATS_TOP = 180
local BUTTON_H = 40
local BUTTON_GAP = 10

local function state(hud)
    local game = hud:game()
    if game.phase == "ended" then
        return game.winner == game.human and "victory" or "ended"
    end
    if not game.human.alive and game.phase == "playing" and not hud.spectating then
        return "defeat"
    end
    return nil
end

local function buttons(hud)
    local game = hud:game()
    local list = {}
    if state(hud) == "defeat" then
        list[#list + 1] = { label = "Keep Watching", icon = "Eye.png", action = function() hud.spectating = true end }
    end
    if not game.lockstep then
        list[#list + 1] = {
            label = "Play Again",
            icon = "Restart.png",
            primary = true,
            action = function()
                local options = {}
                for k, v in pairs(game.options) do options[k] = v end
                options.seed = os.time()
                hud.spectating = false
                GM.Session:Start(options)
            end
        }
    end
    if GM.Menu then
        list[#list + 1] = {
            label = "Main Menu",
            icon = "Home.png",
            action = function()
                hud.spectating = false
                GM.Session:Stop()
                GM.Menu:Open()
            end
        }
    end
    list[#list + 1] = { label = "Quit", icon = "Exit.png", danger = true, action = function() love.event.quit() end }
    return list
end

local function buttonsTop(y)
    return y + STATS_TOP + 3 * 26 + 24
end

local function buttonRect(x, y, w, k)
    return x + 44, buttonsTop(y) + (k - 1) * (BUTTON_H + BUTTON_GAP), w - 80, BUTTON_H
end

function EndScreen.visible(hud)
    return state(hud) ~= nil
end

function EndScreen.size(hud)
    return WIDTH, STATS_TOP + 3 * 26 + 24 + #buttons(hud) * (BUTTON_H + BUTTON_GAP) + 20
end

function EndScreen.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function EndScreen.draw(hud, x, y, w, h)
    local game = hud:game()
    local s = state(hud)
    local age = hud:appeared(EndScreen)
    local base = Pixel.alpha
    local W, H = love.graphics.getDimensions()

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(0.02, 0.03, 0.06, 0.6 * base)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Fx.vignette(0.8 * base)
    if s == "victory" then
        hud.endEmbers = hud.endEmbers or Fx.embers(90)
        Fx.updateEmbers(hud.endEmbers, love.timer.getDelta())
        Fx.drawEmbers(hud.endEmbers, base)
    end
    love.graphics.pop()

    local title, palette, subtitle, accent
    if s == "victory" then
        title, palette, subtitle, accent = "VICTORY", "gold", "You conquered the world.", Style.colors.gold
    elseif s == "defeat" then
        title, palette, subtitle, accent = "DEFEAT", "red", "Your nation has fallen.", Style.colors.bad
    else
        title, palette, subtitle, accent = "GAME OVER", "steel", (game.winner and game.winner.name or "Someone") .. " has won the game.", Style.colors.muted
    end
    Style.frame(x, y, w, h, nil, { accent = accent, cornerAlpha = 1 })
    local tw, th = WordArt.size(title, 22, TITLE_SCALE)
    WordArt.draw(title, x + (w - tw) / 2, y + 12, { size = 22, scale = TITLE_SCALE, palette = palette, progress = age / 0.9 })
    local font = Style.font(14)
    Pixel.text(subtitle, x + (w - font:getWidth(subtitle)) / 2, y + 12 + th, 14, Style.colors.text, Fx.clamp((age - 0.5) * 3, 0, 1))

    local count = Fx.outCubic((age - 0.6) / 1.2)
    local endTick = game.endTick or game.humanDefeatedTick or game.tick
    local stats = {
        { "Time", Format.time(math.floor(endTick * count), Config.tickRate), "Sun.png" },
        { "Peak territory", Format.percent(game.stats.peakTiles / game.map.landCount * count), "Trophy.png" },
        { "Final territory", Format.percent(game.human.tiles / game.map.landCount * count), "Home.png" }
    }
    local u = Pixel.unit
    for k, stat in ipairs(stats) do
        local sy = y + STATS_TOP + (k - 1) * 26
        local e = Fx.outCubic(Fx.clamp((age - 0.5) * 4 - k * 0.4, 0, 1))
        Pixel.alpha = base * e
        local dx = math.floor((1 - e) * 24)
        Pixel.color(Pixel.colors.raised, 0.6)
        Pixel.block(x + 30 + dx, sy - 3, w - 60, 24, u)
        Pixel.icon(stat[3], x + 38 + dx, sy + 1, 15)
        Pixel.text(stat[1], x + 62 + dx, sy, 13, Style.colors.muted)
        local value = stat[2]
        Pixel.text(value, x + w - 40 - font:getWidth(value) + dx, sy, 14, accent)
    end

    local mx, my = love.mouse.getPosition()
    for k, button in ipairs(buttons(hud)) do
        local bx, by, bw, bh = buttonRect(x, y, w, k)
        local e = Fx.outCubic(Fx.clamp((age - 0.8) * 4 - k * 0.35, 0, 1))
        Pixel.alpha = base * e
        Pixel.button("end:" .. button.label, bx + math.floor((1 - e) * -30), by, bw, bh, button.label, {
            hot = hud.endFocus == k or Style.inside(mx, my, bx, by, bw, bh),
            icon = button.icon,
            align = "left",
            size = 14,
            primary = button.primary,
            color = button.danger and Style.colors.bad or nil
        })
    end
    Pixel.alpha = base
end

function EndScreen.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, b in ipairs(buttons(hud)) do
        if Style.inside(mx, my, buttonRect(x, y, w, k)) then
            hud.endFocus = nil
            b.action()
            return
        end
    end
end

function EndScreen.keyPressed(hud, key)
    if not EndScreen.visible(hud) then
        hud.endFocus = nil
        return false
    end
    local list = buttons(hud)
    if key == "up" or key == "down" then
        local focus = hud.endFocus or (key == "down" and 0 or 2)
        hud.endFocus = (focus - 1 + (key == "down" and 1 or -1)) % #list + 1
        return true
    elseif (key == "return" or key == "kpenter") and hud.endFocus then
        local action = list[hud.endFocus].action
        hud.endFocus = nil
        action()
        return true
    end
    return false
end

return EndScreen
