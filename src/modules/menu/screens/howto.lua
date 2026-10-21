local Style = require("src.modules.hud.style")
local Help = require("src.modules.hud.components.help")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")

local HowTo = { id = "howto" }

local PAGES = {
    {
        title = "SPAWN & EXPAND", icon = "Home.png", color = UI.colors.good,
        lines = {
            "Click anywhere on land to pick your starting location, then press SPACE or wait for the countdown.",
            "Your population grows with your territory and cities. Growth is fastest when you are far from the cap.",
            "The slider splits population between troops, who fight, and workers, who earn gold."
        }
    },
    {
        title = "ATTACK", icon = "Skull.png", color = UI.colors.bad,
        lines = {
            "Left click a neighbour or the wilderness to send a share of your troops. The front advances tile by tile.",
            "Plains are cheap, mountains and snow are expensive. Defense posts and fallout raise the cost even more.",
            "Supply lines matter: attacks far from your capital, cities and rails cost up to three times more."
        }
    },
    {
        title = "BUILD", icon = "Hammer.png", color = UI.colors.gold,
        lines = {
            "Right click your land to build. Cities raise your population cap, trade ports and factories earn gold.",
            "Military ports launch invasions overseas and build warships that patrol, scout and blockade.",
            "Defense posts harden your border. Each building of a kind costs more than the last."
        }
    },
    {
        title = "NUKES", icon = "PotionRed.png", color = { 0.45, 0.85, 0.3, 1 },
        lines = {
            "Build a missile silo, then right click a target to launch an Atom Bomb, a Hydrogen Bomb or a MIRV.",
            "Nuked land loses its owner and is covered in fallout that slowly decays and doubles conquest costs.",
            "SAM launchers intercept warheads aimed inside their range."
        }
    },
    {
        title = "DIPLOMACY", icon = "Team.png", color = UI.colors.troops,
        lines = {
            "Right click another nation to request an alliance, send gold or troops, embargo or mark a target.",
            "Alliances expire after five minutes. Breaking one marks you as a traitor and halves your defense.",
            "Win by holding 80% of the land, or by being the last nation standing."
        }
    },
    { title = "CONTROLS", icon = "Keyboard.png", color = UI.colors.hover, controls = true }
}

local function layout()
    local W, H = love.graphics.getDimensions()
    local w = math.min(860, W - 200)
    local h = math.min(420, H - 260)
    return { x = math.floor((W - w) / 2), y = math.floor((H - h) / 2) + 30, w = w, h = h, W = W, H = H }
end

function HowTo.enter(menu)
    menu.page = menu.page or 1
    menu.pageFrom = nil
end

