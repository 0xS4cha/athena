local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")

local Events = { id = "events", title = "EVENTS", panel = true }

local WIDTH = 370
local MAX = 7
local MAX_SIMPLE = 4
local PAD = 10
local MARK = 16
local LINE = 15
local ACTION = 24
local TIMER = 6
local REQUEST_GAP = 6
local FADE_TICKS = 20

local seen = setmetatable({}, { __mode = "k" })

local function advanced()
    return not GM.Menu or GM.Menu.settings.advancedEvents == true
end

local function active(hud)
    local game = hud:game()
    local requests, feed = {}, {}
    local limit = advanced() and MAX or MAX_SIMPLE
    for k = #game.events, 1, -1 do
        local event = game.events[k]
        if event.expires > game.tick then
            if event.actions then
                table.insert(requests, 1, event)
            elseif #feed < limit and (advanced() or not event.minor) then
                table.insert(feed, 1, event)
            end
        end
    end
    return requests, feed
end

local function layout(hud)
    local font = Style.font(12)
    local rows = {}
    local height = 0
    local requests, feed = active(hud)
    for _, event in ipairs(requests) do
        local _, lines = font:getWrap(event.text, WIDTH - PAD * 2 - MARK)
        local h = #lines * LINE + 8 + ACTION + TIMER
        rows[#rows + 1] = { event = event, lines = lines, offset = height, height = h, request = true }
        height = height + h + REQUEST_GAP
    end
    for _, event in ipairs(feed) do
        local _, lines = font:getWrap(event.text, WIDTH - PAD * 2 - MARK)
        local h = #lines * LINE + 8
        rows[#rows + 1] = { event = event, lines = lines, offset = height, height = h }
        height = height + h
    end
    return rows, height
end

function Events.visible(hud)
    local requests, feed = active(hud)
    return #requests + #feed > 0
end

function Events.size(hud)
    local _, height = layout(hud)
    return WIDTH, Style.headerHeight + 8 + height
end

function Events.position(_, w, h, W, H)
    return W - w - 16, H - h - 16
end

local function actionRect(x, w, rowY, rowH, index, count)
    local bw = math.min(84, math.floor((w - PAD * 2 - (count - 1) * 6) / count))
    local bx = x + w - PAD - (count - index + 1) * (bw + 6) + 6
    return bx, rowY + rowH - ACTION - TIMER - 2, bw, ACTION - 4
end

local function drawRequest(game, row, x, ry, w, slide, now)
    local u = Pixel.unit
    local event = row.event
    local pulse = 0.5 + 0.5 * math.sin(now * 5)
    local bx, bw = x + u * 2 + slide, w - u * 4
    Pixel.color(Style.colors.gold, 0.1 + 0.08 * pulse)
    Pixel.block(bx, ry - 4, bw, row.height, u)
    Pixel.corners(bx, ry - 4, bw, row.height, Style.colors.gold, 0.5 + 0.5 * pulse)
    local left = Fx.clamp((event.expires - game.tick) / math.max(1, event.duration), 0, 1)
    local barW = bw - u * 6
    local barY = ry + row.height - TIMER - 2
    Pixel.color(Pixel.colors.ink, 0.8)
    love.graphics.rectangle("fill", bx + u * 3, barY, barW, u)
    Pixel.color(left < 0.3 and Style.colors.bad or Style.colors.gold, left < 0.3 and 0.6 + 0.4 * pulse or 0.9)
    love.graphics.rectangle("fill", bx + u * 3, barY, math.floor(barW * left / u) * u, u)
end

function Events.draw(hud, x, y, w)
    local game = hud:game()
    local u = Pixel.unit
    local now = love.timer.getTime()
    local base = Pixel.alpha
    love.graphics.setFont(Style.font(12))
    for _, row in ipairs(layout(hud)) do
        local event = row.event
        if not seen[event] then
            seen[event] = (GM.Flags and GM.Flags.ci) and now - 10 or now
        end
        local age = now - seen[event]
        local slide = math.floor((1 - Fx.outCubic(age / 0.35)) * 70 / u) * u
        local ry = y + Style.headerHeight + 6 + row.offset
        local fade = row.request and 1 or Fx.clamp((event.expires - game.tick) / FADE_TICKS, 0, 1)
        Pixel.alpha = base * fade * Fx.clamp(age * 5, 0, 1)
        if row.request then
            drawRequest(game, row, x, ry, w, slide, now)
        end
        local flash = Fx.clamp(1 - age / 0.6, 0, 1)
        if flash > 0 then
            love.graphics.setColor(event.color[1], event.color[2], event.color[3], 0.25 * flash * Pixel.alpha)
            love.graphics.rectangle("fill", x + u * 2 + slide, ry - 2, w - u * 4, row.height - 2)
        end
        Pixel.color(row.request and Style.colors.gold or event.color)
        love.graphics.rectangle("fill", x + PAD + slide, ry + 5, u * 2, u * 2)
        Style.setColor(row.request and Style.colors.gold or event.color)
        for k, line in ipairs(row.lines) do
            love.graphics.print(line, x + PAD + MARK + slide, ry + (k - 1) * LINE)
        end
        local actions = event.actions
        if row.request then
            for k, action in ipairs(actions) do
                local bx, by, bw, bh = actionRect(x, w, ry, row.height, k, #actions)
                Style.button(bx + slide, by, bw, bh, action.label, { id = "event:" .. event.id .. ":" .. k, size = 11, color = action.color })
            end
        end
    end
    Pixel.alpha = base
end

function Events.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    local game = hud:game()
    for _, row in ipairs(layout(hud)) do
        if row.request then
            local actions = row.event.actions
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
