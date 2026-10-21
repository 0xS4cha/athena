local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Pixel = require("src.modules.hud.pixel")

local Control = { id = "control", title = "EMPIRE", panel = true }

local WIDTH = 340
local PAD = 15
local BODY = 322
local MAX_ROWS = 5
local ROW = 24

local function sliders(hud)
    local human = hud:game().human
    return {
        {
            id = "troops",
            label = "Troops / Workers",
            value = human.troopRatio,
            color = Style.colors.troops,
            set = function(v) human.troopRatio = v end,
            text = string.format("%d%% / %d%%", math.floor(human.troopRatio * 100 + 0.5), 100 - math.floor(human.troopRatio * 100 + 0.5))
        },
        {
            id = "attack",
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
    return n > 0 and n * ROW + 12 or 0
end

local function rolling(id, value)
    return Format.number(Pixel.ease("control:" .. id, value, 7))
end

function Control.drawExtra(hud, x, y, w)
    local u = Pixel.unit
    local rows = attackRows(hud)
    if #rows == 0 then return end
    Pixel.color(Pixel.colors.edge, 0.3)
    love.graphics.rectangle("fill", x + u * 3, y, w - u * 6, u)
    local font = Style.font(12)
    local blink = love.timer.getTime() % 0.8 < 0.4
    for k, row in ipairs(rows) do
        local ry = y + 8 + (k - 1) * ROW
        local attack = row.attack
        local color = row.outgoing and Style.colors.text or Style.colors.bad
        Pixel.color(row.outgoing and Style.colors.good or Style.colors.bad, row.outgoing and 1 or (blink and 1 or 0.3))
        Pixel.arrow(x + PAD + (row.outgoing and 0 or u * 3), ry + 10, 3, row.outgoing and 1 or -1)
        local name = row.outgoing and (attack.target and attack.target.name or "Wilderness") or attack.attacker.name
        Pixel.text(name, x + PAD + u * 5, ry + 3, 12, color)
        local troops = Format.number(attack.troops)
        local right = row.outgoing and 72 or 0
        Pixel.text(troops, x + w - PAD - right - font:getWidth(troops) - 6, ry + 3, 12, color)
        if row.outgoing then
            Style.button(x + w - PAD - 66, ry, 66, 21, "Retreat", { id = "retreat:" .. attack.id, size = 11, color = Style.colors.bad })
        end
    end
end

function Control.pressExtra(hud, mx, my, x, y, w)
    local game = hud:game()
    for k, row in ipairs(attackRows(hud)) do
        if row.outgoing and Style.inside(mx, my, x + w - PAD - 66, y + 8 + (k - 1) * ROW, 66, 21) then
            game:pushIntent({ type = "retreat", player = game.human.id, attack = row.attack.id })
            return
        end
    end
end

function Control.size(hud)
    return WIDTH, Style.headerHeight + BODY + Control.extraHeight(hud)
end

function Control.position(_, w, h, W, H)
    return (W - w) / 2, H - h - 12
end

local function sliderY(y, k)
    return y + Style.headerHeight + 150 + (k - 1) * 44
end

function Control.draw(hud, x, y, w)
    local human = hud:game().human
    local rate = Config.tickRate
    local u = Pixel.unit
    local font = Style.font(12)
    local top = y + Style.headerHeight + 10

    local rows = {
        { "Population", rolling("population", human.troops + human.workers) .. " / " .. Format.number(human.maxPopulation), string.format("%+d/s", math.floor(human.growth * rate)), Style.colors.troops, "Team.png" },
        { "Army", rolling("army", human.troops), nil, Style.colors.bad, "Skull.png" },
        { "Workers", rolling("workers", human.workers), nil, Style.colors.good, "Hammer.png" },
        { "Gold", rolling("gold", human.gold), "+" .. Format.number(human.income * rate) .. "/s", Style.colors.gold, "Coin.png" }
    }
    for k, row in ipairs(rows) do
        local ry = top + (k - 1) * 22
        Pixel.icon(row[5], x + PAD, ry + 1, 15)
        Pixel.text(row[1], x + PAD + 22, ry, 12, Style.colors.muted)
        Pixel.text(row[2], x + 112, ry, 12, row[4])
        if row[3] then
            Pixel.text(row[3], x + w - PAD - font:getWidth(row[3]), ry, 12, Style.colors.muted)
        end
    end

    local fill = (human.troops + human.workers) / math.max(1, human.maxPopulation)
    Pixel.meter("control:pop", x + PAD, top + 92, w - PAD * 2, 12, fill, Style.colors.troops)
    local split = math.floor(x + PAD + (w - PAD * 2) * fill * human.troopRatio)
    Pixel.color(Pixel.colors.ink, 0.9)
    love.graphics.rectangle("fill", split, top + 89, u, 18)

    for k, s in ipairs(sliders(hud)) do
        local sy = sliderY(y, k)
        Pixel.text(s.label, x + PAD, sy - 28, 12, Style.colors.text)
        Pixel.text(s.text, x + w - PAD - font:getWidth(s.text), sy - 28, 12, s.color)
        Style.slider(x + PAD, sy, w - PAD * 2, s.value, s.color, hud.slider and hud.slider.id == s.id)
    end

    local by = y + Style.headerHeight + 222
    Pixel.text("Biome Adaptation", x + PAD, by, 12, Style.colors.text)
    local cw = math.floor((w - PAD * 2) / 2)
    for k, name in ipairs(Config.biomeOrder) do
        local biome = Config.biomes[name]
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        local bx = x + PAD + col * cw
        local ry = by + 20 + row * 24
        local value = human:familiarity(biome.id)
        Pixel.text(biome.label, bx, ry, 10, Style.colors.muted)
        local text = string.format("%d%%", math.floor(value * 100))
        Pixel.text(text, bx + cw - 12 - Style.font(10):getWidth(text), ry, 10, Style.colors.muted)
        Pixel.meter("control:biome:" .. name, bx, ry + 14, cw - 12, 10, value, biome.color)
    end

    Control.drawExtra(hud, x, y + Style.headerHeight + BODY, w)
end

function Control.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, s in ipairs(sliders(hud)) do
        if Style.sliderHit(mx, my, x + PAD, sliderY(y, k), w - PAD * 2) then
            hud:startSlider(x + PAD, w - PAD * 2, s.set)
            hud.slider.id = s.id
            return
        end
    end
    Control.pressExtra(hud, mx, my, x, y + Style.headerHeight + BODY, w)
end

return Control
