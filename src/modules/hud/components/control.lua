local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")

local Control = { id = "control", title = "EMPIRE", panel = true }

local WIDTH = 330
local PAD = 15

local function sliders(hud)
    local human = hud:game().human
    return {
        {
            label = "Troops / Workers",
            value = human.troopRatio,
            color = Style.colors.troops,
            set = function(v) human.troopRatio = v end,
            text = string.format("%d%% / %d%%", math.floor(human.troopRatio * 100 + 0.5), 100 - math.floor(human.troopRatio * 100 + 0.5))
        },
        {
            label = "Attack Ratio",
            value = human.attackRatio,
            color = Style.colors.bad,
            set = function(v) human.attackRatio = math.max(0.01, v) end,
            text = string.format("%d%%  (%s)", math.floor(human.attackRatio * 100 + 0.5), Format.number(human.troops * human.attackRatio))
        }
    }
end

function Control.visible(hud)
    local human = hud:game().human
    return human.spawned and human.alive
end

local MAX_ROWS = 5
local ROW = 22

local function attackRows(hud)
    local game = hud:game()
    local rows = {}
    for _, attack in ipairs(Attack.outgoing(game, game.human)) do
        rows[#rows + 1] = { attack = attack, outgoing = true }
    end
    for _, attack in ipairs(Attack.incoming(game, game.human)) do
        rows[#rows + 1] = { attack = attack, outgoing = false }
    end
    while #rows > MAX_ROWS do
        table.remove(rows)
    end
    return rows
end

function Control.extraHeight(hud)
    local n = #attackRows(hud)
    return n > 0 and n * ROW + 8 or 0
end

function Control.drawExtra(hud, x, y, w)
    local font = Style.font(12)
    love.graphics.setFont(font)
    for k, row in ipairs(attackRows(hud)) do
        local ry = y + (k - 1) * ROW
        local attack = row.attack
        local name
        if row.outgoing then
            name = "> " .. (attack.target and attack.target.name or "Wilderness")
            Style.setColor(Style.colors.text)
        else
            name = "< " .. attack.attacker.name
            Style.setColor(Style.colors.bad)
        end
        love.graphics.print(name, x + PAD, ry + 3)
        local troops = Format.number(attack.troops)
        local right = row.outgoing and 70 or 0
        love.graphics.print(troops, x + w - PAD - right - font:getWidth(troops) - 6, ry + 3)
        if row.outgoing then
            Style.button(x + w - PAD - 64, ry, 64, 19, "Retreat", { size = 11 })
        end
    end
end

function Control.pressExtra(hud, mx, my, x, y, w)
    local game = hud:game()
    for k, row in ipairs(attackRows(hud)) do
        if row.outgoing and Style.inside(mx, my, x + w - PAD - 64, y + (k - 1) * ROW, 64, 19) then
            game:pushIntent({ type = "retreat", player = game.human.id, attack = row.attack.id })
            return
        end
    end
end

function Control.size(hud)
    return WIDTH, Style.headerHeight + 190 + Control.extraHeight(hud)
end

function Control.position(_, w, h, W, H)
    return (W - w) / 2, H - h - 12
end

local function sliderY(y, k)
    return y + Style.headerHeight + 124 + (k - 1) * 36
end

function Control.draw(hud, x, y, w)
    local human = hud:game().human
    local rate = Config.tickRate
    local font = Style.font(12)
    love.graphics.setFont(font)

    local rows = {
        {
            "Population",
            string.format("%s / %s", Format.number(human.troops + human.workers), Format.number(human.maxPopulation)),
            string.format("%+d/s", math.floor(human.growth * rate)),
            Style.colors.troops
        },
        { "Army", Format.number(human.troops), nil, Style.colors.bad },
        { "Workers", Format.number(human.workers), nil, Style.colors.good },
        { "Gold", Format.number(human.gold), string.format("+%s/s", Format.number(human.income * rate)), Style.colors.gold }
    }
    for k, row in ipairs(rows) do
        local ry = y + Style.headerHeight + 8 + (k - 1) * 20
        Style.setColor(Style.colors.muted)
        love.graphics.print(row[1], x + PAD, ry)
        Style.setColor(row[4])
        love.graphics.print(row[2], x + 90, ry)
        if row[3] then
            Style.setColor(Style.colors.muted)
            love.graphics.print(row[3], x + w - PAD - font:getWidth(row[3]), ry)
        end
    end

    for k, s in ipairs(sliders(hud)) do
        local sy = sliderY(y, k)
        Style.setColor(Style.colors.text)
        love.graphics.print(s.label, x + PAD, sy - 18)
        Style.setColor(s.color)
        love.graphics.print(s.text, x + w - PAD - font:getWidth(s.text), sy - 18)
        Style.slider(x + PAD, sy, w - PAD * 2, s.value, s.color, hud.slider and hud.slider.id == s.label)
    end

    if Control.drawExtra then
        Control.drawExtra(hud, x, y + Style.headerHeight + 190, w)
    end
end

function Control.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, s in ipairs(sliders(hud)) do
        if Style.sliderHit(mx, my, x + PAD, sliderY(y, k), w - PAD * 2) then
            hud:startSlider(x + PAD, w - PAD * 2, s.set)
            hud.slider.id = s.label
            return
        end
    end
    if Control.pressExtra then
        Control.pressExtra(hud, mx, my, x, y + Style.headerHeight + 190, w)
    end
end

return Control
