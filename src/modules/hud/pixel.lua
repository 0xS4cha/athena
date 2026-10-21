local Icons = require("src.modules.hud.icons")
local Fx = require("src.modules.hud.fx")

local UI = {}

local floor = math.floor

UI.unit = 3
UI.alpha = 1

UI.colors = {
    ink = { 0.02, 0.03, 0.06, 1 },
    panel = { 0.05, 0.07, 0.11, 0.92 },
    raised = { 0.09, 0.13, 0.21, 0.95 },
    edge = { 0.2, 0.45, 0.8, 1 },
    hover = { 0.1, 0.65, 0.55, 1 },
    text = { 0.9, 0.9, 0.95, 1 },
    muted = { 0.55, 0.6, 0.7, 1 },
    disabled = { 0.38, 0.4, 0.46, 1 },
    gold = { 1, 0.82, 0.25, 1 },
    good = { 0.25, 0.8, 0.45, 1 },
    bad = { 0.95, 0.35, 0.3, 1 },
    troops = { 0.45, 0.75, 1, 1 }
}

UI.fontPath = "assets/fonts/Jersey10-Regular.ttf"
UI.fontScale = 1.4

local fonts = {}

function UI.font(size)
    size = math.max(8, math.floor(size * UI.fontScale + 0.5))
    if not fonts[size] then
        local font = love.graphics.newFont(UI.fontPath, size, "mono")
        font:setFilter("nearest", "nearest")
        fonts[size] = font
    end
    return fonts[size]
end

local eased = {}
local touched = {}
local lastPurge = 0

local function purge(now)
    lastPurge = now
    for id, time in pairs(touched) do
        if now - time > 3 then
            touched[id] = nil
            eased[id] = nil
        end
    end
end

function UI.color(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or c[4] or 1) * UI.alpha)
end

function UI.mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t }
end

function UI.ease(id, target, rate)
    if type(target) ~= "number" then
        target = target and 1 or 0
    end
    local now = love.timer.getTime()
    local value = eased[id] or target
    value = Fx.approach(value, target, rate or 14, math.min(love.timer.getDelta(), 0.1))
    eased[id] = value
    touched[id] = now
    if now - lastPurge > 5 then
        purge(now)
    end
    return value
end

function UI.snap(v)
    return floor(v / UI.unit + 0.5) * UI.unit
end

function UI.block(x, y, w, h, u)
    u = u or UI.unit
    love.graphics.rectangle("fill", x + u, y, w - 2 * u, h)
    love.graphics.rectangle("fill", x, y + u, w, h - 2 * u)
end

function UI.text(text, x, y, size, color, alpha)
    local font = UI.font(size)
    love.graphics.setFont(font)
    UI.color(color or UI.colors.text, alpha)
    love.graphics.print(text, floor(x), floor(y))
    return font:getWidth(text), font:getHeight()
end

function UI.shadowText(text, x, y, size, color, alpha)
    local font = UI.font(size)
    love.graphics.setFont(font)
    UI.color(UI.colors.ink, 0.8 * (alpha or 1))
    love.graphics.print(text, floor(x) + 2, floor(y) + 2)
    UI.color(color or UI.colors.text, alpha)
    love.graphics.print(text, floor(x), floor(y))
    return font:getWidth(text), font:getHeight()
end

function UI.corners(x, y, w, h, color, alpha)
    local u = UI.unit
    local l = u * 4
    UI.color(color, alpha)
    love.graphics.rectangle("fill", x - u, y - u, l, u)
    love.graphics.rectangle("fill", x - u, y - u, u, l)
    love.graphics.rectangle("fill", x + w - l + u, y - u, l, u)
    love.graphics.rectangle("fill", x + w, y - u, u, l)
    love.graphics.rectangle("fill", x - u, y + h, l, u)
    love.graphics.rectangle("fill", x - u, y + h - l + u, u, l)
    love.graphics.rectangle("fill", x + w - l + u, y + h, l, u)
    love.graphics.rectangle("fill", x + w, y + h - l + u, u, l)
end

