local Format = {}

function Format.number(n)
    n = math.floor(n or 0)
    local a = math.abs(n)
    if a >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif a >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif a >= 1e4 then
        return string.format("%.1fK", n / 1e3)
    end
    return tostring(n)
end

function Format.percent(v)
    return string.format("%.1f%%", (v or 0) * 100)
end

function Format.time(ticks, rate)
    local s = math.floor(ticks / rate)
    return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

return Format
