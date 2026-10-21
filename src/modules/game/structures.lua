local Structures = {}

local CELL = 8
local SIZE = 7
local MAX_FRAMES = 4
local LAYERS = { base = 0, mask = 1, silhouette = 2 }

local INK = { 0.06, 0.05, 0.09 }

local COLORS = {
    L = { 0.9, 0.88, 0.82 },
    M = { 0.72, 0.7, 0.66 },
    D = { 0.5, 0.48, 0.46 },
    R = { 0.86, 0.3, 0.22 },
    r = { 0.6, 0.18, 0.15 },
    Y = { 1, 0.85, 0.35 },
    y = { 0.8, 0.58, 0.18 },
    W = { 0.16, 0.18, 0.26 },
    G = { 0.68, 0.72, 0.78 },
    g = { 0.42, 0.45, 0.52 },
    B = { 0.45, 0.75, 1 }
}

local MASK = { C = 1, c = 0.62 }
local SOCLE = 0.5

Structures.art = {
    capital = {
        frames = { { "Y.Y.Y", "YYYYy", "LCCCD", "LWCWD", "MMMMD" } },
        shine = true
    },
    city = {
        frames = { { "Rr.Rr", "RrRRr", "LWDRr", "LDLWD", "LWDWD" } },
        windows = true
    },
    tradePort = {
        frames = {
            { ".CC..", ".Cg..", "yyg.G", "YyGGg", "CCCCC" },
            { "CC...", ".Cg..", "yyg.G", "YyGGg", "CCCCC" }
        },
        fps = 3
    },
    militaryPort = {
        frames = { { ".gGg.", "..G..", "GGGGg", "G.G.g", ".GGg." } },
        beacon = { 2, 0 }
    },
    factory = {
        frames = { { "g....", "gR.R.", "gRrRr", "LWLWD", "MMMMD" } },
        smoke = { 0, 0 },
        windows = true
    },
    barracks = {
        frames = {
            { "Cc...", "g..Rr", "gRRRr", "MWMWD", "DDDDD" },
            { "cC...", "g..Rr", "gRRRr", "MWMWD", "DDDDD" }
        },
        fps = 2
    },
    farm = {
        frames = {
            { ".Rr..", "RRRr.", "LWLD.", "YyYyY", "yYyYy" },
            { ".Rr..", "RRRr.", "LWLD.", "yYyYy", "YyYyY" }
        },
        fps = 1.5
    },
    mine = {
        frames = {
            { "..M..", ".MLD.", "MLWWD", "LWWWD", "yYgYy" },
            { "..M..", ".MLD.", "MLWWD", "LWWYD", "yYgYy" }
        },
        fps = 2
    },
    defensePost = {
        frames = { { "L.L.L", "LLLLD", "LCCCD", "LCcCD", "MMMMD" } }
    },
    silo = {
        frames = { { ".GGg.", "GLRLg", "GLRLg", "GLRLg", ".ggg." } },
        light = { 2, 0 }
    },
    sam = {
        frames = {
            { "RGg.R", ".R.R.", "..G..", ".GGg.", "GGGgg" },
            { "R.G.R", ".RGR.", "..G..", ".GGg.", "GGGgg" },
            { "R.gGR", ".R.R.", "..G..", ".GGg.", "GGGgg" }
        },
        fps = 4
    }
}

Structures.badges = {
    city = { "x.x", "xxx", "xxx" },
    tradePort = { "xxx", ".x.", "xxx" },
    militaryPort = { ".x.", ".x.", "xxx" },
    factory = { "x..", "xxx", "xxx" },
    barracks = { "x.x", "x.x", "xxx" },
    mine = { "x.x", ".x.", "x.x" },
    farm = { "xxx", "...", "xxx" },
    defensePost = { "xxx", "xxx", ".x." },
    silo = { ".x.", "xxx", "x.x" },
    sam = { "x.x", ".x.", "xxx" }
}

local KINDS = { "capital", "city", "tradePort", "militaryPort", "factory", "barracks", "mine", "farm", "defensePost", "silo", "sam" }

local atlas, quads, rowOf = nil, {}, {}

