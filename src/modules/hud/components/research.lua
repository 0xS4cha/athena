local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")
local Research = require("src.modules.game.systems.research")
local Data = require("src.config.research")
local Bar = require("src.modules.hud.components.researchbar")

local Tree = { id = "research", modal = true }

local MAX_W, MAX_H = 1320, 780
local MARGIN = 20
local TOP = 44
local QUEUE_H = 58
local HEADER_H = 26
local DETAIL_H = 134
local PAD = 16
local NODE_GAP = 10
local BRANCH_GAP = 18
local CLICK_GUARD = 0.25

local STATE_COLORS = {
    known = Style.colors.good,
    active = Style.colors.gold,
    queued = Style.colors.gold,
    available = Style.colors.text,
    locked = Style.colors.muted,
    excluded = Style.colors.bad
}

local function branchIndex(id)
    for k, branch in ipairs(Data.branches) do
        if branch.id == id then return k end
    end
    return 1
end

function Tree.layout(x, y, w, h)
    local top = y + TOP + QUEUE_H + HEADER_H
    local bottom = y + h - DETAIL_H - PAD
    local branchW = (w - PAD * 2 - BRANCH_GAP * (#Data.branches - 1)) / #Data.branches
    local nodeW = math.floor((branchW - NODE_GAP) / 2)
    local rows = #Data.tiers
    local rowH = (bottom - top) / rows
    local nodeH = math.floor(math.min(70, rowH - 18))
    return { top = top, bottom = bottom, branchW = branchW, nodeW = nodeW, nodeH = nodeH, rowH = rowH, x = x + PAD }
end

function Tree.nodeRect(l, tech)
    local branchX = l.x + (branchIndex(tech.branch) - 1) * (l.branchW + BRANCH_GAP)
    local nx = branchX + (tech.column - 1) * (l.nodeW + NODE_GAP)
    local ny = l.top + (tech.tier - 1) * l.rowH + (l.rowH - l.nodeH) / 2
    return math.floor(nx), math.floor(ny), l.nodeW, l.nodeH
end

function Tree.effectLines(tech)
    local lines = {}
    for _, field in ipairs(Tree.effectOrder) do
        local value = tech.effects[field]
        if value then
            local def = Data.effects[field]
            local sign = value > 0 and "+" or "-"
            local amount = math.abs(value)
            local text = def.kind == "percent" and string.format("%s%d%%", sign, math.floor(amount * 100 + 0.5))
                or def.kind == "tiles" and string.format("%s%d tiles", sign, amount)
                or string.format("%s%d", sign, amount)
            local good = (value < 0) == (def.lowerIsBetter == true)
            lines[#lines + 1] = { text = text .. "  " .. def.label, good = good }
        end
    end
    return lines
end

Tree.effectOrder = {}
for key in pairs(Data.effects) do
    Tree.effectOrder[#Tree.effectOrder + 1] = key
end
table.sort(Tree.effectOrder)

function Tree.visible(hud)
    if not hud.researchOpen then return false end
    if not Bar.isUsable(hud) then
        hud.researchOpen = false
        return false
    end
    return true
end

function Tree.size()
    local W, H = love.graphics.getDimensions()
    return math.min(MAX_W, W - MARGIN * 2), math.min(MAX_H, H - MARGIN * 2)
end

function Tree.position(_, w, h, W, H)
    return math.floor((W - w) / 2), math.floor((H - h) / 2)
end

local function closeRect(x, y, w)
    return x + w - 40, y + 8, 30, 26
end

local function line(x1, y1, x2, y2, color, alpha)
    local u = Pixel.unit
    Pixel.color(color, alpha)
    if x1 == x2 then
        love.graphics.rectangle("fill", x1 - math.floor(u / 2), math.min(y1, y2), u, math.abs(y2 - y1))
    else
        love.graphics.rectangle("fill", math.min(x1, x2), y1 - math.floor(u / 2), math.abs(x2 - x1) + u, u)
    end
end

local function drawLinks(l, game, human)
    for _, tech in ipairs(Data.list) do
        local parents = tech.requires or tech.requiresAny or {}
        if Research.available(game, tech.id) then
            local cx, cy, cw = Tree.nodeRect(l, tech)
            local tx = cx + math.floor(cw / 2)
            for _, parent in ipairs(parents) do
                local px, py, pw, ph = Tree.nodeRect(l, Data.byId[parent])
                local fx = px + math.floor(pw / 2)
                local fy = py + ph
                local midY = math.floor((fy + cy) / 2)
                local known = human.research.known[parent]
                local color = known and Style.colors.good or Pixel.colors.edge
                local alpha = known and 0.9 or 0.6
                line(fx, fy, fx, midY, color, alpha)
                line(fx, midY, tx, midY, color, alpha)
                line(tx, midY, tx, cy, color, alpha)
            end
        end
    end
end

local function drawNode(hud, l, tech, mx, my, game, human)
    local x, y, w, h = Tree.nodeRect(l, tech)
    local status, position = Research.status(game, human, tech.id)
    if status == "disabled" then return false end
    local hovered = Style.inside(mx, my, x, y, w, h)
    local hot = Pixel.ease("research:" .. tech.id, hovered, 18)
    local u = Pixel.unit
    local color = STATE_COLORS[status]
    local dim = status == "locked" or status == "excluded"
    Pixel.color(Pixel.colors.ink)
    Pixel.block(x, y, w, h, u)
    Pixel.color(status == "known" and Style.colors.good or Pixel.mix(Pixel.colors.raised, Pixel.colors.hover, hot * 0.5), status == "known" and 0.22 or (dim and 0.35 or 0.85))
    Pixel.block(x + u, y + u, w - u * 2, h - u * 2, u)
    if status == "active" or status == "queued" or hovered then
        Pixel.corners(x, y, w, h, hovered and Style.colors.text or Style.colors.gold, 1)
    end
    if tech.group then
        Pixel.color(Style.colors.gold, dim and 0.3 or 0.8)
        love.graphics.rectangle("fill", x + u, y + u, u, h - u * 2)
    end
    local alpha = dim and 0.5 or 1
    Pixel.icon(tech.icon, x + u * 4, y + u * 3, 18, alpha)
    local font = Style.font(11)
    local label = tech.label
    local room = w - u * 4 - 26
    while font:getWidth(label) > room and #label > 3 do label = label:sub(1, -2) end
    Pixel.text(label, x + u * 4 + 22, y + u * 3, 11, dim and Style.colors.muted or Style.colors.text)
    local detail
    if status == "known" then
        detail = "Researched"
    elseif status == "excluded" then
        detail = "Excluded"
    elseif status == "active" then
        local stalled = human.research.stalled
        detail = stalled == "slow" and "Low gold" or stalled and "Stalled" or Bar.remaining(game, human, tech.id)
    elseif status == "queued" then
        detail = string.format("Queue #%d", position)
    else
        detail = Format.number(Research.cost(game, human, tech.id))
    end
    Pixel.text(detail, x + u * 4, y + h - u * 3 - 14, 10, status == "active" and human.research.stalled and human.research.stalled ~= "slow" and Style.colors.bad or color)
    local progress = Research.progress(human, tech.id)
    if status ~= "known" and progress > 0 then
        Pixel.meter("research:node:" .. tech.id, x + u * 2, y + h - u * 3, w - u * 4, u, progress, Style.colors.gold, { instant = true })
    end
    return hovered
end

local function drawOrMarks(l, game)
    local seen = {}
    local font = Style.font(10)
    for _, tech in ipairs(Data.list) do
        if tech.group and not seen[tech.group] and Research.available(game, tech.id) then
            seen[tech.group] = true
            local x, y, w, h = Tree.nodeRect(l, tech)
            local cx = x + w + math.floor(NODE_GAP / 2)
            local cy = y + math.floor(h / 2)
            Pixel.color(Pixel.colors.ink)
            love.graphics.rectangle("fill", cx - 10, cy - 8, 20, 16)
            Pixel.text("OR", cx - math.floor(font:getWidth("OR") / 2), cy - 7, 10, Style.colors.gold)
        end
    end
end

local function drawQueue(hud, x, y, w, game, human)
    local state = human.research
    Pixel.text("QUEUE", x + PAD, y + TOP, 11, Style.colors.muted)
    local cx = x + PAD
    local cy = y + TOP + 16
    local mx, my = love.mouse.getPosition()
    if #state.queue == 0 then
        Pixel.text("Nothing is being researched. Click a technology below.", cx, cy + 6, 13, Style.colors.muted)
    end
    hud.researchChips = {}
    for k, id in ipairs(state.queue) do
        local tech = Data.byId[id]
        local chipW = 186
        local chip = { x = cx, y = cy, w = chipW, h = 34, id = id }
        hud.researchChips[k] = chip
        local hovered = Style.inside(mx, my, chip.x, chip.y, chip.w, chip.h)
        Pixel.color(hovered and Pixel.colors.hover or Pixel.colors.raised, 0.85)
        Pixel.block(chip.x, chip.y, chip.w, chip.h, Pixel.unit)
        Pixel.icon(tech.icon, chip.x + 6, chip.y + 8, 18)
        Pixel.text(tech.label, chip.x + 30, chip.y + 2, 11, k == 1 and Style.colors.gold or Style.colors.text)
        local stalled = k == 1 and state.stalled
        local detail = hovered and "Click to cancel" or stalled == "gold" and "Waiting for gold" or stalled == "slow" and "Slowed: half of your income" or stalled == "capital" and "Paused: capital lost"
            or (k == 1 and Bar.remaining(game, human, id) or Format.number(Research.cost(game, human, id)))
        Pixel.text(detail, chip.x + 30, chip.y + 18, 10, (hovered or (stalled and stalled ~= "slow")) and Style.colors.bad or Style.colors.muted)
        if k == 1 then
            Pixel.meter("research:active", chip.x + 2, chip.y + chip.h - 3, chip.w - 4, 2, Research.progress(human, id), Style.colors.gold, { instant = true })
        end
        cx = cx + chipW + 8
    end
    local summary = string.format("%s gold  -  +%s/s", Format.number(human.gold), Format.number(human.income * Config.tickRate))
    local font = Style.font(13)
    Pixel.text(summary, x + w - PAD - font:getWidth(summary), y + TOP - 2, 13, Style.colors.gold)
end

local function drawDetail(x, y, w, tech, game, human)
    local dy = y
    Pixel.color(Pixel.colors.ink, 0.6)
    Pixel.block(x + PAD, dy, w - PAD * 2, DETAIL_H - PAD, Pixel.unit)
    local tx = x + PAD + 12
    if not tech then
        Pixel.text("Hover a technology to read it.", tx, dy + 10, 14, Style.colors.muted)
        Pixel.text("Click: add to the queue, with what it requires   -   Shift + click: research first   -   Click a queued one: cancel", tx, dy + 34, 11, Style.colors.muted)
        Pixel.text("A gold edge marks a doctrine: you can only adopt one per branch.", tx, dy + 52, 11, Style.colors.muted)
        Pixel.text("Allies who know a technology make it 20% cheaper, and so does it being widespread (15%).", tx, dy + 70, 11, Style.colors.muted)
        Pixel.text("Capturing a capital steals plans; losing yours pauses research. With little gold, research only takes half of your income.", tx, dy + 88, 11, Style.colors.muted)
        return
    end
    local status = Research.status(game, human, tech.id)
    Pixel.text(tech.label, tx, dy + 6, 16, tech.group and Style.colors.gold or Style.colors.text)
    Pixel.text(tech.text, tx, dy + 30, 12, Style.colors.muted)
    for k, effect in ipairs(Tree.effectLines(tech)) do
        Pixel.text(effect.text, tx, dy + 34 + k * 18, 12, effect.good and Style.colors.good or Style.colors.bad)
    end
    local rx = x + math.floor(w * 0.62)
    local friend, common = Research.discounts(game, human, tech.id)
    local seconds = Research.durationTicks(tech.id) / game.rules.research
    local rows = { { "Tier", tostring(tech.tier) }, { "Time", Format.time(seconds, Config.tickRate) } }
    if status ~= "known" then
        local discount = friend and common and "  (-20% ally, -15% common)" or friend and "  (-20% ally)" or common and "  (-15% common)" or ""
        rows[#rows + 1] = { "Cost", Format.number(Research.cost(game, human, tech.id)) .. " gold" .. discount }
    end
    local names = {}
    for _, parent in ipairs(tech.requires or tech.requiresAny or {}) do names[#names + 1] = Data.byId[parent].label end
    if #names > 0 then
        rows[#rows + 1] = { "Requires", table.concat(names, tech.requiresAny and " or " or ", ") }
    end
    for k, row in ipairs(rows) do
        Pixel.text(row[1], rx, dy + 6 + (k - 1) * 22, 12, Style.colors.muted)
        Pixel.text(row[2], rx + 72, dy + 5 + (k - 1) * 22, 12, Style.colors.text)
    end
end

function Tree.draw(hud, x, y, w, h)
    local game = hud:game()
    local human = game.human
    local base = Pixel.alpha
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(0.02, 0.03, 0.06, 0.65 * base)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
    Style.frame(x, y, w, h, nil, { grip = false, accent = Style.colors.gold, cornerAlpha = 0.9 })
    Pixel.shadowText("RESEARCH", x + PAD, y + 8, 20, Style.colors.gold)
    local status = string.format("%d / %d technologies", human.research.count, #Data.list)
    Pixel.text(status, x + PAD + 140, y + 15, 12, Style.colors.muted)
    local mx, my = love.mouse.getPosition()
    local cx, cy, cw, ch = closeRect(x, y, w)
    Style.button(cx, cy, cw, ch, "X", { id = "research:close", hot = Style.inside(mx, my, cx, cy, cw, ch), color = Style.colors.bad, size = 12 })
    drawQueue(hud, x, y, w, game, human)
    local l = Tree.layout(x, y, w, h)
    for k, branch in ipairs(Data.branches) do
        local bx = l.x + (k - 1) * (l.branchW + BRANCH_GAP)
        Pixel.color(branch.color, 0.12)
        love.graphics.rectangle("fill", bx, l.top - HEADER_H + 2, l.branchW, l.bottom - l.top + HEADER_H)
        Pixel.icon(branch.icon, bx + 6, l.top - HEADER_H + 5, 16)
        Pixel.text(branch.label, bx + 28, l.top - HEADER_H + 5, 13, branch.color)
    end
    drawLinks(l, game, human)
    local hovered
    for _, tech in ipairs(Data.list) do
        if drawNode(hud, l, tech, mx, my, game, human) then hovered = tech end
    end
    drawOrMarks(l, game)
    drawDetail(x, l.bottom + 8, w, hovered, game, human)
end

function Tree.plan(game, human, id, first)
    local status = Research.status(game, human, id)
    if status == "active" or status == "queued" then
        return { { type = "researchCancel", player = human.id, tech = id } }
    end
    if not Research.canPlan(game, human, id) then return {} end
    return { { type = "researchQueue", player = human.id, tech = id, first = first and true or nil } }
end

local function click(hud, id)
    local now = love.timer.getTime()
    hud.researchClicks = hud.researchClicks or {}
    if hud.researchClicks[id] and now - hud.researchClicks[id] < CLICK_GUARD then return end
    hud.researchClicks[id] = now
    local game = hud:game()
    local first = love.keyboard.isDown("lshift", "rshift")
    local intents = Tree.plan(game, game.human, id, first)
    if #intents == 0 then
        game:emit("refused")
        return
    end
    for _, intent in ipairs(intents) do
        game:submit(intent)
    end
end

function Tree.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    if not Style.inside(mx, my, x, y, w, h) or Style.inside(mx, my, closeRect(x, y, w)) then
        hud.researchOpen = false
        return
    end
    for _, chip in ipairs(hud.researchChips or {}) do
        if Style.inside(mx, my, chip.x, chip.y, chip.w, chip.h) then
            click(hud, chip.id)
            return
        end
    end
    local l = Tree.layout(x, y, w, h)
    for _, tech in ipairs(Data.list) do
        if Style.inside(mx, my, Tree.nodeRect(l, tech)) and Research.available(hud:game(), tech.id) then
            click(hud, tech.id)
            return
        end
    end
end

function Tree.keyPressed(hud, key)
    if key == "e" then
        if not Bar.isUsable(hud) or hud.settingsOpen or hud.helpOpen then return false end
        hud.researchOpen = not hud.researchOpen
        return true
    end
    if hud.researchOpen then
        if key == "escape" then hud.researchOpen = false end
        return key ~= "p"
    end
    return false
end

return Tree
