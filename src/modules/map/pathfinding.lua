local ffi = require("ffi")
local bit = require("bit")

local band = bit.band
local abs = math.abs
local floor = math.floor

local Pathfinding = {}
Pathfinding.__index = Pathfinding

local SQRT2 = 1.41421356
local WEIGHT = 1.4
local DIRECT_DISTANCE = 80
local DIRECT_NODES = 40000
local COARSE_CELLS = 120000

function Pathfinding.new(map)
    local n = map.size
    local self = setmetatable({}, Pathfinding)
    self.map = map
    self.g = ffi.new("float[?]", n)
    self.parent = ffi.new("int32_t[?]", n)
    self.seen = ffi.new("uint32_t[?]", n)
    self.closed = ffi.new("uint32_t[?]", n)
    self.generation = 0
    self.capacity = 65536
    self.heapTile = ffi.new("int32_t[?]", self.capacity)
    self.heapCost = ffi.new("float[?]", self.capacity)
    self:buildCoarse()
    self:buildComponents()
    return self
end

function Pathfinding:buildComponents()
    local map = self.map
    local n, w = map.size, map.width
    local terrain = map.terrain
    local component = ffi.new("int32_t[?]", n)
    local queue = ffi.new("int32_t[?]", n)
    local count = 0
    for i = 0, n - 1 do
        if component[i] == 0 and band(terrain[i], 128) == 0 then
            count = count + 1
            component[i] = count
            local head, tail = 0, 1
            queue[0] = i
            while head < tail do
                local c = queue[head]
                head = head + 1
                local x = c % w
                local a = x > 0 and c - 1 or -1
                local b = x < w - 1 and c + 1 or -1
                local u = c >= w and c - w or -1
                local d = c < n - w and c + w or -1
                if a >= 0 and component[a] == 0 and band(terrain[a], 128) == 0 then component[a] = count; queue[tail] = a; tail = tail + 1 end
                if b >= 0 and component[b] == 0 and band(terrain[b], 128) == 0 then component[b] = count; queue[tail] = b; tail = tail + 1 end
                if u >= 0 and component[u] == 0 and band(terrain[u], 128) == 0 then component[u] = count; queue[tail] = u; tail = tail + 1 end
                if d >= 0 and component[d] == 0 and band(terrain[d], 128) == 0 then component[d] = count; queue[tail] = d; tail = tail + 1 end
            end
        end
    end
    self.component = component
end

function Pathfinding:waterComponents(i)
    local map = self.map
    local list = {}
    local nb = {}
    if map:isWater(i) then
        list[self.component[i]] = true
    end
    local count = map:neighbors(i, nb)
    for k = 1, count do
        local c = self.component[nb[k]]
        if c > 0 then list[c] = true end
    end
    return list
end

function Pathfinding:connected(a, b)
    local ca = self:waterComponents(a)
    for c in pairs(self:waterComponents(b)) do
        if ca[c] then return true end
    end
    return false
end

function Pathfinding:buildCoarse()
    local map = self.map
    local w, h = map.width, map.height
    local scale = math.max(2, math.ceil(math.sqrt(map.size / COARSE_CELLS)))
    local cw, ch = math.ceil(w / scale), math.ceil(h / scale)
    local water = ffi.new("uint8_t[?]", cw * ch)
    local rep = ffi.new("int32_t[?]", cw * ch)
    local terrain = map.terrain
    for cy = 0, ch - 1 do
        for cx = 0, cw - 1 do
            local best, bestD = -1, nil
            local mx, my = cx * scale + scale / 2, cy * scale + scale / 2
            for y = cy * scale, math.min(h - 1, cy * scale + scale - 1) do
                for x = cx * scale, math.min(w - 1, cx * scale + scale - 1) do
                    local i = y * w + x
                    if band(terrain[i], 128) == 0 then
                        local d = (x - mx) * (x - mx) + (y - my) * (y - my)
                        if not bestD or d < bestD then
                            best, bestD = i, d
                        end
                    end
                end
            end
            local c = cy * cw + cx
            water[c] = best >= 0 and 1 or 0
            rep[c] = best
        end
    end
    self.scale = scale
    self.coarseWidth = cw
    self.coarseHeight = ch
    self.coarseWater = water
    self.coarseRep = rep
end

function Pathfinding:grow()
    local capacity = self.capacity * 2
    local tiles = ffi.new("int32_t[?]", capacity)
    local costs = ffi.new("float[?]", capacity)
    ffi.copy(tiles, self.heapTile, self.capacity * 4)
    ffi.copy(costs, self.heapCost, self.capacity * 4)
    self.heapTile = tiles
    self.heapCost = costs
    self.capacity = capacity
end

