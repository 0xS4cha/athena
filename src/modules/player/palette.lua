local Palette = {}

Palette.human = { 0.2, 0.55, 1.0 }
Palette.tribe = { 1, 1, 1 }

local function hueToRgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
end

function Palette.hsl(h, s, l)
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return hueToRgb(p, q, h + 1 / 3), hueToRgb(p, q, h), hueToRgb(p, q, h - 1 / 3)
end

function Palette.color(index)
    local hue = (0.13 + index * 0.618033988749895) % 1
    local s = 0.55 + (index * 7 % 5) * 0.08
    local l = 0.42 + (index * 3 % 4) * 0.06
    local r, g, b = Palette.hsl(hue, s, l)
    return { r, g, b }
end

return Palette
