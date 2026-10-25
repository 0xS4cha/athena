local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")
local ChatLog = require("src.modules.hud.chatlog")

local Chat = { id = "chat" }

local MAX_WIDTH = 400
local CONTROL_W = 360
local MARGIN = 16
local INFO_H = 46
local INPUT_H = 34
local HISTORY_H = 200
local HINT_H = 18
local SHOWN = 6
local LIFETIME = 12
local FADE = 2

local function net()
    return GM.Multiplayer
end

local function enabled(hud)
    local game = hud:game()
    return game.lockstep ~= nil and #(game.options.humans or {}) > 1
end

local function width()
    local W = love.graphics.getWidth()
    return math.max(240, math.min(MAX_WIDTH, math.floor((W - CONTROL_W) / 2) - MARGIN * 2))
end

local function bottom()
    return love.graphics.getHeight() - INFO_H
end

local function entries(hud)
    local game = hud:game()
    local now = love.timer.getTime()
    local list = {}
    local messages = net().chat
    for k = #messages, 1, -1 do
        local message = messages[k]
        local alpha = 1
        if not hud.chatOpen then
            local age = now - message.time
            if age >= LIFETIME or #list >= SHOWN then break end
            alpha = Fx.clamp((LIFETIME - age) / FADE, 0, 1)
        end
        local player = message.slot and game.players[message.slot]
        table.insert(list, 1, { message = message, color = player and player.color or ChatLog.color(message), alpha = alpha })
    end
    return list
end

local function blocked(hud)
    for _, component in ipairs(hud.components) do
        if component.modal and hud:isVisible(component) then return true end
    end
    return false
end

local function close(hud)
    hud.chatOpen = false
    hud.chatText = ""
end

local function send(hud)
    local text = hud.chatText
    close(hud)
    if text:match("%S") then
        net():SendChat(text, hud.chatScope)
    end
end

function Chat.init(hud)
    hud.chatOpen = false
    hud.chatText = ""
    hud.chatScope = "all"
end

function Chat.visible(hud)
    if not enabled(hud) then
        if hud.chatOpen then close(hud) end
        return false
    end
    return hud.chatOpen or #entries(hud) > 0
end

function Chat.typing(hud)
    return hud.chatOpen and enabled(hud)
end

function Chat.hit(hud, mx, my)
    if not hud.chatOpen then return false end
    local h = HISTORY_H + INPUT_H + HINT_H
    return Style.inside(mx, my, MARGIN, bottom() - h, width(), h)
end

function Chat.draw(hud)
    local w = width()
    local x, y = MARGIN, bottom()
    local u = Pixel.unit
    if not hud.chatOpen then
        ChatLog.draw(entries(hud), x, y, w, { backdrop = true, gap = u })
        return
    end
    local top = y - HISTORY_H - INPUT_H - HINT_H
    Style.frame(x, top, w, HISTORY_H + INPUT_H + HINT_H, nil, { accent = Style.colors.gold, cornerAlpha = 0.6 })
    local inputY = y - INPUT_H - HINT_H
    ChatLog.draw(entries(hud), x + u * 2, inputY - u * 2, w - u * 4, { top = top + u * 3 })
    local allies = hud.chatScope == "allies"
    ChatLog.input(x + u * 2, inputY, w - u * 4, INPUT_H - u * 2, hud.chatText, {
        editing = true,
        label = allies and "ALLIES:" or "ALL:",
        labelColor = allies and Style.colors.good or Style.colors.gold,
        placeholder = "Type a message..."
    })
    Pixel.text("Enter send  -  Tab all / allies  -  Esc cancel", x + u * 3, y - HINT_H, 10, Style.colors.muted)
end

function Chat.mousePressed() end

function Chat.textInput(hud, text)
    hud.chatText = ChatLog.edit(hud.chatText, text)
end

function Chat.keyPressed(hud, key)
    if not hud.chatOpen then
        if (key == "return" or key == "kpenter") and enabled(hud) and not blocked(hud) then
            hud.chatOpen = true
            hud.chatText = ""
            hud.contextMenu:close()
            return true
        end
        return false
    end
    if key == "return" or key == "kpenter" then
        send(hud)
    elseif key == "escape" then
        close(hud)
    elseif key == "tab" then
        hud.chatScope = hud.chatScope == "allies" and "all" or "allies"
    elseif key == "backspace" then
        hud.chatText = ChatLog.edit(hud.chatText, nil)
    end
    return true
end

return Chat