function Pathfinding:search(w, h, start, goal, passable, maxNodes, orthogonal)
    local g, parent, seen, closed = self.g, self.parent, self.seen, self.closed
    self.generation = self.generation + 1
    local gen = self.generation
    local gx = goal % w
    local gy = (goal - gx) / w

    local size = 0
    local function push(tile, cost)
        size = size + 1
        if size >= self.capacity then self:grow() end
        local ht, hc = self.heapTile, self.heapCost
        local k = size
        while k > 1 do
            local p = (k - k % 2) / 2
            if hc[p] <= cost then break end
            ht[k] = ht[p]
            hc[k] = hc[p]
            k = p
        end
        ht[k] = tile
        hc[k] = cost
    end
    local function pop()
        local ht, hc = self.heapTile, self.heapCost
        local top = ht[1]
        local lastTile, lastCost = ht[size], hc[size]
        size = size - 1
        local k = 1
        while true do
            local c = k * 2
            if c > size then break end
            if c < size and hc[c + 1] < hc[c] then c = c + 1 end
            if hc[c] >= lastCost then break end
            ht[k] = ht[c]
            hc[k] = hc[c]
            k = c
        end
        if size > 0 then
            ht[k] = lastTile
            hc[k] = lastCost
        end
        return top
    end
    local function heuristic(x, y)
        local dx, dy = abs(x - gx), abs(y - gy)
        local d = dx < dy and dx or dy
        return ((dx + dy) + (SQRT2 - 2) * d) * WEIGHT
    end

    seen[start] = gen
    g[start] = 0
    parent[start] = -1
    local sx = start % w
    push(start, heuristic(sx, (start - sx) / w))
    local expanded = 0

    while size > 0 do
        local current = pop()
        if current == goal then
            local path = {}
            local node = goal
            while node ~= -1 do
                path[#path + 1] = node
                node = parent[node]
            end
            local n = #path
            for k = 1, floor(n / 2) do
                path[k], path[n - k + 1] = path[n - k + 1], path[k]
            end
            return path
        end
        if closed[current] ~= gen then
            closed[current] = gen
            expanded = expanded + 1
            if expanded > maxNodes then return nil end
            local cx = current % w
            local cy = (current - cx) / w
            local base = g[current]
            for dy = -1, 1 do
                local ny = cy + dy
                if ny >= 0 and ny < h then
                    for dx = -1, 1 do
                        local nx = cx + dx
                        if (dx ~= 0 or dy ~= 0) and (not orthogonal or dx == 0 or dy == 0) and nx >= 0 and nx < w then
                            local ni = ny * w + nx
                            if closed[ni] ~= gen and passable(ni) then
                                local diagonal = dx ~= 0 and dy ~= 0
                                if not diagonal or (passable(cy * w + nx) and passable(ny * w + cx)) then
                                    local cost = base + (diagonal and SQRT2 or 1)
                                    if seen[ni] ~= gen or cost < g[ni] then
                                        seen[ni] = gen
                                        g[ni] = cost
                                        parent[ni] = current
                                        push(ni, cost + heuristic(nx, ny))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Pathfinding:land(start, goal, ownerId, maxNodes)
    local map = self.map
    local terrain = map.terrain
    local own = map.owner
    return self:search(map.width, map.height, start, goal, function(i)
        return band(terrain[i], 128) ~= 0 and own[i] == ownerId
    end, maxNodes, true)
end

function Pathfinding:fine(start, goal, maxNodes)
    local map = self.map
    local terrain = map.terrain
    return self:search(map.width, map.height, start, goal, function(i)
        return band(terrain[i], 128) == 0 or i == goal
    end, maxNodes)
end

local function appendLine(path, map, from, to)
    local w = map.width
    local x1, y1 = from % w, floor(from / w)
    local x2, y2 = to % w, floor(to / w)
    local steps = math.max(abs(x2 - x1), abs(y2 - y1))
    for k = 1, steps do
        local x = floor(x1 + (x2 - x1) * k / steps + 0.5)
        local y = floor(y1 + (y2 - y1) * k / steps + 0.5)
        path[#path + 1] = y * w + x
    end
end

function Pathfinding:coarse(start, goal, maxNodes)
    local map = self.map
    local w = map.width
    local scale, cw = self.scale, self.coarseWidth
    local function cell(i)
        local x = i % w
        return floor((i - x) / w / scale) * cw + floor(x / scale)
    end
    local cs, cg = cell(start), cell(goal)
    local water, rep = self.coarseWater, self.coarseRep
    local route = self:search(cw, self.coarseHeight, cs, cg, function(c)
        return water[c] == 1 or c == cg
    end, maxNodes)
    if not route then return nil end
    local path = { start }
    local last = start
    for k = 2, #route - 1 do
        local r = rep[route[k]]
        if r >= 0 then
            appendLine(path, map, last, r)
            last = r
        end
    end
    appendLine(path, map, last, goal)
    return path
end

function Pathfinding:straight(start, goal)
    local map = self.map
    local terrain = map.terrain
    local path = { start }
    appendLine(path, map, start, goal)
    for k = 2, #path - 1 do
        if band(terrain[path[k]], 128) ~= 0 then
            return nil
        end
    end
    return path
end

function Pathfinding:water(start, goal, maxNodes)
    local direct = self:straight(start, goal)
    if direct then return direct end
    if not self:connected(start, goal) then return nil end
    local map = self.map
    local sx, sy = map:coords(start)
    local gx, gy = map:coords(goal)
    if abs(sx - gx) + abs(sy - gy) <= DIRECT_DISTANCE then
        local path = self:fine(start, goal, DIRECT_NODES)
        if path then return path end
    end
    return self:coarse(start, goal, maxNodes or 200000)
end

return Pathfinding
