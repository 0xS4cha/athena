local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")

local Leaderboard = { id = "leaderboard", title = "LEADERBOARD", panel = true }

local WIDTH = 300
local ROW = 22
local TOP = 10

local MEDALS = {
    { 1, 0.82, 0.25, 1 },
    { 0.78, 0.82, 0.9, 1 },
    { 0.85, 0.52, 0.3, 1 }
}

local function rows(hud)
    local game = hud:game()
    local list = {}
    for _, player in ipairs(game.players) do
        if player.alive and player.tiles > 0 then
            list[#list + 1] = player
        end
    end
    table.sort(list, function(a, b)
        if a.tiles == b.tiles then return a.id < b.id end
        return a.tiles > b.tiles
    end)
    local result = {}
    local humanShown = false
    for k = 1, math.min(TOP, #list) do
        result[#result + 1] = { rank = k, player = list[k] }
        if list[k] == game.human then humanShown = true end
    end
    if not humanShown and game.human.alive then
        for k = TOP + 1, #list do
            if list[k] == game.human then
                result[#result + 1] = { rank = k, player = game.human }
            end
        end
    end
    return result, #list
end

function Leaderboard.visible(hud)
    return hud:game().phase ~= "spawn"
end

function Leaderboard.size(hud)
    local list = rows(hud)
    return WIDTH, Style.headerHeight + 32 + #list * ROW
end

function Leaderboard.position()
    return 16, 64
end

function Leaderboard.draw(hud, x, y, w)
    local game = hud:game()
    local list, alive = rows(hud)
    local font = Style.font(11)
    local u = Pixel.unit
    local mx, my = love.mouse.getPosition()

    local header = string.format("%d alive", alive)
    Pixel.text(header, x + w - u * 12 - font:getWidth(header), y + 7, 11, Style.colors.muted)
    local hy = y + Style.headerHeight + 7
    Pixel.text("#", x + 12, hy, 11, Style.colors.muted)
    Pixel.text("Name", x + 62, hy, 11, Style.colors.muted)
    Pixel.text("Land", x + 196, hy, 11, Style.colors.muted)
    Pixel.text("Troops", x + 242, hy, 11, Style.colors.muted)

    local top = list[1] and list[1].player.tiles or 1
    local base = y + Style.headerHeight + 26
    for k, row in ipairs(list) do
        local player = row.player
        local slot = Pixel.ease("lb:slot:" .. player.id, k, 9)
        local ry = math.floor(base + (slot - 1) * ROW)
        local hovered = Style.inside(mx, my, x + 4, base + (k - 1) * ROW, w - 8, ROW - 2)
        local hot = Pixel.ease("lb:hot:" .. player.id, hovered, 18)
        local share = Pixel.ease("lb:share:" .. player.id, player.tiles / top, 6)
        local c = player.color
        local barW = math.floor((w - u * 4) * share / u) * u
        love.graphics.setColor(c[1], c[2], c[3], (0.14 + 0.12 * hot) * Pixel.alpha)
        love.graphics.rectangle("fill", x + u * 2, ry, barW, ROW - 3)
        if player == game.human then
            love.graphics.setColor(1, 1, 0.6, 0.1 * Pixel.alpha)
            love.graphics.rectangle("fill", x + u * 2, ry, w - u * 4, ROW - 3)
            Pixel.color(Style.colors.gold)
            love.graphics.rectangle("fill", x + u * 2, ry + u, u, ROW - 3 - u * 2)
        end
        if hot > 0.01 then
            Pixel.color(Pixel.colors.hover, 0.35 * hot)
            love.graphics.rectangle("fill", x + u * 2, ry, w - u * 4, ROW - 3)
        end
        local medal = MEDALS[row.rank]
        if medal then
            Pixel.color(Pixel.colors.ink)
            Pixel.block(x + 7, ry + 2, 16, ROW - 7, 2)
            Pixel.color(medal)
            Pixel.block(x + 8, ry + 3, 14, ROW - 9, 2)
            Pixel.text(tostring(row.rank), x + 12, ry + 1, 11, Pixel.colors.ink)
        else
            Pixel.text(tostring(row.rank), x + 10, ry + 2, 11, Style.colors.muted)
        end
        Style.swatch(player.color, x + 30, ry + 5, 10)
        if player.flag then
            Style.flag(player.flag, x + 44, ry + 2, 13)
        end
        local name = player.name
        while font:getWidth(name) > 115 and #name > 3 do
            name = name:sub(1, -2)
        end
        if name ~= player.name then name = name .. "." end
        local color = Style.colors.text
        if player == game.human then
            color = { 1, 1, 0.7, 1 }
        elseif player:isAlliedWith(game.human) then
            color = Style.colors.good
        end
        Pixel.text(name, x + 62 + math.floor(hot * 2) * u, ry + 2, 11, color)
        Pixel.text(Format.percent(player.tiles / game.map.landCount), x + 196, ry + 2, 11, Style.colors.text)
        Pixel.text(Format.number(player.troops), x + 242, ry + 2, 11, Style.colors.text)
    end
end

function Leaderboard.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, row in ipairs(rows(hud)) do
        local ry = y + Style.headerHeight + 26 + (k - 1) * ROW
        if Style.inside(mx, my, x + 4, ry, w - 8, ROW - 2) then
            local camera = hud:camera()
            camera:zoom(math.max(1, 4 / camera.scale))
            camera:centerOn(row.player:center())
            return
        end
    end
end

return Leaderboard
