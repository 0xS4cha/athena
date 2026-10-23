local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Pixel = require("src.modules.hud.pixel")
local Loans = require("src.modules.game.systems.loans")

local Control = { id = "control", title = "EMPIRE", panel = true }

local WIDTH = 360
local PAD = 15
local MAX_ROWS = 5
local ROW = 24
local TILE_H = 58
local TILE_GAP = 6
local TILES_H = TILE_H * 2 + TILE_GAP
local SLIDERS_Y = 10 + TILES_H + 40
local BIOMES_Y = SLIDERS_Y + 64
local BODY = BIOMES_Y + 42
local FLASH_SECONDS = 0.7
local FLASH_CHANGE = 0.04
local FULL_POPULATION = 0.98

local flashes = {}

local function sliders(hud)
    local human = hud:game().human
    return {
        {
            id = "troops",
            label = "Troops / Workers",
            value = human.troopRatio,
            color = Style.colors.troops,
            set = function(v) hud:game():submit({ type = "troopRatio", player = human.id, ratio = v }) end,
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

local function loanRows(hud)
    local game = hud:game()
    return Loans.involving(game, game.human)
end

local function sectionHeight(count)
    return count > 0 and count * ROW + 12 or 0
end

function Control.extraHeight(hud)
    return sectionHeight(#attackRows(hud)) + sectionHeight(#loanRows(hud))
end

local function rolling(id, value)
    return Format.number(Pixel.ease("control:" .. id, value, 7))
end

local function drawLoans(hud, x, y, w)
    local game = hud:game()
    local human = game.human
    local u = Pixel.unit
    local rows = loanRows(hud)
    if #rows == 0 then return end
    Pixel.color(Pixel.colors.edge, 0.3)
    love.graphics.rectangle("fill", x + u * 3, y, w - u * 6, u)
    for k, loan in ipairs(rows) do
        local ry = y + 8 + (k - 1) * ROW
        local owing = loan.borrower == human
        local other = owing and loan.lender or loan.borrower
        local color = owing and Style.colors.bad or Style.colors.good
        Pixel.icon("Coin.png", x + PAD, ry + 3, 15)
        local label = (owing and "Owe " or "Lent ") .. other.name
        local font = Style.font(11)
        while font:getWidth(label) > 112 and #label > 4 do
            label = label:sub(1, -2)
        end
        Pixel.text(label, x + PAD + 20, ry + 3, 11, color)
        local left = Format.number(Loans.remaining(loan)) .. "  " .. Format.time(math.max(0, loan.deadline - game.tick), Config.tickRate)
        local right = owing and 72 or 0
        Pixel.text(left, x + w - PAD - right - font:getWidth(left) - 6, ry + 3, 11, Style.colors.muted)
        Pixel.meter("loan:" .. loan.id, x + PAD + 20, ry + 15, 112, 9, loan.paid / loan.due, Style.colors.gold)
        if owing then
            Style.button(x + w - PAD - 66, ry, 66, 21, "Repay", { id = "repay:" .. loan.id, size = 11, color = Style.colors.gold, disabled = human.gold < 1 })
        end
    end
end

local function pressLoans(hud, mx, my, x, y, w)
    local game = hud:game()
    for k, loan in ipairs(loanRows(hud)) do
        if loan.borrower == game.human and Style.inside(mx, my, x + w - PAD - 66, y + 8 + (k - 1) * ROW, 66, 21) then
            game:submit({ type = "loanRepay", player = game.human.id, target = loan.lender.id })
            return true
        end
    end
    return false
end

function Control.drawExtra(hud, x, y, w)
    drawLoans(hud, x, y + sectionHeight(#attackRows(hud)), w)
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
    if pressLoans(hud, mx, my, x, y + sectionHeight(#attackRows(hud)), w) then return end
    local game = hud:game()
    for k, row in ipairs(attackRows(hud)) do
        if row.outgoing and Style.inside(mx, my, x + w - PAD - 66, y + 8 + (k - 1) * ROW, 66, 21) then
            game:submit({ type = "retreat", player = game.human.id, attack = row.attack.id })
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
    return y + Style.headerHeight + SLIDERS_Y + (k - 1) * 44
end

local function rateText(value)
    local perSecond = value * Config.tickRate
    if math.abs(perSecond) < 0.5 then return "+0/s" end
    return (perSecond < 0 and "-" or "+") .. Format.number(math.abs(perSecond)) .. "/s"
end

local function track(id, value)
    local flash = flashes[id]
    if not flash then
        flashes[id] = { value = value, time = -10, up = true }
        return 0, true
    end
    local change = value - flash.value
    if math.abs(change) > math.max(1, math.abs(flash.value)) * FLASH_CHANGE then
        flash.time = love.timer.getTime()
        flash.up = change > 0
    end
    flash.value = value
    return math.max(0, 1 - (love.timer.getTime() - flash.time) / FLASH_SECONDS), flash.up
end

local function drawTile(tile, x, y, w, h)
    local u = Pixel.unit
    local now = love.timer.getTime()
    local flash, up = track(tile.id, tile.value)
    Pixel.color(Pixel.colors.ink, 0.9)
    Pixel.block(x, y, w, h, u)
    Pixel.color(Pixel.colors.raised)
    Pixel.block(x + u, y + u, w - u * 2, h - u * 2, u)
    if flash > 0 then
        Pixel.color(up and Style.colors.good or Style.colors.bad, 0.35 * flash)
        Pixel.block(x + u, y + u, w - u * 2, h - u * 2, u)
    end
    Pixel.color(tile.color)
    love.graphics.rectangle("fill", x + u, y + u * 2, u, h - u * 4)
    if tile.alert then
        Pixel.corners(x, y, w, h, tile.alertColor, 0.5 + 0.5 * math.sin(now * 7))
    end
    Pixel.icon(tile.icon, x + u * 4, y + 6, 14)
    Pixel.text(tile.label, x + u * 4 + 19, y + 5, 10, Style.colors.muted)
    local small = Style.font(10)
    if tile.rate then
        Pixel.text(tile.rate, x + w - u * 4 - small:getWidth(tile.rate), y + 5, 10, tile.rateColor or Style.colors.muted)
    end
    local big = Style.font(19)
    local valueText = Format.number(Pixel.ease("control:" .. tile.id, tile.value, 7))
    Pixel.text(valueText, x + u * 4, y + 20, 19, tile.color)
    if tile.suffix then
        Pixel.text(tile.suffix, x + u * 4 + big:getWidth(valueText) + 4, y + 28, 10, Style.colors.muted)
    end
    if tile.fill then
        Pixel.meter("control:tile:" .. tile.id, x + u * 3, y + h - u * 5, w - u * 6, u * 3, tile.fill, tile.fillColor or tile.color)
    end
end

local function tiles(hud)
    local game = hud:game()
    local human = game.human
    local population = human.troops + human.workers
    local fill = population / math.max(1, human.maxPopulation)
    local full = fill >= FULL_POPULATION
    local attacked = #Attack.incoming(game, human) > 0
    local crippled = human.capitalLostUntil and human.capitalLostUntil > game.tick
    local unpaid = not human.upkeepPaid
    local GOOD, BAD = Style.colors.good, Style.colors.bad
    local function sign(value) return value < 0 and BAD or GOOD end
    return {
        {
            id = "population", label = crippled and "POP - HALVED" or "POPULATION", icon = "Team.png", color = Style.colors.troops,
            value = population, suffix = "/ " .. Format.number(human.maxPopulation),
            rate = full and "FULL" or rateText(human.growth), rateColor = full and Style.colors.gold or sign(human.growth),
            fill = fill, fillColor = full and Style.colors.gold or Style.colors.troops,
            alert = full or crippled, alertColor = crippled and BAD or Style.colors.gold
        },
        {
            id = "gold", label = unpaid and "GOLD - UNPAID" or "GOLD", icon = "Coin.png", color = Style.colors.gold,
            value = human.gold, rate = rateText(human.income), rateColor = sign(human.income),
            alert = unpaid, alertColor = BAD
        },
        {
            id = "army", label = attacked and "ARMY - ATTACKED" or "ARMY", icon = "Skull.png", color = BAD,
            value = human.troops, rate = rateText(human.growth * human.troopRatio), rateColor = sign(human.growth),
            fill = human.troops / math.max(1, population), alert = attacked, alertColor = BAD
        },
        {
            id = "workers", label = "WORKERS", icon = "Hammer.png", color = GOOD,
            value = human.workers, rate = rateText(human.growth * (1 - human.troopRatio)), rateColor = sign(human.growth),
            fill = human.workers / math.max(1, population)
        }
    }
end

function Control.draw(hud, x, y, w)
    local human = hud:game().human
    local font = Style.font(12)
    local top = y + Style.headerHeight + 10

    local tw = math.floor((w - PAD * 2 - TILE_GAP) / 2)
    for k, tile in ipairs(tiles(hud)) do
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        drawTile(tile, x + PAD + col * (tw + TILE_GAP), top + row * (TILE_H + TILE_GAP), tw, TILE_H)
    end

    for k, s in ipairs(sliders(hud)) do
        local sy = sliderY(y, k)
        Pixel.text(s.label, x + PAD, sy - 28, 12, Style.colors.text)
        Pixel.text(s.text, x + w - PAD - font:getWidth(s.text), sy - 28, 12, s.color)
        Style.slider(x + PAD, sy, w - PAD * 2, s.value, s.color, hud.slider and hud.slider.id == s.id)
    end

    local by = y + Style.headerHeight + BIOMES_Y
    Pixel.text("Biome Adaptation", x + PAD, by, 11, Style.colors.muted)
    local count = #Config.biomeOrder
    local cw = math.floor((w - PAD * 2) / count)
    for k, name in ipairs(Config.biomeOrder) do
        local biome = Config.biomes[name]
        local bx = x + PAD + (k - 1) * cw
        local value = human:familiarity(biome.id)
        local text = string.format("%d%%", math.floor(value * 100))
        Pixel.text(biome.label, bx, by + 16, 10, Style.colors.muted)
        Pixel.text(text, bx + cw - 8 - Style.font(10):getWidth(text), by + 16, 10, value >= 1 and Style.colors.text or Style.colors.muted)
        Pixel.meter("control:biome:" .. name, bx, by + 30, cw - 8, 8, value, biome.color)
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
