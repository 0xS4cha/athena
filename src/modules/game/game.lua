local Class = require("src.core.class")
local Config = require("src.config.game")
local Map = require("src.modules.map.map")
local Renderer = require("src.modules.map.renderer")
local Player = require("src.modules.player.player")
local Palette = require("src.modules.player.palette")
local Random = require("src.core.random")
local Hash = require("src.core.hash")

local SystemPaths = {
    "src.modules.game.systems.spawn",
    "src.modules.game.systems.economy",
    "src.modules.game.systems.supply",
    "src.modules.game.systems.attack",
    "src.modules.game.systems.units",
    "src.modules.game.systems.capital",
    "src.modules.game.systems.ships",
    "src.modules.game.systems.rails",
    "src.modules.game.systems.nukes",
    "src.modules.game.systems.vision",
    "src.modules.game.systems.diplomacy",
    "src.modules.game.systems.loans",
    "src.modules.game.systems.ai",
    "src.modules.game.systems.victory"
}

local Systems = {}
for k, path in ipairs(SystemPaths) do
    Systems[k] = require(path)
end

local HeadlessRenderer = {
    layers = {},
    paintTile = function() end,
    repaintAll = function() end
}

local Game = Class()

Game.SystemPaths = SystemPaths

function Game:init(options)
    self.options = options or {}
    self.seed = self.options.seed or os.time()
    self.rng = Random.new(self.seed)
    self.aiRng = Random.new(self.seed + 7919)
    self.authority = self.options.authority ~= false
    self.headless = self.options.headless == true
    self.commandSink = nil
    self.ownerHash = 0
    self.handlers = {}
    self.map = Map(self.options.map or Config.defaultMap)
    self.tick = 0
    self.phase = "playing"
    self.players = {}
    self.human = nil
    self.intents = {}
    self.intentHandlers = {}
    self.events = {}
    self.eventSerial = 0
    self.accumulator = 0
    self.speedIndex = 1
    self.paused = false
    self.renderer = self.headless and HeadlessRenderer or Renderer(self)
    self.lockstep = nil
    local humans = self.options.humans or { { name = self.options.playerName or "Player", flag = self.options.playerFlag } }
    local localSlot = self.options.localSlot or (not self.headless and 1 or nil)
    for slot, human in ipairs(humans) do
        local player = self:addPlayer(human.name or "Player", "human", human.flag, slot ~= localSlot and Palette.color(slot) or nil)
        if slot == localSlot then
            self.human = player
        end
    end

    for _, system in ipairs(Systems) do
        if system.intents then
            for name, handler in pairs(system.intents) do
                self.intentHandlers[name] = handler
            end
        end
        if system.init then
            system.init(self)
        end
    end
    self:emit("setup")
end

function Game:addPlayer(name, kind, flag, color)
    local id = #self.players + 1
    color = color or (kind == "human" and Palette.human or kind == "bot" and Palette.tribe or Palette.color(id))
    local player = Player(id, name, kind, color, flag)
    self.players[id] = player
    return player
end

function Game:playerAt(i)
    local id = self.map.owner[i]
    if id == 0 then
        return nil
    end
    return self.players[id]
end

function Game:claimDisk(player, cx, cy, radius)
    local map = self.map
    local count = 0
    map:forDisk(cx, cy, radius, function(i)
        if map:isLand(i) and map.owner[i] == 0 then
            self:setOwner(i, player.id)
            count = count + 1
        end
    end)
    return count
end

