local Flags = require("src.modules.hud.flags")
local Pixel = require("src.modules.hud.pixel")

local Style = {}

local floor = math.floor

Style.headerHeight = 26
Style.pixel = Pixel

Style.colors = {
    shadow = { 0, 0, 0, 0.45 },
    background = { 0.06, 0.08, 0.12, 0.95 },
    border = { 0, 0, 0, 1 },
    accent = { 0.2, 0.45, 0.8, 0.6 },
    header = { 0.1, 0.15, 0.25, 0.9 },
    separator = { 0.2, 0.45, 0.8, 0.3 },
    hover = { 0.1, 0.65, 0.55, 0.8 },
    text = { 0.9, 0.9, 0.95, 1 },
    muted = { 0.55, 0.6, 0.7, 1 },
    disabled = { 0.38, 0.4, 0.46, 1 },
    good = { 0.3, 0.85, 0.45, 1 },
    bad = { 0.95, 0.35, 0.3, 1 },
    gold = { 1, 0.82, 0.25, 1 },
    troops = { 0.45, 0.75, 1, 1 }
}

Style.fontPath = Pixel.fontPath
Style.fontScale = Pixel.fontScale
Style.font = Pixel.font

function Style.setColor(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], (alpha or c[4] or 1) * Pixel.alpha)
end

function Style.inside(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Style.box(x, y, w, h, options)
    options = options or {}
    Pixel.panel(x, y, w, h, { corners = options.corners or false, accent = options.accent, fill = options.fill })
end

function Style.frame(x, y, w, h, title, options)
    options = options or {}
    local u = Pixel.unit
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    Pixel.panel(x, y, w, h, { accent = options.accent, cornerAlpha = options.cornerAlpha or 0.55 })
    if title then
        Pixel.color(Pixel.colors.raised, 0.9)
        love.graphics.rectangle("fill", x + u, y + u, w - 2 * u, Style.headerHeight - u)
        Pixel.color(options.accent or Pixel.colors.edge, 0.45)
        love.graphics.rectangle("fill", x + u, y + Style.headerHeight, w - 2 * u, u)
        Pixel.color(options.accent or Pixel.colors.gold)
        love.graphics.rectangle("fill", x + u * 3, y + floor(Style.headerHeight / 2) - u, u * 2, u * 2)
        Pixel.text(title, x + u * 7, y + 5, 12, options.titleColor or Pixel.colors.gold)
        if options.grip ~= false then
            Pixel.color(Pixel.colors.muted, 0.35)
            for k = 0, 2 do
                love.graphics.rectangle("fill", x + w - u * (5 + k * 3), y + floor(Style.headerHeight / 2) - u, u, u * 2)
            end
        end
    end
end

function Style.button(x, y, w, h, label, options)
    options = options or {}
    local mx, my = love.mouse.getPosition()
    local hovered = not options.disabled and Style.inside(mx, my, x, y, w, h)
    Pixel.button(options.id or string.format("button:%s:%d:%d", label, floor(x), floor(y)), x, y, w, h, label, {
        compact = options.compact ~= false,
        hot = hovered,
        active = options.active,
        color = options.color,
        disabled = options.disabled,
        icon = options.icon,
        iconSize = options.iconSize,
        size = options.size or 12,
        primary = options.primary,
        align = options.align,
        hint = options.hint
    })
    return hovered
end

function Style.slider(x, y, w, value, color, active)
    local mx, my = love.mouse.getPosition()
    local hovered = Style.sliderHit(mx, my, x, y, w)
    Pixel.meter(string.format("slider:%d:%d", floor(x), floor(y)), x, y - 6, w, 12, value, color, { knob = true, hot = hovered or active, instant = true })
end

function Style.sliderHit(mx, my, x, y, w)
    return Style.inside(mx, my, x - 6, y - 10, w + 12, 20)
end

function Style.flag(flagKey, x, y, size)
    if not flagKey or flagKey == "" then return false end
    local flag = Flags:Get(flagKey)
    if not flag then return false end
    local fw, fh = flag:getWidth(), flag:getHeight()
    local scale = math.min(size / fw, size / fh)
    love.graphics.setColor(1, 1, 1, Pixel.alpha)
    love.graphics.draw(flag, x, y + (size - fh * scale) / 2, 0, scale, scale)
    return true
end

function Style.swatch(color, x, y, size)
    x, y = floor(x), floor(y)
    Pixel.color(Pixel.colors.ink)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(color[1], color[2], color[3], Pixel.alpha)
    love.graphics.rectangle("fill", x + 2, y + 2, size - 4, size - 4)
    love.graphics.setColor(1, 1, 1, 0.35 * Pixel.alpha)
    love.graphics.rectangle("fill", x + 2, y + 2, size - 4, 2)
end

return Style
