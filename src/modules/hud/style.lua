local Flags = require("src.modules.hud.flags")

local Style = {}

Style.headerHeight = 26

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

local fonts = {}

Style.fontPath = "assets/fonts/Jersey10-Regular.ttf"
Style.fontScale = 1.4

function Style.font(size)
    size = math.max(8, math.floor(size * Style.fontScale + 0.5))
    if not fonts[size] then
        local font = love.graphics.newFont(Style.fontPath, size, "mono")
        font:setFilter("nearest", "nearest")
        fonts[size] = font
    end
    return fonts[size]
end

function Style.setColor(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

function Style.inside(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Style.box(x, y, w, h)
    Style.setColor(Style.colors.shadow)
    love.graphics.rectangle("fill", x + 3, y + 3, w, h)
    Style.setColor(Style.colors.background)
    love.graphics.rectangle("fill", x, y, w, h)
    Style.setColor(Style.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    Style.setColor(Style.colors.accent)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4)
end

function Style.frame(x, y, w, h, title)
    Style.box(x, y, w, h)
    if title then
        Style.setColor(Style.colors.header)
        love.graphics.rectangle("fill", x + 3, y + 3, w - 6, Style.headerHeight - 2)
        Style.setColor(Style.colors.separator)
        love.graphics.line(x + 3, y + Style.headerHeight + 1, x + w - 3, y + Style.headerHeight + 1)
        Style.setColor(Style.colors.text)
        love.graphics.setFont(Style.font(12))
        love.graphics.print(title, x + 10, y + 6)
    end
end

function Style.button(x, y, w, h, label, options)
    options = options or {}
    local mx, my = love.mouse.getPosition()
    local hovered = not options.disabled and Style.inside(mx, my, x, y, w, h)
    if hovered or options.active then
        Style.setColor(options.color or Style.colors.hover)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("line", x, y, w, h)
    else
        Style.setColor(Style.colors.header)
        love.graphics.rectangle("fill", x, y, w, h)
        Style.setColor(Style.colors.accent)
        love.graphics.rectangle("line", x, y, w, h)
    end
    local font = Style.font(options.size or 12)
    love.graphics.setFont(font)
    Style.setColor(options.disabled and Style.colors.disabled or Style.colors.text)
    love.graphics.print(label, math.floor(x + (w - font:getWidth(label)) / 2), math.floor(y + (h - font:getHeight()) / 2))
    return hovered
end

function Style.slider(x, y, w, value, color, active)
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(0.05, 0.06, 0.09, 1)
    love.graphics.rectangle("fill", x, y - 2, w, 4)
    love.graphics.setColor(0.15, 0.2, 0.3, 1)
    love.graphics.rectangle("line", x, y - 2, w, 4)
    Style.setColor(color, 0.8)
    love.graphics.rectangle("fill", x, y - 2, value * w, 4)

    local hx = x + value * w
    local hovered = Style.inside(mx, my, x - 6, y - 8, w + 12, 16)
    if hovered or active then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", hx - 4, y - 6, 8, 12, 2, 2)
        Style.setColor(color, 1)
        love.graphics.rectangle("line", hx - 4, y - 6, 8, 12, 2, 2)
    else
        love.graphics.setColor(0.8, 0.8, 0.85, 1)
        love.graphics.rectangle("fill", hx - 4, y - 6, 8, 12, 2, 2)
        love.graphics.setColor(0.4, 0.5, 0.6, 1)
        love.graphics.rectangle("line", hx - 4, y - 6, 8, 12, 2, 2)
    end
end

function Style.sliderHit(mx, my, x, y, w)
    return Style.inside(mx, my, x - 6, y - 8, w + 12, 16)
end

function Style.flag(flagKey, x, y, size)
    if not flagKey or flagKey == "" then return false end
    local flag = Flags:Get(flagKey)
    if not flag then return false end
    local fw, fh = flag:getWidth(), flag:getHeight()
    local scale = math.min(size / fw, size / fh)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(flag, x, y + (size - fh * scale) / 2, 0, scale, scale)
    return true
end

function Style.swatch(color, x, y, size)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", x, y, size, size)
end

return Style
