local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")

local WordArt = {}

local SPACING = 1
local PAD = 6

WordArt.palettes = {
    gold = { extrude = { 0.12, 0.2, 0.4 }, deep = { 0.08, 0.12, 0.25 }, base = { 0.88, 0.62, 0.18 }, light = { 1, 0.86, 0.38 }, shine = { 1, 0.97, 0.78 } },
    red = { extrude = { 0.32, 0.06, 0.08 }, deep = { 0.2, 0.04, 0.06 }, base = { 0.82, 0.2, 0.16 }, light = { 1, 0.42, 0.32 }, shine = { 1, 0.78, 0.68 } },
    steel = { extrude = { 0.12, 0.16, 0.26 }, deep = { 0.08, 0.1, 0.18 }, base = { 0.55, 0.62, 0.75 }, light = { 0.78, 0.84, 0.94 }, shine = { 0.96, 0.98, 1 } }
}

local canvases = {}

local function glyphs(text, font)
    local list = {}
    local x = PAD
    for k = 1, #text do
        local ch = text:sub(k, k)
        list[k] = { ch = ch, x = x }
        x = x + font:getWidth(ch) + SPACING
    end
    return list, x - SPACING + PAD
end

function WordArt.size(text, fontSize, scale)
    local font = Pixel.font(fontSize)
    local _, width = glyphs(text, font)
    return width * scale, (font:getHeight() + PAD * 2) * scale
end

local function drawLetters(list, p, time, color, dx, dy)
    for k, glyph in ipairs(list) do
        local e = Fx.clamp(p * 1.8 - (k - 1) * 0.13, 0, 1)
        if e > 0 then
            local drop = math.floor((1 - Fx.outBack(e)) * -14)
            local bob = math.floor(math.sin(time * 1.6 + k * 0.7) * 0.6 + 0.5)
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * math.min(1, e * 3))
            love.graphics.print(glyph.ch, glyph.x + dx, PAD + drop + bob + dy)
        end
    end
end

function WordArt.draw(text, x, y, options)
    local size = options.size or 22
    local scale = options.scale or 4
    local p = options.progress or 1
    local time = options.time or love.timer.getTime()
    local palette = WordArt.palettes[options.palette or "gold"]
    local font = Pixel.font(size)
    local list, width = glyphs(text, font)
    local height = font:getHeight() + PAD * 2
    local key = text .. ":" .. size
    local canvas = canvases[key]
    if not canvas then
        canvas = love.graphics.newCanvas(width, height)
        canvas:setFilter("nearest", "nearest")
        canvases[key] = canvas
    end

    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setFont(font)
    drawLetters(list, p, time, palette.extrude, 0, 3)
    drawLetters(list, p, time, palette.deep, 0, 2)
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
        drawLetters(list, p, time, { 0.03, 0.04, 0.09, 1 }, o[1], o[2])
    end
    drawLetters(list, p, time, palette.base, 0, 0)
    local top = PAD + math.floor(font:getHeight() * 0.22)
    love.graphics.setScissor(0, 0, width, top + math.floor(font:getHeight() * 0.3))
    drawLetters(list, p, time, palette.light, 0, 0)
    love.graphics.setScissor(0, 0, width, top + math.floor(font:getHeight() * 0.1))
    drawLetters(list, p, time, palette.shine, 0, 0)
    local sweep = (time % 4.5) / 1.6
    if sweep < 1 then
        local sx = math.floor(sweep * (width + 12)) - 6
        love.graphics.setScissor(sx, 0, 3, height)
        drawLetters(list, p, time, { 1, 1, 1, 0.9 }, 0, 0)
    end
    love.graphics.setScissor()
    love.graphics.setCanvas()
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, (options.alpha or 1) * Pixel.alpha)
    love.graphics.draw(canvas, math.floor(x), math.floor(y), 0, scale, scale)
    return width * scale, height * scale
end

return WordArt
