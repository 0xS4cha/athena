local floor = math.floor
local frexp, ldexp = math.frexp, math.ldexp

local DMath = {}

local LN2 = 0.6931471805599453
local SQRT_HALF = 0.7071067811865476

function DMath.log(x)
    if x <= 0 then
        return x == 0 and -math.huge or 0 / 0
    end
    if x == math.huge then return x end
    local m, e = frexp(x)
    if m < SQRT_HALF then
        m = m * 2
        e = e - 1
    end
    local s = (m - 1) / (m + 1)
    local s2 = s * s
    local term = s
    local sum = s
    for k = 3, 41, 2 do
        term = term * s2
        sum = sum + term / k
    end
    return e * LN2 + 2 * sum
end

function DMath.exp(x)
    if x ~= x then return x end
    if x > 709 then return math.huge end
    if x < -745 then return 0 end
    local k = floor(x / LN2 + 0.5)
    local r = x - k * LN2
    local term = 1
    local sum = 1
    for n = 1, 24 do
        term = term * r / n
        sum = sum + term
    end
    return ldexp(sum, k)
end

function DMath.pow(x, y)
    if y == 0 then return 1 end
    if x == 0 then return y > 0 and 0 or math.huge end
    if y == floor(y) and y > 0 and y <= 64 then
        local result, base, n = 1, x, y
        while n > 0 do
            if n % 2 == 1 then result = result * base end
            base = base * base
            n = floor(n / 2)
        end
        return result
    end
    if x < 0 then return 0 / 0 end
    return DMath.exp(y * DMath.log(x))
end

return DMath
