local Fx = {}

local floor = math.floor

function Fx.clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

function Fx.outCubic(t)
    t = 1 - Fx.clamp(t, 0, 1)
    return 1 - t * t * t
end

function Fx.outBack(t)
    t = Fx.clamp(t, 0, 1) - 1
    local c = 1.70158
    return 1 + (c + 1) * t * t * t + c * t * t
end

function Fx.approach(value, target, rate, dt)
    return target + (value - target) * math.exp(-rate * dt)
end

function Fx.mirror(half)
    local rows = {}
    for k, row in ipairs(half) do
        rows[k] = row .. row:sub(1, #row - 1):reverse()
    end
    return rows
end

function Fx.sprite(rows, palette, x, y, unit, alpha)
    for r, row in ipairs(rows) do
        for c = 1, #row do
            local color = palette[row:sub(c, c)]
            if color then
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
                love.graphics.rectangle("fill", x + (c - 1) * unit, y + (r - 1) * unit, unit, unit)
            end
        end
    end
end

local EMBER_COLORS = {
    { 1, 0.82, 0.25 },
    { 1, 0.55, 0.15 },
    { 0.95, 0.35, 0.2 },
    { 0.45, 0.75, 1 }
}

local function resetEmber(ember, W, H, anywhere)
    ember.x = love.math.random() * W
    ember.y = anywhere and love.math.random() * H or H + love.math.random() * 40
    ember.speed = 12 + love.math.random() * 34
    ember.sway = 6 + love.math.random() * 18
    ember.phase = love.math.random() * math.pi * 2
    ember.size = love.math.random() < 0.2 and 3 or 2
    ember.flicker = 2 + love.math.random() * 5
    ember.color = EMBER_COLORS[love.math.random() < 0.15 and 4 or love.math.random(1, 3)]
    ember.alpha = 0.35 + love.math.random() * 0.5
end

function Fx.embers(count)
    local W, H = love.graphics.getDimensions()
    local list = {}
    for k = 1, count do
        list[k] = {}
        resetEmber(list[k], W, H, true)
    end
    return list
end

function Fx.updateEmbers(list, dt)
    local W, H = love.graphics.getDimensions()
    for _, ember in ipairs(list) do
        ember.y = ember.y - ember.speed * dt
        ember.phase = ember.phase + dt
        if ember.y < -10 or ember.x < -20 or ember.x > W + 20 then
            resetEmber(ember, W, H, false)
        end
    end
end

function Fx.drawEmbers(list, alpha)
    local time = love.timer.getTime()
    for _, ember in ipairs(list) do
        local x = floor(ember.x + math.sin(ember.phase * 0.8) * ember.sway)
        local flicker = 0.6 + 0.4 * math.sin(time * ember.flicker + ember.phase)
        local c = ember.color
        love.graphics.setColor(c[1], c[2], c[3], ember.alpha * flicker * alpha)
        love.graphics.rectangle("fill", x, floor(ember.y), ember.size, ember.size)
    end
end

local vignette, gradient, scanlines, scanQuad

function Fx.vignette(alpha)
    if not vignette then
        local size = 64
        local data = love.image.newImageData(size, size)
        for y = 0, size - 1 do
            for x = 0, size - 1 do
                local dx = (x + 0.5) / size * 2 - 1
                local dy = (y + 0.5) / size * 2 - 1
                local d = math.sqrt(dx * dx * 0.7 + dy * dy)
                local a = Fx.clamp((d - 0.5) / 0.8, 0, 1) ^ 1.5
                data:setPixel(x, y, 0, 0, 0, a)
            end
        end
        vignette = love.graphics.newImage(data)
        vignette:setFilter("linear", "linear")
    end
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(vignette, 0, 0, 0, W / vignette:getWidth(), H / vignette:getHeight())
end

function Fx.gradient(x, y, w, h, color, alpha, side)
    if not gradient then
        gradient = love.graphics.newMesh({
            { 0, 0, 0, 0, 1, 1, 1, 1 },
            { 1, 0, 0, 0, 1, 1, 1, 0 },
            { 1, 1, 0, 0, 1, 1, 1, 0 },
            { 0, 1, 0, 0, 1, 1, 1, 1 }
        }, "fan", "static")
    end
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    if side == "top" then
        love.graphics.draw(gradient, x, y, math.pi / 2, h, -w)
    elseif side == "bottom" then
        love.graphics.draw(gradient, x, y + h, -math.pi / 2, h, w)
    elseif side == "right" then
        love.graphics.draw(gradient, x + w, y, 0, -w, h)
    else
        love.graphics.draw(gradient, x, y, 0, w, h)
    end
end

function Fx.scanlines(alpha)
    local W, H = love.graphics.getDimensions()
    if not scanlines then
        local data = love.image.newImageData(1, 3)
        data:setPixel(0, 2, 0, 0, 0, 1)
        scanlines = love.graphics.newImage(data)
        scanlines:setFilter("nearest", "nearest")
        scanlines:setWrap("repeat", "repeat")
    end
    if not scanQuad or scanQuad.w ~= W or scanQuad.h ~= H then
        scanQuad = { quad = love.graphics.newQuad(0, 0, W, H, 1, 3), w = W, h = H }
    end
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(scanlines, scanQuad.quad, 0, 0)
end

local WIPE_CELL = 36

function Fx.wipe(progress, covering)
    local W, H = love.graphics.getDimensions()
    local cols = math.ceil(W / WIPE_CELL)
    local rows = math.ceil(H / WIPE_CELL)
    for cy = 0, rows - 1 do
        for cx = 0, cols - 1 do
            local delay = (cx / cols * 0.65 + cy / rows * 0.35) * 0.5
            local p = Fx.clamp((progress - delay) / 0.5, 0, 1)
            if not covering then
                p = 1 - p
            end
            if p > 0 then
                local size = math.ceil(WIPE_CELL * Fx.outCubic(p) / 3) * 3
                local edge = 1 - p
                love.graphics.setColor(0.02 + edge * 0.15, 0.03 + edge * 0.3, 0.06 + edge * 0.6, 1)
                local x = cx * WIPE_CELL + floor((WIPE_CELL - size) / 2)
                local y = cy * WIPE_CELL + floor((WIPE_CELL - size) / 2)
                love.graphics.rectangle("fill", x, y, size, size)
            end
        end
    end
end

return Fx
