local json = require("libs.json")
local Codec = require("src.net.codec")
local NetConfig = require("src.net.config")

local ReplayFile = { dir = "replays", keep = 20 }

local MAGIC = "ATHENA-REPLAY"
local FORMAT = 1
local PREFIX_BYTES = 64

local function path(name)
    return ReplayFile.dir .. "/" .. name
end

local function parsePrefix(content)
    local format, size, stop = content:match("^ATHENA%-REPLAY (%d+) (%d+)\n()")
    if not format then return nil end
    return tonumber(format), tonumber(size), stop
end

local function validHeader(header)
    if type(header) ~= "table" or type(header.seed) ~= "number" or type(header.ticks) ~= "number" or type(header.slot) ~= "number" then return false end
    if type(header.players) ~= "table" or type(header.settings) ~= "table" then return false end
    local map = header.settings.map
    return type(map) == "string" and map:match("^assets/maps/[%w_%-]+/$") ~= nil
end

local function decodeHeader(content, size, stop)
    local ok, header = pcall(json.decode, content:sub(stop, stop + size - 1))
    if ok and validHeader(header) then return header end
    return nil
end

function ReplayFile.slug(text)
    local slug = tostring(text or "game"):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    return slug ~= "" and slug or "game"
end

function ReplayFile.save(header, frames)
    love.filesystem.createDirectory(ReplayFile.dir)
    header.version = NetConfig.version
    header.date = header.date or os.time()
    local stem = os.date("%Y%m%d-%H%M%S", header.date) .. "-" .. ReplayFile.slug(header.mapName)
    local name, serial = stem .. ".replay", 1
    while love.filesystem.getInfo(path(name)) do
        serial = serial + 1
        name = stem .. "-" .. serial .. ".replay"
    end
    local head = json.encode(header)
    local body = love.data.compress("string", "zlib", Codec.encode(frames))
    if not love.filesystem.write(path(name), string.format("%s %d %d\n", MAGIC, FORMAT, #head) .. head .. body) then
        return nil
    end
    ReplayFile.prune()
    return name
end

function ReplayFile.names()
    local names = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(ReplayFile.dir)) do
        if item:match("%.replay$") then names[#names + 1] = item end
    end
    table.sort(names, function(a, b) return a > b end)
    return names
end

function ReplayFile.prune()
    local names = ReplayFile.names()
    for k = ReplayFile.keep + 1, #names do
        love.filesystem.remove(path(names[k]))
    end
end

function ReplayFile.header(name)
    local prefix = love.filesystem.read(path(name), PREFIX_BYTES)
    if not prefix then return nil end
    local format, size, stop = parsePrefix(prefix)
    if format ~= FORMAT then return nil end
    local content = love.filesystem.read(path(name), stop + size - 1)
    return content and decodeHeader(content, size, stop)
end

function ReplayFile.list()
    local list = {}
    for _, name in ipairs(ReplayFile.names()) do
        local header = ReplayFile.header(name)
        if header then
            list[#list + 1] = { name = name, header = header, outdated = header.version ~= NetConfig.version }
        end
    end
    return list
end

function ReplayFile.load(name)
    local content = love.filesystem.read(path(name))
    if not content then return nil, "This replay no longer exists" end
    local format, size, stop = parsePrefix(content)
    if format ~= FORMAT then return nil, "This file is not a valid replay" end
    local header = decodeHeader(content, size, stop)
    if not header then return nil, "This replay is damaged" end
    if header.version ~= NetConfig.version then return nil, "This replay was recorded with another version of the game" end
    if not love.filesystem.getInfo(header.settings.map .. "map.bin") then return nil, "The map of this replay is missing" end
    local ok, raw = pcall(love.data.decompress, "string", "zlib", content:sub(stop + size))
    local frames = ok and Codec.decode(raw)
    if type(frames) ~= "table" then return nil, "This replay is damaged" end
    return { name = name, header = header, frames = frames }
end

function ReplayFile.delete(name)
    return love.filesystem.remove(path(name))
end

return ReplayFile