function Game:alivePlayers()
    local list = {}
    for _, player in ipairs(self.players) do
        if player.alive and player.spawned then
            list[#list + 1] = player
        end
    end
    return list
end

function Game:refreshBorder(i)
    local map = self.map
    local own = map.owner
    local o = own[i]
    if o ~= 0 then
        local w = map.width
        local x = i % w
        local border = (x > 0 and own[i - 1] ~= o)
            or (x < w - 1 and own[i + 1] ~= o)
            or (i >= w and own[i - w] ~= o)
            or (i < map.size - w and own[i + w] ~= o)
        self.players[o].borders[i] = border or nil
    end
    self.renderer:paintTile(i)
end

function Game:setOwner(i, id)
    local map = self.map
    local old = map.owner[i]
    if old == id then
        return
    end
    local w = map.width
    local x = i % w
    local y = (i - x) / w
    map.owner[i] = id
    if old ~= 0 then self.ownerHash = Hash.toggle(self.ownerHash, i, old) end
    if id ~= 0 then self.ownerHash = Hash.toggle(self.ownerHash, i, id) end

    local previous = old ~= 0 and self.players[old] or nil
    local biome = map.biome[i]
    if previous then
        previous.biomeTiles[biome] = previous.biomeTiles[biome] - 1
        previous.tiles = previous.tiles - 1
        previous.sumX = previous.sumX - x
        previous.sumY = previous.sumY - y
        previous.borders[i] = nil
    end
    if id ~= 0 then
        local p = self.players[id]
        p.biomeTiles[biome] = p.biomeTiles[biome] + 1
        p.tiles = p.tiles + 1
        p.sumX = p.sumX + x
        p.sumY = p.sumY + y
    end

    self:refreshBorder(i)
    if x > 0 then self:refreshBorder(i - 1) end
    if x < w - 1 then self:refreshBorder(i + 1) end
    if i >= w then self:refreshBorder(i - w) end
    if i < map.size - w then self:refreshBorder(i + w) end

    self:emit("tileChanged", i, previous, id)

    if previous and previous.tiles == 0 and self.phase == "playing" then
        self:eliminate(previous, id ~= 0 and self.players[id] or nil)
    end
end

function Game:eliminate(player, by)
    if not player.alive then return end
    player.alive = false
    player.troops = 0
    player.workers = 0
    self:emit("eliminated", player, by)
    if player == self.human then
        self:addEvent("You have been eliminated!", { color = { 0.95, 0.35, 0.3, 1 }, duration = 600 })
    elseif not player:isBot() then
        local text = by and string.format("%s was conquered by %s", player.name, by.name) or (player.name .. " has collapsed")
        self:addEvent(text, { color = { 0.95, 0.6, 0.3, 1 } })
    end
end

function Game:emit(name, ...)
    local list = self.handlers[name]
    if not list then
        list = {}
        for _, system in ipairs(Systems) do
            if system[name] then
                list[#list + 1] = system[name]
            end
        end
        self.handlers[name] = list
    end
    for k = 1, #list do
        list[k](self, ...)
    end
end

function Game:pushIntent(intent)
    self.intents[#self.intents + 1] = intent
end

function Game:submit(intent, preview)
    if self.lockstep then
        self.lockstep:submit(intent, preview)
    else
        self:pushIntent(intent)
    end
end

function Game:command(intent)
    if self.commandSink then
        self.commandSink(intent)
    else
        self:pushIntent(intent)
    end
end

function Game:processIntents()
    local list = self.intents
    self.intents = {}
    for _, intent in ipairs(list) do
        local handler = self.intentHandlers[intent.type]
        if handler then
            handler(self, intent)
        else
            Logger:warn("game", "Unknown intent " .. tostring(intent.type))
        end
    end
end

function Game:addEvent(text, options)
    options = options or {}
    self.eventSerial = self.eventSerial + 1
    local event = {
        id = self.eventSerial,
        text = text,
        tick = self.tick,
        color = options.color or { 0.85, 0.87, 0.92, 1 },
        actions = options.actions,
        minor = options.minor == true,
        duration = options.duration or Config.eventTicks,
        expires = self.tick + (options.duration or Config.eventTicks)
    }
    table.insert(self.events, event)
    if #self.events > Config.maxEvents then
        for k, old in ipairs(self.events) do
            if not old.actions then
                table.remove(self.events, k)
                break
            end
        end
    end
    return event
end

function Game:notify(player, text, options)
    if player and player == self.human then
        return self:addEvent(text, options)
    end
end

function Game:removeEvent(event)
    for k, e in ipairs(self.events) do
        if e == event then
            table.remove(self.events, k)
            return
        end
    end
end

function Game:step()
    self:processIntents()
    for _, system in ipairs(Systems) do
        if system.step then
            system.step(self)
        end
    end
    self.tick = self.tick + 1
end

function Game:checksum()
    local floor = math.floor
    local h = Hash.combine(self.ownerHash, self.tick)
    for _, p in ipairs(self.players) do
        h = Hash.combine(h, p.tiles)
        h = Hash.combine(h, floor(p.troops))
        h = Hash.combine(h, floor(p.workers))
        h = Hash.combine(h, floor(p.gold))
    end
    h = Hash.combine(h, #(self.units or {}))
    h = Hash.combine(h, #(self.attacks or {}))
    return h
end

function Game:difficulty()
    return Config.difficulties[self.options.difficulty or "medium"] or Config.difficulties.medium
end

function Game:report()
    local counts = {}
    for _, u in ipairs(self.units) do counts[u.kind] = (counts[u.kind] or 0) + 1 end
    local parts = {}
    for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
    table.sort(parts)
    Logger:info("game", "units " .. table.concat(parts, " "))
    local alliances = 0
    for _, p in ipairs(self.players) do
        for _ in pairs(p.allies) do alliances = alliances + 1 end
    end
    local blockaded = 0
    for _, u in ipairs(self.units) do if u.blockaded then blockaded = blockaded + 1 end end
    Logger:info("game", string.format("blockaded ports=%d", blockaded))
    Logger:info("game", string.format("alliances=%d rails=%d events=%d", alliances / 2, #(self.rails or {}), #self.events))
    for _, e in ipairs(self.events) do
        Logger:trace("event", e.text)
    end
    local alive = self:alivePlayers()
    table.sort(alive, function(a, b) return a.tiles > b.tiles end)
    Logger:info("game", string.format("tick=%d phase=%s alive=%d", self.tick, self.phase, #alive))
    for k = 1, math.min(8, #alive) do
        local p = alive[k]
        Logger:info("game", string.format("%-28s %-6s tiles=%-7d troops=%-9d workers=%-9d gold=%d", p.name, p.kind, p.tiles, p.troops, p.workers, p.gold))
    end
    local h = self.human
    if h then
        Logger:info("game", string.format("human tiles=%d troops=%d gold=%d alive=%s", h.tiles, h.troops, h.gold, tostring(h.alive)))
    end
end

function Game:speed()
    return Config.speeds[self.speedIndex]
end

function Game:changeSpeed(delta)
    self.speedIndex = math.max(1, math.min(#Config.speeds, self.speedIndex + delta))
end

function Game:update(dt)
    if self.lockstep then
        self.lockstep:update(dt)
        return
    end
    if self.paused or self.phase == "ended" then
        self.accumulator = 0
        return
    end
    local stepTime = 1 / Config.tickRate
    self.accumulator = self.accumulator + dt * self:speed()
    local steps = 0
    while self.accumulator >= stepTime do
        self:step()
        self.accumulator = self.accumulator - stepTime
        steps = steps + 1
        if steps >= Config.maxStepsPerFrame * self:speed() then
            self.accumulator = 0
            break
        end
    end
end

return Game
