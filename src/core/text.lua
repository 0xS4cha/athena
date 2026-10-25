local Text = {}

local byte = string.byte

local function sequence(s, i)
    local lead = byte(s, i)
    if lead < 0x80 then return 1 end
    local size, low, high
    if lead >= 0xC2 and lead <= 0xDF then
        size, low, high = 2, 0x80, 0xBF
    elseif lead == 0xE0 then
        size, low, high = 3, 0xA0, 0xBF
    elseif lead == 0xED then
        size, low, high = 3, 0x80, 0x9F
    elseif lead >= 0xE1 and lead <= 0xEF then
        size, low, high = 3, 0x80, 0xBF
    elseif lead == 0xF0 then
        size, low, high = 4, 0x90, 0xBF
    elseif lead >= 0xF1 and lead <= 0xF3 then
        size, low, high = 4, 0x80, 0xBF
    elseif lead == 0xF4 then
        size, low, high = 4, 0x80, 0x8F
    else
        return nil
    end
    if i + size - 1 > #s then return nil end
    local second = byte(s, i + 1)
    if second < low or second > high then return nil end
    for k = i + 2, i + size - 1 do
        local b = byte(s, k)
        if b < 0x80 or b > 0xBF then return nil end
    end
    return size
end

function Text.chars(s)
    local chars = {}
    local i = 1
    while i <= #s do
        local size = sequence(s, i)
        if not size then return nil end
        chars[#chars + 1] = s:sub(i, i + size - 1)
        i = i + size
    end
    return chars
end

function Text.length(s)
    local chars = Text.chars(s)
    return chars and #chars or nil
end

function Text.clean(s, limit)
    if type(s) ~= "string" then return nil end
    local chars = Text.chars(s)
    if not chars then return nil end
    local out = {}
    for k = 1, math.min(#chars, limit) do
        out[k] = chars[k]:match("^%c$") and " " or chars[k]
    end
    local cleaned = table.concat(out):gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned
end

function Text.dropLast(s)
    local trimmed = s:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
    return trimmed
end

return Text
