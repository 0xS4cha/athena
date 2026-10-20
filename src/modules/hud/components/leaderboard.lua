local Style = require("src.modules.hud.style")
local Format = require("src.core.format")

local Leaderboard = { id = "leaderboard", title = "LEADERBOARD", panel = true }

local WIDTH = 290
local ROW = 20
local TOP = 10

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
    return WIDTH, Style.headerHeight + 30 + #list * ROW
end

function Leaderboard.position()
    return 16, 60
end

function Leaderboard.draw(hud, x, y, w)
    local game = hud:game()
    local list, alive = rows(hud)
    local font = Style.font(11)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    Style.setColor(Style.colors.muted)
    local header = string.format("%d alive", alive)
    love.graphics.print(header, x + w - 12 - font:getWidth(header), y + 7)
    local hy = y + Style.headerHeight + 6
    love.graphics.print("#", x + 10, hy)
    love.graphics.print("Name", x + 56, hy)
    love.graphics.print("Land", x + 186, hy)
    love.graphics.print("Troops", x + 232, hy)

    for k, row in ipairs(list) do
        local ry = y + Style.headerHeight + 24 + (k - 1) * ROW
        local player = row.player
        if Style.inside(mx, my, x + 4, ry - 2, w - 8, ROW) then
            Style.setColor(Style.colors.hover, 0.35)
            love.graphics.rectangle("fill", x + 4, ry - 2, w - 8, ROW)
        elseif player == game.human then
            love.graphics.setColor(1, 1, 0.6, 0.1)
            love.graphics.rectangle("fill", x + 4, ry - 2, w - 8, ROW)
        end
        Style.setColor(Style.colors.muted)
        love.graphics.print(tostring(row.rank), x + 10, ry + 1)
        Style.swatch(player.color, x + 28, ry + 3, 10)
        if player.flag then
            Style.flag(player.flag, x + 42, ry + 1, 13)
        end
        local name = player.name
        while font:getWidth(name) > 115 and #name > 3 do
            name = name:sub(1, -2)
        end
        if name ~= player.name then name = name .. "." end
        if player == game.human then
            love.graphics.setColor(1, 1, 0.7, 1)
        elseif player:isAlliedWith(game.human) then
            Style.setColor(Style.colors.good)
        else
            Style.setColor(Style.colors.text)
        end
        love.graphics.print(name, x + 60, ry + 1)
        Style.setColor(Style.colors.text)
        love.graphics.print(Format.percent(player.tiles / game.map.landCount), x + 186, ry + 1)
        love.graphics.print(Format.number(player.troops), x + 232, ry + 1)
    end
end

function Leaderboard.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, row in ipairs(rows(hud)) do
        local ry = y + Style.headerHeight + 24 + (k - 1) * ROW
        if Style.inside(mx, my, x + 4, ry - 2, w - 8, ROW) then
            local camera = hud:camera()
            camera:zoom(math.max(1, 4 / camera.scale))
            camera:centerOn(row.player:center())
            return
        end
    end
end

return Leaderboard
