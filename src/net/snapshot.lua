local ffi = require("ffi")
local Buffer = require("src.net.buffer")
local Player = require("src.modules.player.player")
local NumHeap = require("src.modules.algorithms.numheap")
local Random = require("src.core.random")

local Snapshot = {}

local FORMAT = 2

local NIL, FALSE, TRUE, UINT, NINT, DOUBLE, STRING, TABLE, REF, PLAYER, FUNC = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
local MAX_INT = 2 ^ 53
local floor = math.floor

local CLASSES = { Player = Player, NumHeap = NumHeap, Random = Random }

local LOCAL_FIELDS = {
    map = true, renderer = true, handlers = true, intentHandlers = true, options = true, human = true,
    events = true, eventSerial = true, accumulator = true, speedIndex = true, paused = true, lockstep = true,
    pathfinder = true, echoes = true, nukeAlerts = true, radarCache = true, seed = true, authority = true,
    aiRng = true, commandSink = true, headless = true, combat = true, tradeRoutes = true
}

local PLAYER_LOCAL_FIELDS = {
    id = true, color = true, color255 = true, attackRatio = true, brain = true, nextDecision = true, requestEvents = true, pactEvents = true,
    borders = true, supplyCache = true, aiMemory = true
}

local classNames
local functionNames
local functionsByName

local function registry()
    if classNames then return end
    classNames = {}
    for name, class in pairs(CLASSES) do
        classNames[class] = name
    end
    functionNames, functionsByName = {}, {}
    local Game = require("src.modules.game.game")
    for _, path in ipairs(Game.SystemPaths) do
        local module = require(path)
        for key, value in pairs(module) do
            if type(value) == "function" then
                local name = path .. "." .. key
                functionNames[value] = name
                functionsByName[name] = value
            end
        end
    end
end

local function writeRuns(w, array, size)
    local k = 0
    while k < size do
        local value = array[k]
        local j = k + 1
        while j < size and array[j] == value do
            j = j + 1
        end
        w:varint(value)
        w:varint(j - k)
        k = j
    end
end

local function readRuns(r, array, size)
    local k = 0
    while k < size do
        local value = r:varint()
        local count = r:varint()
        if count < 1 or k + count > size then error("Snapshot: corrupted map runs") end
        for j = k, k + count - 1 do
            array[j] = value
        end
        k = k + count
    end
end

local Encoder = {}
Encoder.__index = Encoder

function Encoder:value(v, skip)
    local w = self.w
    local kind = type(v)
    if v == nil then
        w:u8(NIL)
    elseif kind == "boolean" then
        w:u8(v and TRUE or FALSE)
    elseif kind == "number" then
        if v == floor(v) and v >= -MAX_INT and v <= MAX_INT then
            if v >= 0 then
                w:u8(UINT)
                w:varint(v)
            else
                w:u8(NINT)
                w:varint(-v)
            end
        else
            w:u8(DOUBLE)
            w:double(v)
        end
    elseif kind == "string" then
        w:u8(STRING)
        w:string(v)
    elseif kind == "function" then
        local name = functionNames[v]
        if not name then error("Snapshot: unregistered function") end
        w:u8(FUNC)
        w:string(name)
    elseif kind == "table" then
        if getmetatable(v) == Player then
            w:u8(PLAYER)
            w:varint(v.id)
            return
        end
        local id = self.ids[v]
        if id then
            w:u8(REF)
            w:varint(id)
            return
        end
        self.count = self.count + 1
        self.ids[v] = self.count
        w:u8(TABLE)
        local mt = getmetatable(v)
        local class = mt and classNames[mt]
        if mt and not class then error("Snapshot: unregistered class") end
        w:string(class or "")
        self:fields(v, skip)
    else
        error("Snapshot: cannot encode " .. kind)
    end
end

local function packable(t, n)
    if n < 8 then return false end
    for k = 1, n do
        local v = t[k]
        if type(v) ~= "number" or v ~= floor(v) or v < -MAX_INT or v > MAX_INT then return false end
    end
    return true
end