function UI.panel(x, y, w, h, options)
    options = options or {}
    local u = UI.unit
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    UI.color(UI.colors.ink, 0.45)
    UI.block(x + u * 2, y + u * 2, w, h)
    UI.color(UI.colors.ink)
    UI.block(x, y, w, h)
    UI.color(options.fill or UI.colors.panel)
    UI.block(x + u, y + u, w - 2 * u, h - 2 * u)
    UI.color(UI.colors.edge, 0.3)
    love.graphics.rectangle("fill", x + 2 * u, y + u, w - 4 * u, u)
    UI.color(UI.colors.ink, 0.5)
    love.graphics.rectangle("fill", x + 2 * u, y + h - 2 * u, w - 4 * u, u)
    if options.corners ~= false then
        UI.corners(x, y, w, h, options.accent or UI.colors.edge, options.cornerAlpha or 0.75)
    end
    if options.title then
        UI.text(options.title, x + u * 5, y + u * 3, 12, UI.colors.gold)
        UI.color(UI.colors.edge, 0.35)
        love.graphics.rectangle("fill", x + u * 2, y + u * 3 + 26, w - u * 4, u)
        return y + u * 4 + 28
    end
    return y + u * 2
end

function UI.arrow(x, y, size, direction)
    local u = UI.unit
    for k = 0, size - 1 do
        local height = (size - k) * 2 - 1
        local cx = direction < 0 and x - (k + 1) * u or x + k * u
        love.graphics.rectangle("fill", cx, y - floor(height / 2) * u - floor(u / 2), u, height * u)
    end
end

function UI.icon(name, x, y, size, alpha)
    local image = Icons.get(name)
    if not image then return end
    love.graphics.setColor(1, 1, 1, (alpha or 1) * UI.alpha)
    love.graphics.draw(image, floor(x), floor(y), 0, size / image:getWidth(), size / image:getHeight())
end

function UI.button(id, x, y, w, h, label, options)
    options = options or {}
    local u = UI.unit
    local compact = options.compact
    local t = UI.ease(id, (options.hot or options.active) and not options.disabled)
    local time = love.timer.getTime()
    local accent = options.color or (options.primary and UI.colors.gold or UI.colors.hover)
    local bx = compact and floor(x) or floor(x + floor(t * 3 + 0.5) * u)
    y, w, h = floor(y), floor(w), floor(h)

    UI.color(UI.colors.ink, 0.45)
    UI.block(bx + u * (compact and 1 or 2), y + u * (compact and 1 or 2), w, h)
    UI.color(UI.colors.ink)
    UI.block(bx, y, w, h)
    local fill
    if options.disabled then
        fill = UI.mix(UI.colors.panel, UI.colors.raised, 0.4)
    elseif options.primary then
        fill = UI.mix(UI.mix(UI.colors.raised, accent, 0.18), accent, t)
    else
        fill = UI.mix(UI.colors.raised, accent, t * 0.85)
    end
    UI.color(fill)
    UI.block(bx + u, y + u, w - 2 * u, h - 2 * u)
    love.graphics.setColor(1, 1, 1, (0.08 + 0.18 * t) * UI.alpha)
    love.graphics.rectangle("fill", bx + 2 * u, y + u, w - 4 * u, u)
    UI.color(UI.colors.ink, 0.35)
    love.graphics.rectangle("fill", bx + 2 * u, y + h - 2 * u, w - 4 * u, u)
    if not options.disabled and not compact then
        UI.color(accent, 0.6 + 0.4 * t)
        love.graphics.rectangle("fill", bx + u, y + 2 * u, u * (1 + floor(t * 2 + 0.5)), h - 4 * u)
    end
    if options.primary and not options.disabled then
        local pulse = 0.35 + 0.35 * math.sin(time * 3)
        UI.color(accent, pulse * (1 - t * 0.5))
        love.graphics.rectangle("fill", bx + u, y - u, w - 2 * u, u)
        love.graphics.rectangle("fill", bx + u, y + h, w - 2 * u, u)
        love.graphics.rectangle("fill", bx - u, y + u, u, h - 2 * u)
        love.graphics.rectangle("fill", bx + w, y + u, u, h - 2 * u)
    end

    if t > 0.02 then
        local sweep = ((time * 0.9) % 1.8) / 1.4
        local sx = bx + floor(sweep * w / u) * u
        if sx > bx + 3 * u and sx < bx + w - 6 * u then
            love.graphics.setColor(1, 1, 1, 0.16 * t * UI.alpha)
            love.graphics.rectangle("fill", sx, y + u, u * 2, h - 2 * u)
            love.graphics.rectangle("fill", sx + u * 3, y + u, u, h - 2 * u)
        end
        if not compact then
            local bob = floor(math.sin(time * 7) + 0.5) * u
            UI.color(accent, t)
            UI.arrow(x - u * 6 + bob, y + floor(h / 2), 3, 1)
        end
    end

    local size = options.size or 16
    local font = UI.font(size)
    local textColor = options.disabled and UI.colors.disabled or (((options.primary or options.dark) and t > 0.5) and UI.colors.ink or UI.colors.text)
    local tx = options.align == "left" and bx + u * 7 or bx + floor((w - font:getWidth(label)) / 2)
    if options.icon then
        local iconSize = options.iconSize or floor((h - 8 * u) / u) * u
        local ix = label == "" and bx + floor((w - iconSize) / 2) or bx + u * 6
        UI.icon(options.icon, ix, y + floor((h - iconSize) / 2), iconSize, options.disabled and 0.4 or 1)
        if options.align == "left" then
            tx = tx + iconSize + u * 3
        end
    end
    local ty = floor(y + (h - font:getHeight()) / 2)
    if options.sublabel then
        local small = UI.font(11)
        ty = floor(y + (h - font:getHeight() - small:getHeight() + 4) / 2)
        love.graphics.setFont(small)
        local subColor = (options.primary and t > 0.5) and UI.colors.ink or UI.colors.muted
        UI.color(subColor, 0.9)
        love.graphics.print(options.sublabel, tx, ty + font:getHeight() - 4)
    end
    love.graphics.setFont(font)
    UI.color(textColor)
    love.graphics.print(label, tx, ty)
    if options.hint then
        local small = UI.font(10)
        love.graphics.setFont(small)
        local hw = small:getWidth(options.hint) + u * 4
        local hx = bx + w - hw - u * 4
        local hy = y + floor((h - small:getHeight() - u * 2) / 2)
        UI.color(UI.colors.ink, 0.35 + 0.3 * t)
        UI.block(hx, hy, hw, small:getHeight() + u * 2, u)
        UI.color(textColor, 0.8)
        love.graphics.print(options.hint, hx + u * 2, hy + u)
    end
    return t
