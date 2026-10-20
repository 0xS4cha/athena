local Style = require("src.modules.hud.style")

local Layers = { id = "layers", title = "LAYERS", panel = true }

local ITEMS = {
    { name = "Terrain",     layer = "terrain",   key = "1" },
    { name = "Territories", layer = "political", key = "2" },
    { name = "Units",       layer = "units",     key = "3" },
    { name = "Names",       layer = "names",     key = "4" },
    { name = "Supply",      layer = "supply",    key = "5" }
}

function Layers.size()
    return 200, Style.headerHeight + 10 + #ITEMS * 24
end

function Layers.position(_, w, _, W)
    return W - w - 20, 20
end

local function itemY(y, k)
    return y + Style.headerHeight + 8 + (k - 1) * 24
end

function Layers.draw(hud, x, y, w)
    local layers = hud:game().renderer.layers
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(Style.font(12))
    for k, item in ipairs(ITEMS) do
        local iy = itemY(y, k)
        local hovered = Style.inside(mx, my, x + 4, iy - 2, w - 8, 22)
        if hovered then
            Style.setColor(Style.colors.hover)
            love.graphics.rectangle("fill", x + 4, iy - 2, w - 8, 22)
        end
        local on = layers[item.layer]
        love.graphics.setColor(on and 0.1 or 0.5, on and 0.75 or 0.5, on and 0.55 or 0.5, 1)
        love.graphics.rectangle("line", x + 14, iy + 4, 10, 10)
        if on then
            love.graphics.rectangle("fill", x + 16, iy + 6, 6, 6)
        end
        Style.setColor(Style.colors.text)
        love.graphics.print(item.name, x + 32, iy + 2)
        Style.setColor(Style.colors.muted)
        love.graphics.print("[" .. item.key .. "]", x + w - 30, iy + 2)
    end
end

function Layers.mousePressed(hud, mx, my, button, x, y, w)
    if button ~= 1 then return end
    for k, item in ipairs(ITEMS) do
        if Style.inside(mx, my, x + 4, itemY(y, k) - 2, w - 8, 22) then
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