local function expand(rows)
    local grid = {}
    for y = 0, SIZE - 1 do
        grid[y] = {}
        for x = 0, SIZE - 1 do
            grid[y][x] = "."
        end
    end
    for row = 1, #rows do
        for col = 1, #rows[row] do
            grid[row][col] = rows[row]:sub(col, col)
        end
    end
    local art = {}
    for y = 0, SIZE - 1 do
        art[y] = {}
        for x = 0, SIZE - 1 do
            art[y][x] = grid[y][x] ~= "."
        end
    end
    local solid = {}
    for y = 0, SIZE - 1 do
        solid[y] = {}
        for x = 0, SIZE - 1 do
            local edge = not art[y][x] and ((art[y - 1] and art[y - 1][x]) or (art[y + 1] and art[y + 1][x]) or art[y][x - 1] or art[y][x + 1])
            if edge then
                grid[y][x] = "k"
            end
            solid[y][x] = art[y][x] or edge or false
        end
    end
    for x = 0, SIZE - 1 do
        if grid[SIZE - 1][x] == "k" then
            grid[SIZE - 1][x] = "s"
        end
    end
    return grid, solid
end

local function paint(data, ox, oy, grid, solid)
    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            if solid[y][x] and not (solid[y + 1] and solid[y + 1][x + 1]) then
                data:setPixel(ox + x + 1, oy + y + 1, INK[1], INK[2], INK[3], 0.4)
            end
        end
    end
    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            local ch = grid[y][x]
            local base = LAYERS.base * MAX_FRAMES * CELL
            local mask = LAYERS.mask * MAX_FRAMES * CELL
            local silhouette = LAYERS.silhouette * MAX_FRAMES * CELL
            if ch ~= "." then
                data:setPixel(silhouette + ox + x, oy + y, 1, 1, 1, 1)
            end
            if ch == "k" then
                data:setPixel(base + ox + x, oy + y, INK[1], INK[2], INK[3], 1)
            elseif ch == "s" then
                data:setPixel(mask + ox + x, oy + y, SOCLE, SOCLE, SOCLE, 1)
            elseif MASK[ch] then
                local v = MASK[ch]
                data:setPixel(mask + ox + x, oy + y, v, v, v, 1)
            elseif COLORS[ch] then
                local c = COLORS[ch]
                data:setPixel(base + ox + x, oy + y, c[1], c[2], c[3], 1)
            end
        end
    end
end

local function build()
    local data = love.image.newImageData(CELL * MAX_FRAMES * 3, CELL * #KINDS)
    for row, kind in ipairs(KINDS) do
        rowOf[kind] = row - 1
        local def = Structures.art[kind]
        def.cells = {}
        for frame, art in ipairs(def.frames) do
            local grid, solid = expand(art)
            paint(data, (frame - 1) * CELL, (row - 1) * CELL, grid, solid)
            if frame == 1 then
                for y = 0, SIZE - 1 do
                    for x = 0, SIZE - 1 do
                        if grid[y][x] == "W" then
                            def.cells[#def.cells + 1] = { x, y }
                        end
                    end
                end
            end
        end
    end
    atlas = love.graphics.newImage(data)
    atlas:setFilter("nearest", "nearest")
end

function Structures.quad(kind, frame, layer, rows)
    if not atlas then build() end
    rows = rows or CELL
    local key = kind .. ":" .. frame .. ":" .. layer .. ":" .. rows
    local quad = quads[key]
    if not quad then
        local x = (LAYERS[layer] * MAX_FRAMES + frame - 1) * CELL
        local y = rowOf[kind] * CELL + CELL - rows
        quad = love.graphics.newQuad(x, y, CELL, rows, atlas:getDimensions())
        quads[key] = quad
    end
    return quad
end

function Structures.has(kind)
    return Structures.art[kind] ~= nil
end

function Structures.frame(kind, time)
    local def = Structures.art[kind]
    local count = #def.frames
    if count == 1 then return 1 end
    return math.floor(time * (def.fps or 3)) % count + 1
end

function Structures.layer(kind, frame, layer, x, y, scale, color, alpha, rows)
    rows = rows or CELL
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.draw(atlas, Structures.quad(kind, frame, layer, rows), x, y + (CELL - rows) * scale, 0, scale, scale)
end

function Structures.draw(kind, x, y, scale, owner, alpha, options)
    options = options or {}
    local frame = options.frame or 1
    local rows = options.rows
    local white = { 1, 1, 1 }
    Structures.quad(kind, frame, "base")
    Structures.layer(kind, frame, "base", x, y, scale, white, alpha, rows)
    Structures.layer(kind, frame, "mask", x, y, scale, owner, alpha, rows)
end

function Structures.icon(kind, x, y, size, owner, alpha)
    if not Structures.has(kind) then return false end
    local scale = size / CELL
    Structures.draw(kind, x, y, scale, owner, alpha or 1)
    return true
end

Structures.CELL = CELL
Structures.SIZE = SIZE

return Structures
