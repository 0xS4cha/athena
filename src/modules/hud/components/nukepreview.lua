local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")
local Interaction = require("src.modules.game.interaction")
local Nukes = require("src.modules.game.systems.nukes")
local Config = require("src.config.game")

local NukePreview = { id = "nukepreview" }

local WIDTH = 270
local ROW = 20

local function current(hud)
    local game = hud:game()
    local camera = hud:camera()
    if not game or not camera then return nil end
    local mx, my = love.mouse.getPosition()
    local mouseTile = game.map:tileAt(camera:toWorld(mx, my))
    local kind, tile = Interaction.previewTarget(game, mouseTile)
    if not kind then return nil end
    return Nukes.preview(game, game.human, kind, tile)
end

local function rows(game, preview)
    local def = preview.def
    local list = {}
    list[#list + 1] = { "Target", preview.target and preview.target.name or "Unclaimed land", Style.colors.text }
    list[#list + 1] = { "Flight time", preview.flight and string.format("%.1fs", preview.flight) or "No silo", Style.colors.text }
    if preview.warheads then
        list[#list + 1] = { "Warheads", tostring(preview.warheads), Style.colors.text }
    end
    list[#list + 1] = { "Destroyed", "~" .. Format.number(preview.total) .. " tiles", Style.colors.gold }
    list[#list + 1] = { "Enemy land", "~" .. Format.number(preview.enemy), Style.colors.good }
    if not preview.warheads then
        list[#list + 1] = { "Friendly fire", preview.friendly >= 1 and ("~" .. Format.number(preview.friendly) .. " tiles") or "None", preview.friendly >= 1 and Style.colors.bad or Style.colors.muted }
    end
    local buildings = preview.enemyBuildings .. " enemy"
    if preview.friendlyBuildings > 0 then
        buildings = buildings .. ", " .. preview.friendlyBuildings .. " yours"
    end
    list[#list + 1] = { "Buildings hit", buildings, preview.friendlyBuildings > 0 and Style.colors.bad or Style.colors.text }
    local interception, color
    if #preview.sams > 0 then
        interception, color = #preview.sams .. " known SAM" .. (#preview.sams > 1 and "s" or ""), Style.colors.bad
    elseif preview.blind then
        interception, color = "Unknown (no radar)", Style.colors.muted
    else
        interception, color = "No SAM in range", Style.colors.good
    end
    list[#list + 1] = { "Interception", interception, color }
    if preview.sheltered then
        list[#list + 1] = { "Shelter", string.format("Bunker: -%d%% casualties", math.floor(Config.units.bunker.shelter * 100 + 0.5)), Style.colors.bad }
    end
    list[#list + 1] = { "Cost", Format.number(def.cost) .. " gold", game.human.gold >= def.cost and Style.colors.text or Style.colors.bad }
    return list
end

function NukePreview.visible(hud)
    return current(hud) ~= nil
end

function NukePreview.draw(hud)
    local game = hud:game()
    local preview = current(hud)
    if not preview then return end
    local u = Pixel.unit
    local list = rows(game, preview)
    local aiming = game.nukeAim ~= nil and game.nukeHover == nil
    local h = 44 + #list * ROW + (preview.ok and 0 or 24) + (aiming and 26 or 0)
    local W, H = love.graphics.getDimensions()
    local x, y
    local menu = hud.contextMenu
    if game.nukeHover and menu.visible then
        local tx, ty = hud:camera():toScreen(preview.x, preview.y)
        local candidates = {
            { menu.x + menu.width + 12, menu.y },
            { menu.x, menu.y + menu:height() + 12 },
            { menu.x - WIDTH - 12, menu.y },
            { menu.x, menu.y - h - 12 }
        }
        x, y = candidates[1][1], candidates[1][2]
        for _, c in ipairs(candidates) do
            local fits = c[1] >= 0 and c[2] >= 0 and c[1] + WIDTH <= W and c[2] + h <= H
            local covers = tx >= c[1] - 30 and tx <= c[1] + WIDTH + 30 and ty >= c[2] - 30 and ty <= c[2] + h + 30
            if fits and not covers then
                x, y = c[1], c[2]
                break
            end
        end
    else
        local mx = love.mouse.getPosition()
        if mx > W / 2 then
            x, y = 16, 360
        else
            x, y = W - WIDTH - 16, 260
        end
    end
    x = math.max(4, math.min(W - WIDTH - 4, x))
    y = math.max(4, math.min(H - h - 4, y))
    local accent = preview.ok and Style.colors.bad or Style.colors.muted
    Style.frame(x, y, WIDTH, h, nil, { accent = accent, cornerAlpha = 1 })
    Pixel.icon(preview.def.icon, x + u * 4, y + 9, 16)
    Pixel.text(string.upper(preview.def.label), x + u * 4 + 22, y + 7, 14, accent)
    if aiming then
        local blink = love.timer.getTime() % 1 < 0.6
        Pixel.text("AIMING", x + WIDTH - 62, y + 9, 11, blink and Style.colors.bad or Style.colors.muted)
    end
    Pixel.color(Pixel.colors.edge, 0.35)
    love.graphics.rectangle("fill", x + u * 3, y + 32, WIDTH - u * 6, u)
    local font = Style.font(12)
    for k, row in ipairs(list) do
        local ry = y + 40 + (k - 1) * ROW
        Pixel.text(row[1], x + u * 5, ry, 12, Style.colors.muted)
        Pixel.text(row[2], x + WIDTH - u * 5 - font:getWidth(row[2]), ry, 12, row[3])
    end
    local fy = y + 44 + #list * ROW
    if not preview.ok then
        Pixel.text("Cannot launch: " .. (preview.reason or "?"), x + u * 5, fy, 12, Style.colors.bad)
        fy = fy + 24
    end
    if aiming then
        Pixel.text("Left click launch  -  Right click / Esc cancel", x + u * 5, fy, 10, Style.colors.muted)
    end
end

return NukePreview
