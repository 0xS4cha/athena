local Config = require("src.config.game")
local NumHeap = require("src.modules.algorithms.numheap")
local Format = require("src.core.format")
local Supply = require("src.modules.game.systems.supply")

local Attack = {}

local TILE_SPACE = 8388608
local floor = math.floor

local function adjacency(map, i, id)
    local own = map.owner
    local w = map.width
    local x = i % w
    local n = 0
    if x > 0 and own[i - 1] == id then n = n + 1 end
    if x < w - 1 and own[i + 1] == id then n = n + 1 end
    if i >= w and own[i - w] == id then n = n + 1 end
    if i < map.size - w and own[i + w] == id then n = n + 1 end
    return n
end

local function enqueue(game, attack, j)
    if attack.queued[j] then return end
    local map = game.map
    local adj = adjacency(map, j, attack.attacker.id)
    if adj == 0 then return end
    attack.queued[j] = true
    local priority = floor((attack.wave + game.rng:random() * 2 - adj * 0.6 + 10) * 100)
    attack.queue:push(priority * TILE_SPACE + j)
end

local function enqueueNeighbors(game, attack, i)
    local map = game.map
    local nb = attack.nb
    local count = map:neighbors(i, nb)
    for k = 1, count do
        local j = nb[k]
        if map.owner[j] == attack.targetId and map:isLand(j) then
            enqueue(game, attack, j)
        end
    end
end

function Attack.refreshFront(game, attack)
    for b in pairs(attack.attacker.borders) do
        enqueueNeighbors(game, attack, b)
    end
end

function Attack.sharesBorder(game, player, targetId)
    local map = game.map
    local nb = {}
    for b in pairs(player.borders) do
        local count = map:neighbors(b, nb)
        for k = 1, count do
            local j = nb[k]
            if map.owner[j] == targetId and map:isLand(j) then
                return true
            end
        end
    end
    return false
end