local function turn(menu, delta)
    local page = Fx.clamp(menu.page + delta, 1, #PAGES)
    if page == menu.page then return end
    menu.pageFrom = menu.page
    menu.pageDirection = delta
    menu.page = page
    menu.pageTime = love.timer.getTime()
end

function HowTo.build(menu)
    local l = layout()
    local M = math.max(40, math.floor(l.W * 0.04))
    return {
        { id = "back", x = M, y = 36, w = 150, h = 46, nav = false, press = function() menu:switch("root", -1) end },
        { id = "prev", x = l.x - 76, y = l.y + math.floor(l.h / 2) - 30, w = 52, h = 60, press = function() turn(menu, -1) end, left = function() turn(menu, -1) end, right = function() turn(menu, 1) end },
        { id = "next", x = l.x + l.w + 24, y = l.y + math.floor(l.h / 2) - 30, w = 52, h = 60, press = function() turn(menu, 1) end, left = function() turn(menu, -1) end, right = function() turn(menu, 1) end }
    }
end

local function drawCard(page, x, y, w, h, index)
    local u = UI.unit
    UI.panel(x, y, w, h, { accent = page.color, cornerAlpha = 0.9 })
    local iconBox = 96
    UI.color(UI.colors.ink, 0.8)
    UI.block(x + 30, y + 30, iconBox, iconBox)
    UI.color(page.color, 0.25)
    UI.block(x + 30 + u, y + 30 + u, iconBox - 2 * u, iconBox - 2 * u)
    local bob = math.floor(math.sin(love.timer.getTime() * 2) * 1.5 + 0.5) * u
    UI.icon(page.icon, x + 30 + 16, y + 30 + 16 + bob, iconBox - 32)
    UI.text(string.format("%02d / %02d", index, #PAGES), x + 30 + iconBox + 28, y + 36, 11, UI.colors.muted)
    UI.shadowText(page.title, x + 30 + iconBox + 28, y + 56, 24, page.color)

    local ty = y + 30 + iconBox + 30
    local font = Style.font(17)
    love.graphics.setFont(font)
    if page.controls then
        local half = math.ceil(#Help.lines / 2)
        for k, line in ipairs(Help.lines) do
            local col = k > half and 1 or 0
            local row = (k - 1) % half
            local cx = x + 40 + col * math.floor((w - 60) / 2)
            local cy = ty + row * 30
            local kw = Style.font(12):getWidth(line[1]) + u * 6
            UI.color(UI.colors.ink, 0.9)
            UI.block(cx, cy, kw, 24, u)
            UI.color(UI.colors.raised)
            UI.block(cx + u, cy + u, kw - 2 * u, 24 - 3 * u, u)
            UI.text(line[1], cx + u * 3, cy + 1, 12, UI.colors.gold)
            UI.text(line[2], cx + kw + 12, cy + 1, 12, UI.colors.text)
        end
        return
    end
    for _, line in ipairs(page.lines) do
        UI.color(page.color)
        love.graphics.rectangle("fill", x + 40, ty + 11, u * 2, u * 2)
        UI.color(UI.colors.text)
        love.graphics.printf(line, x + 40 + u * 6, ty, w - 90 - u * 6, "left")
        local _, wrapped = font:getWrap(line, w - 90 - u * 6)
        ty = ty + #wrapped * font:getHeight() + 18
    end
end

function HowTo.draw(menu, elements, p)
    local l = layout()
    local u = UI.unit
    UI.alpha = menu:stagger(p, 1)
    local back = elements[1]
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("HOW TO PLAY", back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text("LEFT / RIGHT to flip through the field manual.", back.x + back.w + 38, 76, 12, UI.colors.muted)

    local e = menu:stagger(p, 2)
    local time = love.timer.getTime()
    local turnT = menu.pageFrom and Fx.clamp((time - menu.pageTime) / 0.4, 0, 1) or 1
    local shift = Fx.outCubic(turnT)
    local direction = menu.pageDirection or 1
    if menu.pageFrom and turnT < 1 then
        UI.alpha = e * (1 - shift)
        drawCard(PAGES[menu.pageFrom], l.x - math.floor(shift * 120 * direction / u) * u, l.y, l.w, l.h, menu.pageFrom)
    end
    UI.alpha = e * shift
    local enter = math.floor((1 - shift) * 120 * direction / u) * u + math.floor((1 - e) * 40)
    drawCard(PAGES[menu.page], l.x + enter, l.y, l.w, l.h, menu.page)

    UI.alpha = menu:stagger(p, 3)
    for k = 2, 3 do
        local element = elements[k]
        local direction = k == 2 and -1 or 1
        local enabled = (direction < 0 and menu.page > 1) or (direction > 0 and menu.page < #PAGES)
        local hot = UI.ease("nav:" .. element.id, menu.focus == element.id and enabled)
        UI.color(UI.colors.ink, enabled and 0.8 or 0.4)
        UI.block(element.x, element.y, element.w, element.h)
        UI.color(UI.mix(UI.colors.raised, UI.colors.hover, hot), enabled and 1 or 0.4)
        UI.block(element.x + u, element.y + u, element.w - 2 * u, element.h - 2 * u)
        UI.color(enabled and UI.colors.text or UI.colors.muted, enabled and 1 or 0.5)
        local ax = element.x + math.floor(element.w / 2) + (direction > 0 and -u * 2 or u * 2) + math.floor(hot * 2) * u * direction
        UI.arrow(ax, element.y + math.floor(element.h / 2), 5, direction)
    end

    local dots = #PAGES
    local dw = u * 5
    local dx = math.floor((l.W - dots * dw) / 2)
    for k = 1, dots do
        local active = UI.ease("dot:" .. k, k == menu.page, 12)
        UI.color(UI.mix(UI.colors.raised, UI.colors.gold, active))
        local size = u * 2 + math.floor(active + 0.5) * u
        love.graphics.rectangle("fill", dx + (k - 1) * dw, l.y + l.h + 30 - size / 2, size, size)
    end
    UI.alpha = 1
end

function HowTo.keyPressed(menu, key)
    if key == "left" or key == "a" then
        turn(menu, -1)
        return true
    elseif key == "right" or key == "d" then
        turn(menu, 1)
        return true
    end
    return false
end

function HowTo.back(menu)
    menu:switch("root", -1)
end

return HowTo
