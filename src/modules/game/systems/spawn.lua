local Config = require("src.config.game")

local Spawn = {}

local BOT_PREFIXES = {
    "Northern", "Southern", "Iron", "Red", "Black", "Golden", "Silver", "Storm", "Wild", "Ancient",
    "Free", "Grand", "High", "Lost", "Sacred", "Stone", "Sun", "Moon", "River", "Ash"
}

local BOT_SUFFIXES = {
    "Tribe", "Clan", "Horde", "League", "Union", "Realm", "Order", "Pact", "Kin", "Band",
    "Confederacy", "Dominion", "Brotherhood", "Hold", "Marches"
}

local function botName(game)
    local rng = game.rng
    return BOT_PREFIXES[rng:random(#BOT_PREFIXES)] .. " " .. BOT_SUFFIXES[rng:random(#BOT_SUFFIXES)]
end

local function isFree(game, tile, margin)
    local map = game.map
    if not map:isLand(tile) or map.owner[tile] ~= 0 then
        return false
    end
    local x, y = map:coords(tile)
    local offsets = { { margin, 0 }, { -margin, 0 }, { 0, margin }, { 0, -margin } }
    for _, o in ipairs(offsets) do
        local tx, ty = x + o[1], y + o[2]
        if map:isValid(tx, ty) and map.owner[map:index(tx, ty)] ~= 0 then
            return false
        end
    end
    return true
end

function Spawn.randomTile(game)
    local map = game.map
    local rng = game.rng
    for _ = 1, Config.botSpawnAttempts do
        local tile = rng:random(0, map.size - 1)
        if isFree(game, tile, Config.spawnRadius * 2 + 2) then
            return tile
        end
    end
    return nil
end

function Spawn.clear(game, player)
    if not player.spawnTile then return end
    local map = game.map
    local x, y = map:coords(player.spawnTile)
    map:forDisk(x, y, Config.spawnRadius + 1, function(i)
        if map.owner[i] == player.id then
            game:setOwner(i, 0)
        end
    end)
    player.spawned = false
    player.spawnTile = nil
end

function Spawn.place(game, player, tile)
    local map = game.map
    if not map:isLand(tile) or map.owner[tile] ~= 0 then
        return false
    end
    Spawn.clear(game, player)
    local x, y = map:coords(tile)
    game:claimDisk(player, x, y, Config.spawnRadius)
    player.spawnTile = tile
    player.spawned = true
    player.troops = Config.startTroops
    player.workers = Config.startWorkers
    return true
end

function Spawn.setup(game)
    game.phase = "spawn"
    game.spawnTicksLeft = Config.spawnSeconds * Config.tickRate
    local map = game.map

    if game.options.nations ~= false then
        for _, nation in ipairs(map.manifest.nations or {}) do
            if nation.coordinates then
                local player = game:addPlayer(nation.name, "nation", nation.flag)
                local tile = map:findNear(nation.coordinates[1], nation.coordinates[2], Config.nationSpawnSearch, function(i)
                    return isFree(game, i, Config.spawnRadius)
                end)
                if tile then
                    Spawn.place(game, player, tile)
                else
                    player.alive = false
                end
            end
        end
    end

    for _ = 1, game.options.bots or 0 do
        local tile = Spawn.randomTile(game)
        if not tile then break end
        local player = game:addPlayer(botName(game), "bot")
        Spawn.place(game, player, tile)
    end
end

function Spawn.finish(game)
    local human = game.human
    if not human.spawned then
        local tile = Spawn.randomTile(game)
        if tile then
            Spawn.place(game, human, tile)
        else
            human.alive = false
        end
    end
    game.phase = "playing"
    game:addEvent("The game has started. Expand your territory!", { color = { 0.3, 0.85, 0.45, 1 } })
    game:emit("started")
end

function Spawn.step(game)
    if game.phase ~= "spawn" then return end
    game.spawnTicksLeft = game.spawnTicksLeft - 1
    if game.spawnTicksLeft <= 0 then
        Spawn.finish(game)
    end
end

Spawn.intents = {
    spawn = function(game, intent)
        if game.phase ~= "spawn" then return end
        local player = game.players[intent.player]
        if player then
            Spawn.place(game, player, intent.tile)
        end
    end,
    start = function(game)
        if game.phase == "spawn" and game.human.spawned then
            game.spawnTicksLeft = 0
        end
    end
}

return Spawn
