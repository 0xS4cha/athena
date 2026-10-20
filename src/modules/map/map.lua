local ffi = require("ffi")
local bit = require("bit")
local Class = require("src.core.class")
local LoadFile = require("src.core.loadFile")

local band = bit.band
local floor = math.floor

local Map = Class()

function Map:init(path)
    if path:sub(-1) ~= "/" then
        path = path .. "/"
    end
    self.path = path
    self.manifest = LoadFile:Json(path .. "manifest.json")
    self.name = self.manifest.name or path
    self.width = self.manifest.map.width
    self.height = self.manifest.map.height
    self.size = self.width * self.height

    local raw = love.filesystem.read(path .. "map.bin")
    if not raw then
        error("Failed to load " .. path .. "map.bin")
    end
    self.terrain = ffi.new("uint8_t[?]", self.size)
    ffi.copy(self.terrain, raw, math.min(#raw, self.size))
    self.owner = ffi.new("uint16_t[?]", self.size)
    self.fallout = ffi.new("uint8_t[?]", self.size)

    self.landCount = 0
    local terrain = self.terrain
    for i = 0, self.size - 1 do
        if band(terrain[i], 128) ~= 0 then
            self.landCount = self.landCount + 1
        end
    end
end

function Map:index(x, y)
    return y * self.width + x
end

function Map:coords(i)
    local x = i % self.width
    return x, (i - x) / self.width
end

function Map:isValid(x, y)
    return x >= 0 and y >= 0 and x < self.width and y < self.height
end

function Map:tileAt(wx, wy)
    local x, y = floor(wx), floor(wy)
    if not self:isValid(x, y) then
        return nil
    end
    return y * self.width + x
end

function Map:isLand(i)
    return band(self.terrain[i], 128) ~= 0
end

function Map:isWater(i)
    return band(self.terrain[i], 128) == 0
end

function Map:isShoreline(i)
    return band(self.terrain[i], 64) ~= 0
end

function Map:isOcean(i)
    return band(self.terrain[i], 32) ~= 0
end

function Map:magnitude(i)
    return band(self.terrain[i], 31)
end

function Map:terrainType(i)
    if self:isWater(i) then
        return "water"
    end
    local mag = self:magnitude(i)
    if mag < 10 then
        return "plains"
    elseif mag < 20 then
        return "highland"
    end
    return "mountain"
end

function Map:neighbors(i, out)
    local w = self.width
    local x = i % w
    local n = 0
    if x > 0 then
        n = n + 1
        out[n] = i - 1
    end
    if x < w - 1 then
        n = n + 1
        out[n] = i + 1
    end
    if i >= w then
        n = n + 1
        out[n] = i - w
    end
    if i < self.size - w then
        n = n + 1
        out[n] = i + w
    end
    return n
end

function Map:isCoast(i)
    if not self:isLand(i) then
        return false
    end
    local w = self.width
    local x = i % w
    local terrain = self.terrain
    if x > 0 and band(terrain[i - 1], 128) == 0 then return true end
    if x < w - 1 and band(terrain[i + 1], 128) == 0 then return true end
    if i >= w and band(terrain[i - w], 128) == 0 then return true end
    if i < self.size - w and band(terrain[i + w], 128) == 0 then return true end
    return false
end

function Map:distance(a, b)
    local ax, ay = self:coords(a)
    local bx, by = self:coords(b)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

function Map:findNear(x, y, radius, predicate)
    x, y = floor(x), floor(y)
    local w = self.width
    for r = 0, radius do
        local best, bestD
        local function test(tx, ty)
            if tx >= 0 and ty >= 0 and tx < w and ty < self.height then
                local i = ty * w + tx
                if predicate(i) then
                    local dx, dy = tx - x, ty - y
                    local d = dx * dx + dy * dy
                    if not bestD or d < bestD then
                        best, bestD = i, d
                    end
                end
            end
        end
        if r == 0 then
            test(x, y)
        else
            for dx = -r, r do
                test(x + dx, y - r)
                test(x + dx, y + r)
            end
            for dy = -r + 1, r - 1 do
                test(x - r, y + dy)
                test(x + r, y + dy)
            end
        end
        if best then
            return best
        end
    end
    return nil
end

function Map:forDisk(cx, cy, radius, fn)
    local r2 = radius * radius
    local w = self.width
    for y = math.max(0, floor(cy - radius)), math.min(self.height - 1, floor(cy + radius)) do
        local dy = y - cy
        for x = math.max(0, floor(cx - radius)), math.min(w - 1, floor(cx + radius)) do
            local dx = x - cx
            local d2 = dx * dx + dy * dy
            if d2 <= r2 then
                fn(y * w + x, d2)
            end
        end
    end
end

return Map
