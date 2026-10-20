local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")

local EndScreen = { id = "endscreen", modal = true }

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
        list[#list + 1] = { label = "Keep Watching", action = function() hud.spectating = true end }
    end
    list[#list + 1] = {
        label = "Play Again",
        action = function()
            local options = {}
            for k, v in pairs(game.options) do options[k] = v end
            options.seed = os.time()
            hud.spectating = false
            GM.Session:Start(options)
        end
    }
    if GM.Menu then
        list[#list + 1] = {
            label = "Main Menu",
            action = function()
                hud.spectating = false
                GM.Session:Stop()
                GM.Menu:Open()
            end
        }
    end
    list[#list + 1] = { label = "Quit", action = function() love.event.quit() end }
    return list
end

function EndScreen.visible(hud)
    return state(hud) ~= nil
end

function EndScreen.size(hud)
    return 360, 190 + #buttons(hud) * 42
end

function EndScreen.position(_, w, h, W, H)
    return (W - w) / 2, (H - h) / 2
end

function EndScreen.draw(hud, x, y, w, h)
    local game = hud:game()
    local s = state(hud)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    Style.frame(x, y, w, h)

    local title, color, subtitle
    if s == "victory" then
        title, color, subtitle = "VICTORY", Style.colors.gold, "You conquered the world."
    elseif s == "defeat" then
        title, color, subtitle = "DEFEAT", Style.colors.bad, "Your nation has fallen."
    else
        title, color, subtitle = "GAME OVER", Style.colors.bad, (game.winner and game.winner.name or "Someone") .. " has won the game."
    end
    local big = Style.font(30)
    love.graphics.setFont(big)
    Style.setColor(color)
    love.graphics.print(title, x + (w - big:getWidth(title)) / 2, y + 22)
    local font = Style.font(13)
    love.graphics.setFont(font)
    Style.setColor(Style.colors.text)
    love.graphics.print(subtitle, x + (w - font:getWidth(subtitle)) / 2, y + 66)

    local endTick = game.endTick or game.humanDefeatedTick or game.tick
    local stats = {
        { "Time", Format.time(endTick, Config.tickRate) },
        { "Peak territory", Format.percent(game.stats.peakTiles / game.map.landCount) },
        { "Final territory", Format.percent(game.human.tiles / game.map.landCount) }
    }
    for k, stat in ipairs(stats) do
        local sy = y + 96 + (k - 1) * 20
        Style.setColor(Style.colors.muted)
        love.graphics.print(stat[1], x + 40, sy)
        Style.setColor(Style.colors.text)
        love.graphics.print(stat[2], x + w - 40 - font:getWidth(stat[2]), sy)
    end
    for k, button in ipairs(buttons(hud)) do
        Style.button(x + 30, y + 175 + (k - 1) * 42, w - 60, 34, button.label)
    end
end

function EndScreen.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, b in ipairs(buttons(hud)) do
        if Style.inside(mx, my, x + 30, y + 175 + (k - 1) * 42, w - 60, 34) then
            b.action()
            return
        end
    end
end

return EndScreen