function Encoder:fields(t, skip)
    local w = self.w
    local n = #t
    w:varint(n)
    if packable(t, n) then
        w:u8(1)
        local previous = 0
        for k = 1, n do
            w:svarint(t[k] - previous)
            previous = t[k]
        end
    else
        w:u8(0)
        for k = 1, n do
            self:value(t[k])
        end
    end
    local keys = {}
    for k, v in pairs(t) do
        local array = type(k) == "number" and k >= 1 and k <= n and k == floor(k)
        if not array and not (skip and skip[k]) and type(v) ~= "cdata" and type(v) ~= "userdata" then
            keys[#keys + 1] = k
        end
    end
    w:varint(#keys)
    for _, k in ipairs(keys) do
        self:value(k)
        self:value(t[k])
    end
end

local Decoder = {}
Decoder.__index = Decoder

function Decoder:value()
    local r = self.r
    local tag = r:u8()
    if tag == NIL then
        return nil
    elseif tag == FALSE then
        return false
    elseif tag == TRUE then
        return true
    elseif tag == UINT then
        return r:varint()
    elseif tag == NINT then
        return -r:varint()
    elseif tag == DOUBLE then
        return r:double()
    elseif tag == STRING then
        return r:string()
    elseif tag == FUNC then
        local name = r:string()
        local fn = functionsByName[name]
        if not fn then error("Snapshot: unknown function " .. name) end
        return fn
    elseif tag == PLAYER then
        local player = self.players[r:varint()]
        if not player then error("Snapshot: unknown player") end
        return player
    elseif tag == REF then
        local t = self.tables[r:varint()]
        if not t then error("Snapshot: dangling reference") end
        return t
    elseif tag == TABLE then
        local t = {}
        self.count = self.count + 1
        self.tables[self.count] = t
        local class = r:string()
        if class ~= "" then
            if not CLASSES[class] then error("Snapshot: unknown class " .. class) end
            setmetatable(t, CLASSES[class])
        end
        self:fields(t)
        return t
    end
    error("Snapshot: unknown tag " .. tostring(tag))
end

function Decoder:fields(t)
    local r = self.r
    local n = r:varint()
    if r:u8() == 1 then
        local previous = 0
        for k = 1, n do
            previous = previous + r:svarint()
            t[k] = previous
        end
    else
        for k = 1, n do
            t[k] = self:value()
        end
    end
    for _ = 1, r:varint() do
        local key = self:value()
        t[key] = self:value()
    end
end

function Snapshot.encode(game)
    registry()
    local w = Buffer.writer(1048576)
    local map = game.map
    w:varint(FORMAT)
    w:varint(game.tick)
    w:varint(map.size)
    w:varint(#game.players)
    writeRuns(w, map.owner, map.size)
    writeRuns(w, map.fallout, map.size)
    local encoder = setmetatable({ w = w, ids = {}, count = 0 }, Encoder)
    for _, player in ipairs(game.players) do
        w:string(player.kind)
        w:string(player.name)
        encoder:fields(player, PLAYER_LOCAL_FIELDS)
    end
    encoder:fields(game, LOCAL_FIELDS)
    w:varint(game:checksum())
    return love.data.compress("string", "zlib", w:tostring())
end

local function rebuildBorders(map, players)
    for _, player in ipairs(players) do
        player.borders = {}
        player.supplyCache = player.supplyPoints and {} or nil
    end
    local own = map.owner
    local w, size = map.width, map.size
    for i = 0, size - 1 do
        local o = own[i]
        if o ~= 0 then
            local x = i % w
            if (x > 0 and own[i - 1] ~= o) or (x < w - 1 and own[i + 1] ~= o)
                or (i >= w and own[i - w] ~= o) or (i < size - w and own[i + w] ~= o) then
                players[o].borders[i] = true
            end
        end
    end
end

local function clearFields(t, keep)
    local keys = {}
    for k in pairs(t) do
        if not keep[k] then keys[#keys + 1] = k end
    end
    for _, k in ipairs(keys) do
        t[k] = nil
    end
end

function Snapshot.apply(game, data, colorFor)
    registry()
    local r = Buffer.reader(love.data.decompress("string", "zlib", data))
    if r:varint() ~= FORMAT then error("Snapshot: unsupported format") end
    local tick = r:varint()
    local map = game.map
    if r:varint() ~= map.size then error("Snapshot: map size mismatch") end
    local count = r:varint()
    local owner = ffi.new("uint16_t[?]", map.size)
    local fallout = ffi.new("uint8_t[?]", map.size)
    readRuns(r, owner, map.size)
    readRuns(r, fallout, map.size)

    local players = {}
    for id = 1, count do
        players[id] = game.players[id] or setmetatable({ id = id }, Player)
    end
    local decoder = setmetatable({ r = r, tables = {}, count = 0, players = players }, Decoder)
    for id = 1, count do
        local player = players[id]
        local kind, name = r:string(), r:string()
        clearFields(player, PLAYER_LOCAL_FIELDS)
        player.id = id
        player.kind = kind
        player.name = name
        decoder:fields(player)
        if not player.color then
            player:setColor(colorFor(player))
        end
    end
    local state = {}
    decoder:fields(state)
    local expected = r:varint()

    ffi.copy(map.owner, owner, map.size * 2)
    ffi.copy(map.fallout, fallout, map.size)
    for k = #game.players, count + 1, -1 do
        game.players[k] = nil
    end
    for id = 1, count do
        game.players[id] = players[id]
    end
    for key, value in pairs(state) do
        game[key] = value
    end
    rebuildBorders(map, game.players)
    game.tick = tick
    game.intents = {}
    return tick, expected
end

return Snapshot
