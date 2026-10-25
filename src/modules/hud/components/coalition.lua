local Config = require("src.config.game")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")
local Coalitions = require("src.modules.game.systems.coalitions")

local Panel = { id = "coalition", title = "COALITION", panel = true }

local WIDTH = 280
local PAD = 12
local ROW = 22
local HEAD = 58
local BUTTON_H = 24

local function current(hud)
    local game = hud:game()
    return Coalitions.of(game, game.human)
end

local function buttonRect(x, y, w, h)
    return x + PAD, y + h - BUTTON_H - PAD, w - PAD * 2, BUTTON_H
end

function Panel.visible(hud)
    local game = hud:game()
    return game.phase == "playing" and game.human.alive and current(hud) ~= nil
end

function Panel.size(hud)
    local coalition = current(hud)
    local members = coalition and #coalition.members or 0
    return WIDTH, Style.headerHeight + HEAD + members * ROW + BUTTON_H + PAD * 2
end

function Panel.position(_, w, _, W)
    return W - w - 20, 270
end

function Panel.draw(hud, x, y, w, h)
    local game = hud:game()
    local coalition = current(hud)
    if not coalition then return end
    local u = Pixel.unit
    local top = y + Style.headerHeight + 8
    Pixel.color(Coalitions.color(coalition))
    love.graphics.rectangle("fill", x + PAD, top + 3, u * 2, u * 4)
    Pixel.text(coalition.name, x + PAD + u * 4, top, 13, Style.colors.gold)
    local target = coalition.target
    local goal, bonus, color
    if target then
        goal = string.format("War on %s  %s", target.name, Format.percent(Coalitions.share(game, target)))
        bonus = string.format("-%d%% attack cost against %s", math.floor(Config.coalitionAttackBonus * 100 + 0.5), target.name)
        color = Style.colors.bad
    else
        goal = "Mutual defense"
        bonus = string.format("+%d%% defense against outsiders", math.floor(Config.coalitionDefenseBonus * 100 + 0.5))
        color = Style.colors.good
    end
    if #coalition.members < 2 then
        bonus = "Invite members to activate the bonus"
    end
    Pixel.text(goal, x + PAD, top + 20, 11, color)
    Pixel.text(bonus, x + PAD, top + 34, 10, Style.colors.muted)
    local font = Style.font(11)
    for k, member in ipairs(coalition.members) do
        local ry = top + HEAD - 8 + (k - 1) * ROW
        Style.swatch(member.color, x + PAD, ry + 4, 10)
        local label = member == game.human and (member.name .. " (you)") or member.name
        Pixel.text(label, x + PAD + 16, ry + 1, 11, member == game.human and { 1, 1, 0.7, 1 } or Style.colors.text)
        if member == coalition.leader then
            Pixel.icon("Trophy.png", x + PAD + 20 + font:getWidth(label), ry + 3, 12)
        end
        local share = Format.percent(Coalitions.share(game, member))
        Pixel.text(share, x + w - PAD - font:getWidth(share), ry + 1, 11, Style.colors.muted)
    end
    local bx, by, bw, bh = buttonRect(x, y, w, h)
    local deserting = target ~= nil and target.alive
    Style.button(bx, by, bw, bh, deserting and "Desert (traitor)" or "Leave", { id = "coalition:leave", size = 11, color = Style.colors.bad })
end

function Panel.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    if Style.inside(mx, my, buttonRect(x, y, w, h)) then
        local game = hud:game()
        game:submit({ type = "coalitionLeave", player = game.human.id })
    end
end

return Panel
