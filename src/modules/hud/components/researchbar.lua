local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")
local Research = require("src.modules.game.systems.research")
local Data = require("src.config.research")

local Bar = { id = "researchbar" }

local X, Y, W, H = 66, 14, 250, 42

function Bar.isUsable(hud)
    local game = hud:game()
    local human = game.human
    return human ~= nil and Research.enabled(game) and game.phase == "playing" and human.alive
        and not game.options.spectator and not hud.spectating
end

function Bar.visible(hud)
    return Bar.isUsable(hud)
end

function Bar.size()
    return W, H
end

function Bar.position()
    return X, Y
end

function Bar.remaining(game, player, id)
    local ticks = (Research.durationTicks(id) - (player.research.progress[id] or 0)) / game.rules.research
    return Format.time(math.max(0, ticks), Config.tickRate)
end

function Bar.draw(hud, x, y)
    local game = hud:game()
    local human = game.human
    local mx, my = love.mouse.getPosition()
    local hovered = Style.inside(mx, my, x, y, W, H)
    Style.box(x, y, W, H, { corners = true, accent = hovered and Style.colors.gold or nil })
    Pixel.icon("Lightbulb.png", x + 8, y + 11, 20)
    local _, id = Research.nextIndex(human)
    local tx = x + 34
    if not id then
        Pixel.text("RESEARCH", tx, y + 5, 13, Style.colors.gold)
        Pixel.text(string.format("%d / %d known  -  press E", human.research.count, #Data.list), tx, y + 23, 10, Style.colors.muted)
        return
    end
    local stalled = human.research.stalled
    local label = Data.byId[id].label
    local warning = stalled and stalled ~= "slow"
    Pixel.text(label, tx, y + 4, 13, warning and Style.colors.bad or Style.colors.text)
    local status = stalled == "gold" and "NO GOLD" or stalled == "slow" and "LOW GOLD" or stalled == "capital" and "NO CAPITAL" or Bar.remaining(game, human, id)
    local font = Style.font(11)
    Pixel.text(status, x + W - 10 - font:getWidth(status), y + 6, 11, warning and Style.colors.bad or Style.colors.gold)
    Pixel.meter("researchbar:progress", tx, y + 26, W - 44, Pixel.unit * 2, Research.progress(human, id), warning and Style.colors.bad or Style.colors.gold, { instant = true })
end

function Bar.mousePressed(hud, _, _, button)
    if button == 1 then
        hud.researchOpen = true
    end
end

return Bar