end

function UI.field(id, x, y, w, h, text, options)
    options = options or {}
    local u = UI.unit
    local t = UI.ease(id, options.editing)
    local hot = UI.ease(id .. ":hot", options.hot)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    UI.color(UI.colors.ink)
    UI.block(x, y, w, h)
    UI.color(UI.mix(UI.colors.ink, UI.colors.raised, 0.55 + 0.25 * hot))
    UI.block(x + u, y + u, w - 2 * u, h - 2 * u)
    UI.color(UI.mix(UI.colors.edge, UI.colors.gold, t), 0.35 + 0.65 * math.max(t, hot * 0.5))
    love.graphics.rectangle("fill", x + 2 * u, y + h - 2 * u, w - 4 * u, u)
    local tx = x + u * 4
    if options.icon then
        local size = floor((h - 6 * u) / u) * u
        UI.icon(options.icon, tx, y + floor((h - size) / 2), size, 0.6 + 0.4 * t)
        tx = tx + size + u * 3
    end
    local font = UI.font(options.size or 14)
    love.graphics.setFont(font)
    local ty = floor(y + (h - font:getHeight()) / 2) - 1
    if text == "" and options.placeholder then
        UI.color(UI.colors.muted, 0.7)
        love.graphics.print(options.placeholder, tx + (options.editing and u * 4 or 0), ty)
    else
        UI.color(UI.colors.text)
        love.graphics.print(text, tx, ty)
    end
    if options.editing and love.timer.getTime() % 1 < 0.55 then
        local cx = text == "" and tx or tx + font:getWidth(text) + 2
        UI.color(UI.colors.gold)
        love.graphics.rectangle("fill", cx, y + u * 3, u * 2, h - u * 6)
    end
end

