local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")

local Layers = { id = "layers", title = "LAYERS", panel = true }

local ROW = 26

local ITEMS = {
    { name = "Terrain",     layer = "terrain",   key = "1" },
    { name = "Territories", layer = "political", key = "2" },
    { name = "Units",       layer = "units",     key = "3" },
    { name = "Names",       layer = "names",     key = "4" },
    { name = "Supply",      layer = "supply",    key = "5" }
}

function Layers.size()
    return 210, Style.headerHeight + 14 + #ITEMS * ROW
end

function Layers.position(_, w, _, W)
    return W - w - 20, 20
end

local function itemY(y, k)
    return y + Style.headerHeight + 8 + (k - 1) * ROW
end

function Layers.draw(hud, x, y, w)
    local layers = hud:game().renderer.layers
    local mx, my = love.mouse.getPosition()
    local u = Pixel.unit
    for k, item in ipairs(ITEMS) do
        local iy = itemY(y, k)
        local hot = Pixel.ease("layer:hot:" .. k, Style.inside(mx, my, x + 4, iy, w - 8, ROW - 2), 18)
        local on = Pixel.ease("layer:on:" .. k, layers[item.layer] == true, 16)
        if hot > 0.01 then
            Pixel.color(Pixel.colors.hover, 0.35 * hot)
            Pixel.block(x + u * 2, iy, w - u * 4, ROW - 2, u)
            Pixel.color(Pixel.colors.hover, hot)
            love.graphics.rectangle("fill", x + u * 2, iy + u, u, ROW - 2 - u * 2)
        end
        local bx, by = x + u * 5, iy + math.floor((ROW - 2 - u * 6) / 2)
        Pixel.color(Pixel.colors.ink)
        Pixel.block(bx, by, u * 6, u * 6, u)
        Pixel.color(Pixel.mix(Pixel.colors.raised, Pixel.colors.good, on))
        local inner = math.floor(on * 2 + 0.5) * u
        love.graphics.rectangle("fill", bx + u * 3 - inner / 2 - u / 2, by + u * 3 - inner / 2 - u / 2, inner + u, inner + u)
        local tx = x + u * 15 + math.floor(hot * 2) * u
        Pixel.text(item.name, tx, iy + 3, 12, Pixel.mix(Style.colors.muted, Style.colors.text, math.max(on, hot)))
        local font = Style.font(10)
        local kw = font:getWidth(item.key) + u * 4
        local kx = x + w - kw - u * 5
        Pixel.color(Pixel.colors.ink, 0.85)
        Pixel.block(kx, iy + 2, kw, ROW - 6, u)
        Pixel.color(Pixel.colors.raised)
        Pixel.block(kx + u, iy + 2 + u, kw - u * 2, ROW - 6 - u * 2, u)
        Pixel.text(item.key, kx + u * 2, iy + 3, 10, Style.colors.gold)
    end
end

function Layers.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, item in ipairs(ITEMS) do
        if Style.inside(mx, my, x + 4, itemY(y, k), w - 8, ROW - 2) then
            hud:game().renderer:toggleLayer(item.layer)
        end
    end
end

function Layers.keyPressed(hud, key)
    for _, item in ipairs(ITEMS) do
        if item.key == key then
            hud:game().renderer:toggleLayer(item.layer)
            return true
        end
    end
    return false
end

return Layers
