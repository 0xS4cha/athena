local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Palette = require("src.modules.player.palette")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")

local Play = { id = "play" }

local ROW = 30
local DIFFICULTIES = { "easy", "medium", "hard" }
local DIFFICULTY_LABELS = { "Easy", "Medium", "Hard" }
local MAX_BOTS = 400
local CONTROLS_H = 300

local function difficultyIndex(menu)
    for k, d in ipairs(DIFFICULTIES) do
        if menu.settings.difficulty == d then return k end
    end
    return 2
end

function Play.layout()
    local W, H = love.graphics.getDimensions()
    local M = math.max(40, math.floor(W * 0.04))
    local top = 112
    local listW = math.max(240, math.min(340, math.floor(W * 0.24)))
    local list = { x = M, y = top, w = listW, h = H - top - M }
    local panel = { x = list.x + listW + 30, y = top }
    panel.w = W - panel.x - M
    panel.h = list.h
    local rows = { x = list.x + 12, y = list.y + 66, w = list.w - 24 }
    rows.h = list.y + list.h - 14 - rows.y
    local preview = { x = panel.x + 18, y = panel.y + 18, w = panel.w - 36 }
    preview.h = panel.h - CONTROLS_H - 36
    return { M = M, list = list, panel = panel, rows = rows, preview = preview }
end

function Play.visibleRows()
    local l = Play.layout()
    return math.max(1, math.floor(l.rows.h / ROW))
end

function Play.enter(menu)
    menu.editing = "search"
    menu:revealPreview()
end

local function textHandler(menu, field)
    return function(_, text)
        if text then
            local limit = field == "name" and 24 or 32
            if field == "name" then
                if #menu.settings.name < limit and text:match("^[%w%s%-_%.']$") then
                    menu.settings.name = menu.settings.name .. text
                end
            elseif #menu.search < limit and text:match("^[%w%s%-']$") then
                menu.search = menu.search .. text
                menu:refreshFilter()
            end
        elseif field == "name" then
            menu.settings.name = menu.settings.name:sub(1, -2)
        else
            menu.search = menu.search:sub(1, -2)
            menu:refreshFilter()
        end
    end
end

