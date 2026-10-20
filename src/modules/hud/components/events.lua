local Style = require("src.modules.hud.style")

local Events = { id = "events", title = "EVENTS", panel = true }

local WIDTH = 360
local MAX = 7
local PAD = 10
local LINE = 15
local ACTION = 22

local function active(hud)
    local game = hud:game()
    local list = {}
    for k = #game.events, 1, -1 do
        local event = game.events[k]
        if event.actions or event.expires > game.tick then
            table.insert(list, 1, event)
            if #list >= MAX then break end
        end
    end
    return list
end

local function layout(hud)
    local font = Style.font(12)
    local rows = {}
    local height = 0
    for _, event in ipairs(active(hud)) do
        local _, lines = font:getWrap(event.text, WIDTH - PAD * 2)
        local h = #lines * LINE + 6 + (event.actions and ACTION or 0)
        rows[#rows + 1] = { event = event, lines = lines, offset = height, height = h }
        height = height + h
    end
    return rows, height
end

function Events.visible(hud)
    return #active(hud) > 0
end

function Events.size(hud)
    local _, height = layout(hud)
    return WIDTH, Style.headerHeight + 8 + height
end

function Events.position(_, w, h, W, H)
    return W - w - 16, H - h - 16
end

local function actionRect(x, w, rowY, rowH, index, count)
    local bw = 80
    local bx = x + w - PAD - (count - index + 1) * (bw + 6) + 6
    return bx, rowY + rowH - ACTION - 2, bw, ACTION - 4
end

function Events.draw(hud, x, y, w)
    local font = Style.font(12)
    love.graphics.setFont(font)
    for _, row in ipairs(layout(hud)) do
        local ry = y + Style.headerHeight + 6 + row.offset
        Style.setColor(row.event.color)
        for k, line in ipairs(row.lines) do
            love.graphics.print(line, x + PAD, ry + (k - 1) * LINE)
        end
        local actions = row.event.actions
        if actions then
            for k, action in ipairs(actions) do
                local bx, by, bw, bh = actionRect(x, w, ry, row.height, k, #actions)
                Style.button(bx, by, bw, bh, action.label, { size = 11, color = action.color })
            end
        end
    end
end

function Events.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    local game = hud:game()
    for _, row in ipairs(layout(hud)) do
        local actions = row.event.actions
        if actions then
            local ry = y + Style.headerHeight + 6 + row.offset
            for k, action in ipairs(actions) do
                if Style.inside(mx, my, actionRect(x, w, ry, row.height, k, #actions)) then
                    game:removeEvent(row.event)
                    action.run()
                    return
                end
            end
        end
    end
end

return Events
