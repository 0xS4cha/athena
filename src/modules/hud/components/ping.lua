local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")

local Ping = { id = "ping" }

local W, H = 104, 42
local CLOCK_W = 330
local BARS = 4

local function net()
    return GM.Multiplayer
end

local function strength(ping)
    if not ping then return 0 end
    if ping < 60 then return 4 end
    if ping < 120 then return 3 end
    if ping < 200 then return 2 end
    return 1
end

function Ping.size()
    return W, H
end

function Ping.position(_, _, _, sw)
    return math.floor((sw + CLOCK_W) / 2) + 8, 14
end

function Ping.visible(hud)
    local game = hud:game()
    return game.lockstep ~= nil and game.phase ~= "spawn" and net():ShowsPing()
end

function Ping.draw(hud, x, y)
    local mp = net()
    local u = Pixel.unit
    local ping = mp:Ping()
    local color = mp.PingColor(ping)
    Style.box(x, y, W, H, { corners = true })
    local level = strength(ping)
    local bx, base = x + u * 5, y + H - u * 5
    for k = 1, BARS do
        local bh = u * (2 + k * 2)
        Pixel.color(k <= level and color or Pixel.colors.raised, k <= level and 1 or 0.7)
        love.graphics.rectangle("fill", bx + (k - 1) * u * 3, base - bh, u * 2, bh)
    end
    local label = ping and string.format("%d ms", ping) or "LOST"
    Pixel.text(label, x + u * 20, y + 7, 15, ping and Style.colors.text or color)
    Pixel.text("PING", x + u * 20, y + 24, 9, Style.colors.muted)
end

return Ping
