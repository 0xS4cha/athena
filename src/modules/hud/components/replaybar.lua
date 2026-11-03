local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Config = require("src.config.game")
local Pixel = require("src.modules.hud.pixel")

local Bar = { id = "replaybar" }

local W, H = 620, 44
local BOTTOM = 16
local BUTTON = 44
local JUMP_TICKS = 30 * Config.tickRate
local LABEL_W = 116

local function layout(x, y)
    local restart = { x = x + 8, y = y + 6, w = BUTTON - 8, h = H - 12 }
    local back = { x = restart.x + restart.w + 4, y = y + 6, w = BUTTON, h = H - 12 }
    local forward = { x = back.x + back.w + 4, y = y + 6, w = BUTTON, h = H - 12 }
    local track = { x = forward.x + forward.w + 12, y = y + 16, h = 12 }
    track.w = x + W - LABEL_W - 16 - track.x
    return restart, back, forward, track
end

function Bar.visible(hud)
    return hud:game().options.replay == true
end

function Bar.size()
    return W, H
end

function Bar.position(_, w, h, sw, sh)
    return math.floor((sw - w) / 2), sh - h - BOTTOM
end

function Bar.draw(hud, x, y)
    local game = hud:game()
    local player = game.lockstep
    local mx, my = love.mouse.getPosition()
    Style.box(x, y, W, H, { corners = true, accent = Style.colors.gold })
    local restart, back, forward, track = layout(x, y)
    Style.button(restart.x, restart.y, restart.w, restart.h, "", { id = "replay:restart", icon = "Restart.png", iconSize = 16, hot = Style.inside(mx, my, restart.x, restart.y, restart.w, restart.h) })
    Style.button(back.x, back.y, back.w, back.h, "-30s", { id = "replay:back", size = 11, hot = Style.inside(mx, my, back.x, back.y, back.w, back.h) })
    Style.button(forward.x, forward.y, forward.w, forward.h, "+30s", { id = "replay:forward", size = 11, hot = Style.inside(mx, my, forward.x, forward.y, forward.w, forward.h) })
    Pixel.meter("replay:track", track.x, track.y, track.w, track.h, game.tick / math.max(1, player.ticks), Style.colors.gold, { instant = true })
    local label = Format.time(game.tick, Config.tickRate) .. " / " .. Format.time(player.ticks, Config.tickRate)
    Pixel.text(label, x + W - LABEL_W - 4, y + 12, 13, Style.colors.text)
end

function Bar.mousePressed(hud, mx, my, button, x, y)
    if button ~= 1 then return end
    local game = hud:game()
    local player = game.lockstep
    local restart, back, forward, track = layout(x, y)
    if Style.inside(mx, my, restart.x, restart.y, restart.w, restart.h) then
        player:seek(0)
    elseif Style.inside(mx, my, back.x, back.y, back.w, back.h) then
        player:seek(game.tick - JUMP_TICKS)
    elseif Style.inside(mx, my, forward.x, forward.y, forward.w, forward.h) then
        player:seek(game.tick + JUMP_TICKS)
    elseif Style.inside(mx, my, track.x, y, track.w, H) then
        player:seek((mx - track.x) / track.w * player.ticks)
    end
end

return Bar