function Play.build(menu)
    local l = Play.layout()
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - CONTROLS_H + 12
    local half = math.floor((cw - 24) / 2)
    local function moveSelection(delta)
        return function() menu:moveSelection(delta) end
    end
    return {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() menu:switch("root", -1) end },
        {
            id = "search", x = l.list.x + 12, y = l.list.y + 14, w = l.list.w - 24, h = 40,
            press = function() menu.editing = "search" end,
            text = textHandler(menu, "search"), up = moveSelection(-1), down = moveSelection(1)
        },
        {
            id = "list", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
            press = function(_, _, my) Play.clickRow(menu, my) end,
            up = moveSelection(-1), down = moveSelection(1)
        },
        {
            id = "name", x = cx, y = cy + 22, w = half, h = 42,
            press = function() menu.editing = "name" end,
            text = textHandler(menu, "name")
        },
        {
            id = "nations", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 42,
            press = function() menu.settings.nations = not menu.settings.nations end,
            left = function() menu.settings.nations = false end,
            right = function() menu.settings.nations = true end
        },
        {
            id = "bots", x = cx, y = cy + 108, w = cw, h = 24,
            drag = function(_, mx)
                local pct = Fx.clamp((mx - cx) / cw, 0, 1)
                menu.settings.bots = math.floor(pct * MAX_BOTS / 5 + 0.5) * 5
            end,
            left = function() menu.settings.bots = math.max(0, menu.settings.bots - 10) end,
            right = function() menu.settings.bots = math.min(MAX_BOTS, menu.settings.bots + 10) end
        },
        {
            id = "difficulty", x = cx, y = cy + 166, w = cw, h = 40,
            press = function(_, mx)
                if not mx then
                    menu.settings.difficulty = DIFFICULTIES[difficultyIndex(menu) % #DIFFICULTIES + 1]
                    return
                end
                local k = Fx.clamp(math.floor((mx - cx) / (cw / #DIFFICULTIES)) + 1, 1, #DIFFICULTIES)
                menu.settings.difficulty = DIFFICULTIES[k]
            end,
            left = function() menu.settings.difficulty = DIFFICULTIES[math.max(1, difficultyIndex(menu) - 1)] end,
            right = function() menu.settings.difficulty = DIFFICULTIES[math.min(#DIFFICULTIES, difficultyIndex(menu) + 1)] end
        },
        { id = "start", x = cx, y = cy + 222, w = cw, h = 58, press = function() menu:start() end }
    }
end

function Play.clickRow(menu, my)
    local l = Play.layout()
    local k = math.floor((my - l.rows.y) / ROW) + 1
    local index = menu.filtered[k + menu.scroll]
    if not index then return end
    local now = love.timer.getTime()
    if index == menu.selected and menu.lastClick and now - menu.lastClick < 0.4 then
        menu:start()
        return
    end
    menu:select(index)
    menu.lastClick = now
end

local function find(elements, id)
    for _, element in ipairs(elements) do
        if element.id == id then return element end
    end
end

local function drawStar(x, y, color)
    local u = 2
    UI.color(color)
    love.graphics.rectangle("fill", x + u * 2, y, u, u * 5)
    love.graphics.rectangle("fill", x, y + u * 2, u * 5, u)
    love.graphics.rectangle("fill", x + u, y + u, u * 3, u * 3)
end

function Play.drawList(menu, l, e)
    local u = UI.unit
    local mx, my = love.mouse.getPosition()
    local rows = l.rows
    local visible = Play.visibleRows()
    love.graphics.setScissor(rows.x - u * 4, rows.y, rows.w + u * 8, rows.h)
    for k = 1, visible + 1 do
        local index = menu.filtered[k + menu.scroll]
        if not index then break end
        local map = menu.maps[index]
        local rowIn = Fx.clamp(e * 2 - k * 0.04, 0, 1)
        local ry = rows.y + (k - 1) * ROW
        local dx = math.floor((1 - Fx.outCubic(rowIn)) * -24 / u) * u
        local selected = index == menu.selected
        local hovered = UI.hotspot({ x = rows.x, y = ry, w = rows.w, h = ROW - 2 }, mx, my) and my < rows.y + rows.h
        local hot = UI.ease("row:" .. index, selected and 1 or (hovered and 0.45 or 0), 18)
        UI.alpha = rowIn * e
        if hot > 0.01 then
            UI.color(selected and UI.colors.hover or UI.colors.raised, 0.25 + 0.6 * hot)
            UI.block(rows.x + dx, ry, rows.w, ROW - 3, u)
            if selected then
                UI.color(UI.colors.gold)
                love.graphics.rectangle("fill", rows.x + dx, ry + u, u, ROW - 3 - 2 * u)
            end
        end
        local tx = rows.x + dx + u * 4 + math.floor(hot * 2) * u
        if map.featured then
            drawStar(tx, ry + 9, UI.colors.gold)
            tx = tx + 16
        end
        UI.text(map.name, tx, ry + 4, 13, selected and UI.colors.text or (map.featured and UI.colors.gold or UI.colors.text), selected and 1 or 0.85)
    end
    love.graphics.setScissor()
    UI.alpha = e
    local total = #menu.filtered
    if total > visible then
        local trackH = rows.h
        local thumbH = math.max(24, math.floor(trackH * visible / total))
        local thumbY = rows.y + math.floor((trackH - thumbH) * menu.scroll / math.max(1, total - visible))
        UI.color(UI.colors.ink, 0.7)
        love.graphics.rectangle("fill", rows.x + rows.w + u * 2, rows.y, u, trackH)
        UI.color(UI.colors.edge, 0.8)
        love.graphics.rectangle("fill", rows.x + rows.w + u * 2, thumbY, u, thumbH)
    elseif total == 0 then
        UI.text("No map matches.", rows.x + u * 4, rows.y + 6, 13, UI.colors.muted)
    end
end

function Play.drawPreview(menu, l, e, map, nations)
    map = map or menu:current()
    if not map then return end
    if nations == nil then nations = menu.settings.nations end
    local u = UI.unit
    local area = l.preview
    local image = menu:preview(map)
    local time = love.timer.getTime()
    local reveal = Fx.clamp((time - menu.previewTime) / 0.45, 0, 1)
    if not image then return end
    local scale = math.min(area.w / image:getWidth(), area.h / image:getHeight())
    local iw, ih = math.floor(image:getWidth() * scale), math.floor(image:getHeight() * scale)
    local ix, iy = area.x + math.floor((area.w - iw) / 2), area.y + math.floor((area.h - ih) / 2)
    local shown = math.floor(ih * Fx.outCubic(reveal) / u) * u

    UI.color(UI.colors.ink)
    UI.block(ix - u * 2, iy - u * 2, iw + u * 4, ih + u * 4)
    if shown > 0 then
        love.graphics.setScissor(ix, iy, iw, shown)
        love.graphics.setColor(1, 1, 1, e)
        love.graphics.draw(image, ix, iy, 0, scale, scale)
        love.graphics.setScissor()
    end
    if reveal < 1 then
        UI.color(UI.colors.troops, 0.9)
        love.graphics.rectangle("fill", ix, iy + shown - u, iw, u)
        UI.color(UI.colors.troops, 0.3)
        love.graphics.rectangle("fill", ix, iy + shown - u * 4, iw, u * 3)
    end
    UI.corners(ix - u * 2, iy - u * 2, iw + u * 4, ih + u * 4, UI.colors.gold, 0.7)

    menu.markers = {}
    local m = map.manifest
    if nations and reveal > 0.6 then
        local sx, sy = iw / m.map.width, ih / m.map.height
        local mx, my = love.mouse.getPosition()
        local hovered
        for k, nation in ipairs(m.nations or {}) do
            if nation.coordinates then
                local delay = 0.6 + (k / math.max(1, #m.nations)) * 0.5
                local pop = Fx.clamp((time - menu.previewTime - delay) / 0.2, 0, 1)
                if pop > 0 then
                    local px = ix + math.floor(nation.coordinates[1] * sx)
                    local py = iy + math.floor(nation.coordinates[2] * sy)
                    local size = math.floor((2 + Fx.outBack(pop)) * 2)
                    local c = Palette.color(k + 1)
                    UI.color(UI.colors.ink, e)
                    love.graphics.rectangle("fill", px - size / 2 - 1, py - size / 2 - 1, size + 2, size + 2)
                    UI.color(c, e)
                    love.graphics.rectangle("fill", px - size / 2, py - size / 2, size, size)
                    if math.abs(mx - px) < 8 and math.abs(my - py) < 8 then
                        hovered = { nation = nation, x = px, y = py, color = c }
                    end
                end
            end
        end
        if hovered then
            local font = Style.font(12)
            local label = hovered.nation.name
            local w = font:getWidth(label) + 46
            local tx = math.min(hovered.x + 12, ix + iw - w)
            local ty = hovered.y - 40
            UI.color(UI.colors.ink, 0.95)
            UI.block(tx, ty, w, 30)
            UI.color(hovered.color)
            love.graphics.rectangle("fill", tx + u, ty + u, u, 30 - 2 * u)
            Style.flag(hovered.nation.flag, tx + 10, ty + 7, 16)
            UI.text(label, tx + 32, ty + 5, 12, UI.colors.text)
        end
    end
end

function Play.drawChips(l, map, nations, bots)
    if not map then return end
    local u = UI.unit
    local m = map.manifest
    local nationCount = #(m.nations or {})
    local opponents = (nations and nationCount or 0) + bots
    local chips = {
        { string.upper(map.name), "Home.png", UI.colors.gold },
        { string.format("%d x %d", m.map.width, m.map.height), "Monitor.png" },
        { Format.number(m.map.num_land_tiles or 0) .. " land", "Flower.png" },
        { string.format("%d nations", nationCount), "Team.png" },
        { string.format("%d rivals", opponents), "Skull.png", opponents == 0 and UI.colors.bad or nil }
    }
    local cx = l.panel.x + 24
    local cy = l.panel.y + l.panel.h - CONTROLS_H - 18
    for _, chip in ipairs(chips) do
        local w = UI.chip(cx, cy, chip[1], chip[2], chip[3])
        cx = cx + w + u * 3
    end
end

function Play.draw(menu, elements, p)
    local l = Play.layout()
    local u = UI.unit
    local s = menu.settings
    local map = menu:current()

    UI.alpha = menu:stagger(p, 1)
    local back = find(elements, "back")
    UI.button("back", back.x, back.y, back.w, back.h, "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    UI.shadowText("NEW GAME", back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text("Pick a battlefield and set up your rivals.", back.x + back.w + 38, 76, 12, UI.colors.muted)

    local e = menu:stagger(p, 2)
    UI.alpha = e
    local dx = math.floor((1 - e) * -40)
    UI.panel(l.list.x + dx, l.list.y, l.list.w, l.list.h, {})
    local search = find(elements, "search")
    UI.field("search", search.x + dx, search.y, search.w, search.h, menu.search, {
        editing = menu.editing == "search",
        hot = menu.focus == "search",
        placeholder = string.format("Search %d maps...", #menu.maps),
        icon = "MagnifyingGlass.png",
        size = 13
    })
    love.graphics.push()
    love.graphics.translate(dx, 0)
    Play.drawList(menu, l, e)
    love.graphics.pop()

    e = menu:stagger(p, 3)
    UI.alpha = e
    local dy = math.floor((1 - e) * 30)
    love.graphics.push()
    love.graphics.translate(0, dy)
    UI.panel(l.panel.x, l.panel.y, l.panel.w, l.panel.h, { accent = UI.colors.gold, cornerAlpha = 0.5 })
    Play.drawPreview(menu, l, e)
    Play.drawChips(l, map, s.nations, s.bots)
    love.graphics.pop()

    e = menu:stagger(p, 4)
    UI.alpha = e
    love.graphics.push()
    love.graphics.translate(0, math.floor((1 - e) * 40))
    local name = find(elements, "name")
    UI.text("COMMANDER", name.x, name.y - 22, 11, UI.colors.muted)
    UI.field("name", name.x, name.y, name.w, name.h, s.name, { editing = menu.editing == "name", hot = menu.focus == "name", icon = "Pencil.png", placeholder = "Player" })

    local nations = find(elements, "nations")
    local nationCount = map and #(map.manifest.nations or {}) or 0
    UI.text("NATIONS", nations.x, nations.y - 22, 11, UI.colors.muted)
    local nhot = UI.ease("nations:hot", menu.focus == "nations")
    UI.color(UI.colors.raised, 0.4 + 0.4 * nhot)
    UI.block(nations.x, nations.y, nations.w, nations.h)
    local tw = UI.toggle("nations", nations.x + u * 3, nations.y + math.floor((nations.h - u * 7) / 2), s.nations, menu.focus == "nations")
    UI.text(s.nations and string.format("%d historical nations", nationCount) or "Disabled", nations.x + tw + u * 7, nations.y + 9, 13, s.nations and UI.colors.text or UI.colors.muted)

    local bots = find(elements, "bots")
    UI.text("WILD TRIBES", bots.x, bots.y - 26, 11, UI.colors.muted)
    local botsText = tostring(s.bots)
    local font = Style.font(13)
    UI.text(botsText, bots.x + bots.w - font:getWidth(botsText), bots.y - 30, 13, UI.colors.troops)
    UI.meter("bots", bots.x, bots.y, bots.w, bots.h, s.bots / MAX_BOTS, UI.colors.troops, { knob = true, hot = menu.focus == "bots" or menu.dragging == "bots" })

    local difficulty = find(elements, "difficulty")
    UI.text("DIFFICULTY", difficulty.x, difficulty.y - 22, 11, UI.colors.muted)
    local dcolors = { UI.colors.good, UI.colors.hover, UI.colors.bad }
    local index = difficultyIndex(menu)
    UI.segments("difficulty", difficulty.x, difficulty.y, difficulty.w, difficulty.h, DIFFICULTY_LABELS, index, { hot = menu.focus == "difficulty", color = dcolors[index] })

    local start = find(elements, "start")
    UI.button("start", start.x, start.y, start.w, start.h, "START GAME", { hot = menu.focus == "start", primary = true, size = 20, icon = "Play.png", hint = "ENTER" })
    love.graphics.pop()
    UI.alpha = 1
end

function Play.keyPressed(menu, key)
    if key == "return" or key == "kpenter" then
        if menu.focus == "back" then return false end
        menu:start()
        return true
    end
    if (key == "up" or key == "down") and (menu.focus == nil or menu.focus == "list") then
        menu:moveSelection(key == "up" and -1 or 1)
        return true
    end
    if key == "pageup" or key == "pagedown" then
        menu:moveSelection((key == "pageup" and -1 or 1) * Play.visibleRows())
        return true
    end
    return false
end

function Play.wheel(menu, y)
    local maxScroll = math.max(0, #menu.filtered - Play.visibleRows())
    menu.scroll = Fx.clamp(menu.scroll - y * 3, 0, maxScroll)
end

function Play.back(menu)
    menu:switch("root", -1)
end

return Play
