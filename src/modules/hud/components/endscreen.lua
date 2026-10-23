local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")
local WordArt = require("src.modules.hud.wordart")
local Stats = require("src.modules.game.systems.stats")
local Palette = require("src.modules.player.palette")

local EndScreen = { id = "endscreen", modal = true }

local WIDTH = 640
local TITLE_SCALE = 3
local GRAPH_TOP = 186
local GRAPH_H = 150
local LEGEND_H = 22
local STATS_TOP = GRAPH_TOP + GRAPH_H + LEGEND_H + 22
local STAT_ROWS = 4
local STAT_ROW = 26
local RIVALS = 3
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
    if not game.lockstep or game.lockstep:canControl() then
        list[#list + 1] = {
            label = "Play Again",
            icon = "Restart.png",
            primary = true,
            action = function()
                local options = {}
                for k, v in pairs(game.options) do options[k] = v end
                hud.spectating = false
                if game.lockstep then
                    local name = game.human and game.human.name
                    GM.Session:Stop()
                    GM.Menu:Open()
                    GM.Menu:Launch(game.map.name, nil)
                    GM.Multiplayer:PlaySolo(options, name)
                else
                    options.seed = os.time()
                    GM.Session:Start(options)
                end
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
    return y + STATS_TOP + STAT_ROWS * STAT_ROW + 20
end

local function buttonRect(x, y, w, k)
    return x + 120, buttonsTop(y) + (k - 1) * (BUTTON_H + BUTTON_GAP), w - 240, BUTTON_H
end

local function graphLines(game)
    local history = game.history
    if not history or #history.ticks < 2 then return nil end
    local last = history.tiles[#history.tiles]
    local rivals = {}
    for id, player in ipairs(game.players) do
        if player ~= game.human then
            local peak = 0
            for k = 1, #history.tiles do
                peak = math.max(peak, history.tiles[k][id] or 0)
            end
            if peak > 0 then
                rivals[#rivals + 1] = { player = player, peak = peak, final = last[id] or 0 }
            end
        end
    end
    table.sort(rivals, function(a, b)
        if a.final ~= b.final then return a.final > b.final end
        if a.peak ~= b.peak then return a.peak > b.peak end
        return a.player.id < b.player.id
    end)
    local lines = {}
    for k = 1, math.min(RIVALS, #rivals) do
        local player = rivals[k].player
        lines[#lines + 1] = { player = player, width = 2, color = player:isBot() and Palette.color(player.id) or player.color }
    end
    lines[#lines + 1] = { player = game.human, width = 3, primary = true }
    local land = game.map.landCount
    local top = 0.05
    for _, line in ipairs(lines) do
        local id = line.player.id
        line.values = {}
        for k = 1, #history.tiles do
            local share = (history.tiles[k][id] or 0) / land
            line.values[k] = share
            if share > top then top = share end
        end
    end
    return lines, math.min(1, top * 1.1), history.ticks
end

local function drawGraph(game, x, y, w, h, progress, accent)
    local u = Pixel.unit
    Pixel.color(Pixel.colors.ink, 0.55)
    Pixel.block(x, y, w, h, u)
    local lines, top, ticks = graphLines(game)
    if not lines then
        Pixel.text("Not enough data yet", x + u * 4, y + u * 4, 12, Style.colors.muted)
        return
    end
    local font = Style.font(10)
    local axis = Format.percent(top)
    local left = x + font:getWidth(axis) + u * 5
    local right, bottom, ceiling = x + w - u * 4, y + h - u * 6, y + u * 4
    Pixel.text(axis, x + u * 2, ceiling - 4, 10, Style.colors.muted)
    Pixel.text("0%", x + u * 2, bottom - 8, 10, Style.colors.muted)
    for k = 0, 3 do
        local gy = math.floor(ceiling + (bottom - ceiling) * k / 3)
        Pixel.color(Pixel.colors.raised, 0.5)
        love.graphics.rectangle("fill", left, gy, right - left, 1)
    end
    local first, last = ticks[1], ticks[#ticks]
    local span = math.max(1, last - first)
    local endLabel = Format.time(last, Config.tickRate)
    Pixel.text(Format.time(first, Config.tickRate), left, bottom + 2, 10, Style.colors.muted)
    Pixel.text(endLabel, right - font:getWidth(endLabel), bottom + 2, 10, Style.colors.muted)
    local count = #ticks
    local visible = math.max(2, math.floor(count * Fx.clamp(progress, 0, 1)))
    love.graphics.setLineStyle("rough")
    love.graphics.setLineJoin("bevel")
    for _, line in ipairs(lines) do
        local points = {}
        for k = 1, math.min(visible, count) do
            points[#points + 1] = left + (ticks[k] - first) / span * (right - left)
            points[#points + 1] = bottom - line.values[k] / top * (bottom - ceiling)
        end
        if #points >= 4 then
            local c = line.primary and accent or line.color
            love.graphics.setLineWidth(line.width + 2)
            love.graphics.setColor(0.02, 0.03, 0.06, 0.8 * Pixel.alpha)
            love.graphics.line(points)
            love.graphics.setLineWidth(line.width)
            love.graphics.setColor(c[1], c[2], c[3], Pixel.alpha)
            love.graphics.line(points)
        end
    end
    love.graphics.setLineWidth(1)
    local lx = x
    for k = #lines, 1, -1 do
        local line = lines[k]
        local c = line.primary and accent or line.color
        local label = line.primary and "You" or line.player.name
        if #label > 16 then label = label:sub(1, 15) .. "." end
        Style.swatch(c, lx, y + h + 6, 10)
        Pixel.text(label, lx + 14, y + h + 3, 11, line.primary and Style.colors.text or Style.colors.muted)
        lx = lx + 14 + Style.font(11):getWidth(label) + u * 6
    end
end

function EndScreen.visible(hud)
    return state(hud) ~= nil
end

function EndScreen.size(hud)
    return WIDTH, STATS_TOP + STAT_ROWS * STAT_ROW + 20 + #buttons(hud) * (BUTTON_H + BUTTON_GAP) + 20
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
    drawGraph(game, x + 30, y + GRAPH_TOP, w - 60, GRAPH_H, count, accent)
    local endTick = game.endTick or game.humanDefeatedTick or game.tick
    local counters = game.counters and Stats.counters(game, game.human) or {}
    local function amount(v) return Format.number(math.floor((v or 0) * count)) end
    local stats = {
        { "Time", Format.time(math.floor(endTick * count), Config.tickRate), "Sun.png" },
        { "Peak territory", Format.percent(math.max(game.stats.peakTiles, counters.peakTiles or 0) / game.map.landCount * count), "Trophy.png" },
        { "Final territory", Format.percent(game.human.tiles / game.map.landCount * count), "Home.png" },
        { "Tiles captured", amount(counters.captured), "Unlocked.png" },
        { "Attacks launched", amount(counters.attacks), "Skull.png" },
        { "Buildings", amount(counters.buildings), "Hammer.png" },
        { "Nukes launched", amount(counters.nukes), "PotionRed.png" },
        { "Nations eliminated", amount(counters.eliminations), "Power.png" }
    }
    local u = Pixel.unit
    local colW = math.floor((w - 60 - 12) / 2)
    for k, stat in ipairs(stats) do
        local column = k > STAT_ROWS and 1 or 0
        local row = (k - 1) % STAT_ROWS
        local sx = x + 30 + column * (colW + 12)
        local sy = y + STATS_TOP + row * STAT_ROW
        local e = Fx.outCubic(Fx.clamp((age - 0.5) * 4 - k * 0.25, 0, 1))
        Pixel.alpha = base * e
        local dx = math.floor((1 - e) * 24)
        Pixel.color(Pixel.colors.raised, 0.6)
        Pixel.block(sx + dx, sy - 3, colW, 24, u)
        Pixel.icon(stat[3], sx + 8 + dx, sy + 1, 15)
        Pixel.text(stat[1], sx + 32 + dx, sy, 13, Style.colors.muted)
        local value = stat[2]
        Pixel.text(value, sx + colW - 10 - font:getWidth(value) + dx, sy, 14, accent)
    end
    Pixel.alpha = base

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