function UI.meter(id, x, y, w, h, value, color, options)
    options = options or {}
    local u = UI.unit
    local shown = options.instant and value or UI.ease(id, value, 10)
    local hot = UI.ease(id .. ":hot", options.hot)
    local step = u * 2
    local count = floor((w - u * 2) / step)
    local inner = count * step - u
    x, y = floor(x), floor(y)
    local fullW = inner + u * 2
    UI.color(UI.colors.ink)
    UI.block(x, y, fullW, h, math.min(u, floor(h / 3)))
    local lead = floor(shown * count + 0.5)
    for k = 0, count - 1 do
        if k < lead then
            UI.color(UI.mix(color, { 1, 1, 1, 1 }, k == lead - 1 and 0.35 or 0), 0.8 + 0.2 * hot)
        else
            UI.color(UI.colors.raised, 0.9)
        end
        love.graphics.rectangle("fill", x + u + k * step, y + u, step - u, h - u * 2)
    end
    if options.knob then
        local kx = x + u + lead * step - floor(u / 2)
        UI.color(UI.colors.ink)
        UI.block(kx - u * 2, y - u * 2, u * 5, h + u * 4)
        UI.color(UI.mix(UI.colors.text, color, 1 - hot))
        UI.block(kx - u, y - u, u * 3, h + u * 2)
    end
    return fullW
end

function UI.toggle(id, x, y, value, hot)
    local u = UI.unit
    local t = UI.ease(id, value, 16)
    local h = UI.ease(id .. ":hot", hot)
    local w, hh = u * 14, u * 7
    x, y = floor(x), floor(y)
    UI.color(UI.colors.ink)
    UI.block(x, y, w, hh)
    UI.color(UI.mix(UI.colors.raised, UI.colors.good, t))
    UI.block(x + u, y + u, w - 2 * u, hh - 2 * u)
    local kx = x + u + floor(t * 7 + 0.5) * u
    UI.color(UI.colors.ink)
    UI.block(kx, y, u * 6, hh)
    UI.color(UI.mix(UI.colors.muted, UI.colors.text, math.max(t, h)))
    UI.block(kx + u, y + u, u * 4, hh - 2 * u)
    return w, hh
end

function UI.segments(id, x, y, w, h, labels, index, options)
    options = options or {}
    local u = UI.unit
    local count = #labels
    local sw = floor(w / count)
    local pos = UI.ease(id, index, 16)
    local hot = UI.ease(id .. ":hot", options.hot)
    x, y = floor(x), floor(y)
    UI.color(UI.colors.ink)
    UI.block(x, y, sw * count, h)
    UI.color(UI.colors.raised, 0.85)
    UI.block(x + u, y + u, sw * count - 2 * u, h - 2 * u)
    local hx = x + floor((pos - 1) * sw / u + 0.5) * u
    UI.color(options.color or UI.colors.hover, 0.85 + 0.15 * hot)
    UI.block(hx + u, y + u, sw - 2 * u, h - 2 * u)
    love.graphics.setColor(1, 1, 1, 0.2 * UI.alpha)
    love.graphics.rectangle("fill", hx + 2 * u, y + u, sw - 4 * u, u)
    local font = UI.font(options.size or 13)
    love.graphics.setFont(font)
    for k, label in ipairs(labels) do
        local active = 1 - math.min(1, math.abs(pos - k))
        UI.color(UI.mix(UI.colors.muted, UI.colors.text, active))
        love.graphics.print(label, x + (k - 1) * sw + floor((sw - font:getWidth(label)) / 2), y + floor((h - font:getHeight()) / 2))
    end
end

function UI.chip(x, y, label, icon, color)
    local u = UI.unit
    local font = UI.font(11)
    local h = font:getHeight() + u * 3
    local iconSize = icon and h - u * 4 or 0
    local w = font:getWidth(label) + u * 6 + (icon and iconSize + u * 2 or 0)
    x, y = floor(x), floor(y)
    UI.color(UI.colors.ink, 0.85)
    UI.block(x, y, w, h)
    UI.color(UI.colors.raised, 0.9)
    UI.block(x + u, y + u, w - 2 * u, h - 2 * u)
    local tx = x + u * 3
    if icon then
        UI.icon(icon, tx, y + u * 2, iconSize)
        tx = tx + iconSize + u * 2
    end
    love.graphics.setFont(font)
    UI.color(color or UI.colors.text)
    love.graphics.print(label, tx, y + floor((h - font:getHeight()) / 2))
    return w, h
end

function UI.hotspot(element, mx, my)
    return mx >= element.x and mx <= element.x + element.w and my >= element.y and my <= element.y + element.h
end

return UI