function Attack.neighbors(game, player)
    local map = game.map
    local own = map.owner
    local nb = {}
    local found = {}
    local neutral = false
    for b in pairs(player.borders) do
        local count = map:neighbors(b, nb)
        for k = 1, count do
            local j = nb[k]
            local o = own[j]
            if o ~= player.id and map:isLand(j) then
                if o == 0 then
                    neutral = true
                else
                    found[o] = true
                end
            end
        end
    end
    local list = {}
    for id in pairs(found) do
        list[#list + 1] = game.players[id]
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list, neutral
end

function Attack.biomeMultiplier(player, biomeName)
    local biome = Config.biomes[biomeName]
    return biome.cost * (1 + biome.penalty * (1 - player:familiarity(biome.id)))
end

function Attack.terrainMultiplier(game, i, attacker)
    local map = game.map
    local name = map:terrainType(i)
    local mult = attacker and Attack.biomeMultiplier(attacker, name) or Config.biomes[name].cost
    if map.fallout[i] > 0 then
        mult = mult * Config.falloutCost
    end
    return mult
end

function Attack.cost(game, attack, i)
    local terrain = Attack.terrainMultiplier(game, i, attack.attacker)
    if attack.attacker then
        terrain = terrain * Supply.multiplier(game, attack.attacker, i)
    end
    local target = attack.target
    if not target then
        return Config.neutralTileCost * terrain, 0
    end
    local density = target.troops / math.max(1, target.tiles)
    local defense = 1
    if game.defenseBonus then
        defense = game:defenseBonus(target, i)
    end
    if target.traitorUntil > game.tick then
        defense = defense * Config.traitorDefense
    end
    return (Config.playerTileCost + density * Config.densityCost) * terrain * defense, density * Config.defenderLoss
end

function Attack.tilesPerTick(attack)
    local divisor = attack.target and Config.playerSpeedDivisor or Config.neutralSpeedDivisor
    return math.max(1, math.min(Config.maxTilesPerTick, math.floor(math.sqrt(attack.troops) / divisor)))
end

function Attack.find(game, attacker, targetId)
    for _, attack in ipairs(game.attacks) do
        if not attack.done and attack.attacker == attacker and attack.targetId == targetId then
            return attack
        end
    end
    return nil
end

function Attack.finish(game, attack, refund)
    if attack.done then return end
    attack.done = true
    if attack.attacker.alive then
        attack.attacker.troops = attack.attacker.troops + attack.troops * (refund or 1)
    end
    attack.troops = 0
end

function Attack.launch(game, attacker, targetId, troops)
    troops = math.floor(math.min(troops, attacker.troops))
    if troops < 1 then return nil end
    local target = targetId ~= 0 and game.players[targetId] or nil

    attacker.troops = attacker.troops - troops

    if target then
        local counter = Attack.find(game, target, attacker.id)
        if counter then
            local cancel = math.min(troops, counter.troops)
            troops = troops - cancel
            counter.troops = counter.troops - cancel
            if counter.troops <= 0 then
                Attack.finish(game, counter)
            end
            if troops <= 0 then
                return nil
            end
        end
    end

    local existing = Attack.find(game, attacker, targetId)
    if existing then
        existing.troops = existing.troops + troops
        Attack.refreshFront(game, existing)
        return existing
    end

    game.attackSerial = game.attackSerial + 1
    local attack = {
        id = game.attackSerial,
        attacker = attacker,
        target = target,
        targetId = targetId,
        troops = troops,
        initialTroops = troops,
        queue = NumHeap.new(),
        queued = {},
        nb = {},
        wave = 0,
        startTick = game.tick
    }
    Attack.refreshFront(game, attack)
    if attack.queue:empty() then
        attacker.troops = attacker.troops + troops
        return nil
    end
    table.insert(game.attacks, attack)
    game:emit("attackLaunched", attack)
    if target then
        game:notify(target, string.format("%s is attacking you with %s troops!", attacker.name, Format.number(troops)), { color = { 0.95, 0.35, 0.3, 1 } })
    end
    return attack
end

function Attack.stepAttack(game, attack)
    local attacker = attack.attacker
    local target = attack.target
    if not attacker.alive then
        Attack.finish(game, attack)
        return
    end
    if target and (not target.alive or attacker:isAlliedWith(target)) then
        Attack.finish(game, attack)
        return
    end

    local map = game.map
    local own = map.owner
    attack.wave = attack.wave + 1
    local budget = Attack.tilesPerTick(attack)
    while budget > 0 do
        local item = attack.queue:pop()
        if not item then
            Attack.finish(game, attack)
            return
        end
        local i = item % TILE_SPACE
        attack.queued[i] = nil
        if own[i] == attack.targetId and adjacency(map, i, attacker.id) > 0 then
            local cost, loss = Attack.cost(game, attack, i)
            if attack.troops < cost then
                Attack.finish(game, attack)
                return
            end
            attack.troops = attack.troops - cost
            if target then
                target.troops = math.max(0, target.troops - loss)
            end
            game:setOwner(i, attacker.id)
            enqueueNeighbors(game, attack, i)
            Attack.recordFront(game, attack, i)
            budget = budget - 1
            if target and not target.alive then
                Attack.finish(game, attack)
                return
            end
        end
    end
end

function Attack.init(game)
    game.attacks = {}
    game.attackSerial = 0
    game.combat = { tiles = {}, ticks = {}, head = 0 }
end

function Attack.recordFront(game, attack, i)
    local recent = attack.recent
    if not recent then
        recent = { head = 0 }
        attack.recent = recent
    end
    recent.head = recent.head % Config.recentFront + 1
    recent[recent.head] = i
    if attack.target then
        local combat = game.combat
        combat.head = combat.head % Config.combatBuffer + 1
        combat.tiles[combat.head] = i
        combat.ticks[combat.head] = game.tick
    end
end

function Attack.step(game)
    if game.phase ~= "playing" then return end
    local list = game.attacks
    for k = 1, #list do
        local attack = list[k]
        if not attack.done then
            Attack.stepAttack(game, attack)
        end
    end
    for k = #list, 1, -1 do
        if list[k].done then
            table.remove(list, k)
        end
    end
end

function Attack.eliminated(game, player)
    for _, attack in ipairs(game.attacks) do
        if attack.attacker == player then
            attack.done = true
        end
    end
end

function Attack.outgoing(game, player)
    local list = {}
    for _, attack in ipairs(game.attacks) do
        if attack.attacker == player and not attack.done then
            list[#list + 1] = attack
        end
    end
    return list
end

function Attack.incoming(game, player)
    local list = {}
    for _, attack in ipairs(game.attacks) do
        if attack.target == player and not attack.done then
            list[#list + 1] = attack
        end
    end
    return list
end

Attack.intents = {
    attack = function(game, intent)
        if game.phase ~= "playing" then return end
        local attacker = game.players[intent.player]
        if not attacker or not attacker.alive then return end
        local targetId = intent.target or 0
        local target = targetId ~= 0 and game.players[targetId] or nil
        if target == attacker then return end
        if target and (not target.alive or attacker:isAlliedWith(target)) then return end
        local troops = intent.troops or attacker.troops * (intent.ratio or attacker.attackRatio)
        Attack.launch(game, attacker, targetId, troops)
    end,
    retreat = function(game, intent)
        for _, attack in ipairs(game.attacks) do
            if attack.id == intent.attack and attack.attacker.id == intent.player then
                Attack.finish(game, attack, Config.retreatRefund)
            end
        end
    end
}

return Attack
