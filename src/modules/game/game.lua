local Class = require("src.core.class")
local Config = require("src.config.game")
local Map = require("src.modules.map.map")
local Renderer = require("src.modules.map.renderer")
local Player = require("src.modules.player.player")
local Palette = require("src.modules.player.palette")

local Systems = {
    require("src.modules.game.systems.spawn"),
    require("src.modules.game.systems.economy")
}

local Game = Class()

function Game:init(options)
    self.options = options or {}
    self.seed = self.options.seed or os.time()
    self.rng = love.math.newRandomGenerator(self.seed)
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
    self.renderer = Renderer(self)
    self.human = self:addPlayer(self.options.playerName or "Player", "human", self.options.playerFlag)

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
end

function Game:addPlayer(name, kind, flag)
    local id = #self.players + 1
    local color = kind == "human" and Palette.human or Palette.color(id)
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

    local previous = old ~= 0 and self.players[old] or nil
    if previous then
        previous.tiles = previous.tiles - 1
        previous.sumX = previous.sumX - x
        previous.sumY = previous.sumY - y
        previous.borders[i] = nil
    end
    if id ~= 0 then
        local p = self.players[id]
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
end

function Game:emit(name, ...)
    for _, system in ipairs(Systems) do
        local fn = system[name]
        if fn then
            fn(self, ...)
        end
    end
end

function Game:pushIntent(intent)
    self.intents[#self.intents + 1] = intent
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
        expires = self.tick + (options.duration or Config.eventTicks)
    }
    table.insert(self.events, event)
    if #self.events > Config.maxEvents then
        table.remove(self.events, 1)
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

function Game:difficulty()
    return Config.difficulties[self.options.difficulty or "medium"] or Config.difficulties.medium
end

function Game:report()
    local alive = self:alivePlayers()
    table.sort(alive, function(a, b) return a.tiles > b.tiles end)
    Logger:info("game", string.format("tick=%d phase=%s alive=%d", self.tick, self.phase, #alive))
    for k = 1, math.min(8, #alive) do
        local p = alive[k]
        Logger:info("game", string.format("%-28s %-6s tiles=%-7d troops=%-9d workers=%-9d gold=%d", p.name, p.kind, p.tiles, p.troops, p.workers, p.gold))
    end
    local h = self.human
    Logger:info("game", string.format("human tiles=%d troops=%d gold=%d alive=%s", h.tiles, h.troops, h.gold, tostring(h.alive)))
end

function Game:speed()
    return Config.speeds[self.speedIndex]
end

function Game:changeSpeed(delta)
    self.speedIndex = math.max(1, math.min(#Config.speeds, self.speedIndex + delta))
end

function Game:update(dt)
    if self.paused or self.phase == "ended" then
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
