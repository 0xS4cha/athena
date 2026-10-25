local Pixel = require("src.modules.hud.pixel")
local Style = require("src.modules.hud.style")
local Palette = require("src.modules.player.palette")
local NetConfig = require("src.net.config")
local Text = require("src.core.text")

local ChatLog = {}

local floor = math.floor

function ChatLog.edit(value, text)
    if not text then
        return Text.dropLast(value)
    end
    text = text:gsub("%c", "")
    local length, added = Text.length(value), Text.length(text)
    if not length or not added or length + added > NetConfig.chatLength then
        return value
    end
    return value .. text
end

function ChatLog.color(message)
    return message.color and Palette.choices[message.color] or Style.colors.muted
end

local function prefix(message)
    return (message.scope == "allies" and "[ALLIES] " or "") .. message.name .. ": "
end

local function colored(message, color, alpha)
    local parts = {}
    if message.scope == "allies" then
        local good = Style.colors.good
        parts[#parts + 1] = { good[1], good[2], good[3], alpha }
        parts[#parts + 1] = "[ALLIES] "
    end
    local text = Style.colors.text
    parts[#parts + 1] = { color[1], color[2], color[3], alpha }
    parts[#parts + 1] = message.name .. ": "
    parts[#parts + 1] = { text[1], text[2], text[3], alpha }
    parts[#parts + 1] = message.text
    return parts
end

function ChatLog.draw(entries, x, bottom, w, options)
    options = options or {}
    local u = Pixel.unit
    local font = Style.font(options.size or 12)
    local lineH = font:getHeight()
    local top = options.top or -math.huge
    love.graphics.setFont(font)
    local y = bottom
    for k = #entries, 1, -1 do
        local entry = entries[k]
        local message = entry.message
        local fade = entry.alpha or 1
        local _, lines = font:getWrap(prefix(message) .. message.text, w - u * 4)
        local h = #lines * lineH + u * 2
        y = y - h
        if y < top then break end
        if options.backdrop then
            Pixel.color(Pixel.colors.ink, 0.6 * fade)
            love.graphics.rectangle("fill", floor(x), floor(y), floor(w), h)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(colored(message, entry.color, fade * Pixel.alpha), floor(x + u * 2), floor(y + u), w - u * 4, "left")
        y = y - (options.gap or 0)
    end
end

function ChatLog.input(x, y, w, h, value, options)
    options = options or {}
    local u = Pixel.unit
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    Pixel.color(Pixel.colors.ink)
    Pixel.block(x, y, w, h)
    Pixel.color(Pixel.colors.raised, options.editing and 0.95 or 0.6)
    Pixel.block(x + u, y + u, w - 2 * u, h - 2 * u)
    Pixel.color(options.editing and Pixel.colors.gold or Pixel.colors.edge, options.editing and 0.9 or 0.4)
    love.graphics.rectangle("fill", x + 2 * u, y + h - 2 * u, w - 4 * u, u)
    local font = Style.font(options.size or 12)
    love.graphics.setFont(font)
    local tx = x + u * 3
    if options.label then
        Pixel.text(options.label, tx, floor(y + (h - font:getHeight()) / 2) - 1, options.size or 12, options.labelColor or Pixel.colors.gold)
        tx = tx + font:getWidth(options.label) + u * 2
    end
    local room = x + w - u * 4 - tx
    local ty = floor(y + (h - font:getHeight()) / 2) - 1
    local offset = math.min(0, room - font:getWidth(value) - u * 3)
    love.graphics.setScissor(tx, y, room, h)
    if value == "" and options.placeholder then
        Pixel.color(Pixel.colors.muted, 0.7)
        love.graphics.print(options.placeholder, tx, ty)
    else
        Pixel.color(Pixel.colors.text)
        love.graphics.print(value, tx + offset, ty)
    end
    if options.editing and love.timer.getTime() % 1 < 0.55 then
        Pixel.color(Pixel.colors.gold)
        love.graphics.rectangle("fill", tx + offset + font:getWidth(value) + 1, y + u * 3, u, h - u * 6)
    end
    love.graphics.setScissor()
end

return ChatLog
