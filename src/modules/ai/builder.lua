local Units = require("src.modules.game.systems.units")

local Builder = {}

local function randomOwnTile(game, player, predicate)
    local map = game.map
    local rng = game.rng
    local cx, cy = player:center()
    local spread = math.sqrt(player.tiles) * 0.6
    for _ = 1, 12 do
        local tile = map:findNear(cx + (rng:random() * 2 - 1) * spread, cy + (rng:random() * 2 - 1) * spread, 8, function(i)
            return map.owner[i] == player.id and (not predicate or predicate(i))
        end)
        if tile then return tile end
    end
    return nil
end

local function coastTile(game, player)
    local map = game.map
    local candidates = {}
    for b in pairs(player.borders) do
        if map:isCoast(b) then
            candidates[#candidates + 1] = b
            if #candidates > 200 then break end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[game.rng:random(#candidates)]
end

local function frontTile(game, player, enemy)
    local map = game.map
    local nb = {}
    local candidates = {}
    for b in pairs(player.borders) do
        local count = map:neighbors(b, nb)
        for k = 1, count do
            if map.owner[nb[k]] == enemy.id then
                candidates[#candidates + 1] = b
                break
            end
        end
        if #candidates > 100 then break end
    end
    if #candidates == 0 then return nil end
    return candidates[game.rng:random(#candidates)]
end

function Builder.request(game, player, kind, tile)
    if not tile then return false end
    local ok = Units.check(game, player, kind, tile)
    if not ok then return false end
    game:pushIntent({ type = "build", player = player.id, unit = kind, tile = tile })
    return true
end

Builder.wishes = {
    function(game, player)
        if player:unitCount("city") < 1 + math.floor(player.tiles / 12000) then
            return "city", randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
        end
    end,
    function(game, player)
        if player:unitCount("port") < 1 + math.floor(player:unitCount("city") / 2) then
            local tile = coastTile(game, player)
            if tile then return "port", tile end
        end
    end,
    function(game, player)
        local cities = player:unitCount("city")
        if cities >= 2 and player:unitCount("factory") < 1 + math.floor(cities / 3) then
            return "factory", randomOwnTile(game, player, function(i) return Units.isSpaced(game, i) end)
        end
    end,
    function(game, player)
        if player:unitCount("port") > 0 and player:unitCount("warship") < math.ceil(player:unitCount("port") / 2) and game.rng:random() < 0.3 then
            local port = Units.nearestPort(game, player, player.spawnTile or 0)
            if port then return "warship", port.tile end
        end
    end,
    function(game, player, ctx)
        if player:unitCount("defensePost") >= 2 + math.floor(player.tiles / 20000) then return end
        for _, other in ipairs(ctx.neighbors) do
            if not player:isAlliedWith(other) and other.troops > player.troops * 1.2 then
                return "defensePost", frontTile(game, player, other)
            end
        end
    end
}

function Builder.behavior(game, player, ctx)
    if game.rng:random() > 0.5 then return false end
    for _, wish in ipairs(Builder.wishes) do
        local kind, tile = wish(game, player, ctx)
        if kind and tile and player.gold >= Units.cost(game, player, kind) then
            if Builder.request(game, player, kind, tile) then
                return false
            end
        end
    end
    return false
end

return Builder
