local Class = require("src.core.class")
local Config = require("src.config.game")

local Lockstep = Class()

local BUFFER_TARGET = 2
local CATCH_UP_TURNS = 20
local CATCH_UP_BUDGET = 0.025
local STALL_SECONDS = 1

function Lockstep:init(connection, hashTicks)
    self.connection = connection
    self.hashTicks = hashTicks or 50
    self.game = nil
    self.turns = {}
    self.latest = -1
    self.outbox = {}
    self.accumulator = 0
    self.lastTurnTime = love.timer.getTime()
    self.finished = false
end

function Lockstep:attach(game)
    self.game = game
    game.lockstep = self
end

function Lockstep:detach()
    if self.connection.lockstep == self then
        self.connection:LeaveRoom()
        self.connection.lockstep = nil
    end
    self.game = nil
end

function Lockstep:load(history, tick)
    for t = 0, (tick or 0) - 1 do
        self.turns[t] = {}
    end
    for _, turn in ipairs(history or {}) do
        self.turns[turn.tick] = turn.intents or {}
    end
    self.latest = math.max(self.latest, (tick or 0) - 1)
end

function Lockstep:submit(intent)
    if intent.type == "troopRatio" then
        for k = #self.outbox, 1, -1 do
            if self.outbox[k].type == "troopRatio" then
                self.outbox[k] = intent
                return
            end
        end
    end
    self.outbox[#self.outbox + 1] = intent
end

function Lockstep:receive(turn)
    if type(turn) ~= "table" or type(turn.tick) ~= "number" then return end
    self.turns[turn.tick] = type(turn.intents) == "table" and turn.intents or {}
    self.latest = math.max(self.latest, turn.tick)
    self.lastTurnTime = love.timer.getTime()
end

function Lockstep:available()
    if not self.game then return 0 end
    return self.latest - self.game.tick + 1
end

function Lockstep:catchingUp()
    return self:available() > CATCH_UP_TURNS
end

function Lockstep:stalled()
    return self:available() <= 0 and love.timer.getTime() - self.lastTurnTime > STALL_SECONDS
end

function Lockstep:status()
    local game = self.game
    if not game or game.phase == "ended" then return nil end
    if self.connection.lockstep ~= self then return nil end
    if self.connection.state ~= "online" then
        return self.connection.reconnecting and "CONNECTION LOST  -  reconnecting..." or "CONNECTION LOST"
    end
    if self:catchingUp() then
        return string.format("CATCHING UP  -  %d%%", math.floor(game.tick / math.max(1, self.latest) * 100))
    end
    if self:stalled() then
        return "WAITING FOR SERVER..."
    end
    return nil
end

function Lockstep:flush()
    for _, intent in ipairs(self.outbox) do
        self.connection:Send("intent", intent)
    end
    self.outbox = {}
end

function Lockstep:step()
    local game = self.game
    local intents = self.turns[game.tick]
    self.turns[game.tick] = nil
    for _, intent in ipairs(intents) do
        game:pushIntent(intent)
    end
    game:step()
    if game.tick % self.hashTicks == 0 then
        self.connection:Send("hash", { tick = game.tick, hash = game:checksum() })
    end
end

function Lockstep:update(dt)
    self:flush()
    local game = self.game
    if not game then return end
    if game.phase == "ended" then
        if not self.finished then
            self.finished = true
            self.connection:Finished(self)
        end
        return
    end
    local stepTime = 1 / Config.tickRate
    self.accumulator = math.min(self.accumulator + dt, stepTime * 2)
    local started = love.timer.getTime()
    while self.turns[game.tick] and game.phase ~= "ended" do
        if self.accumulator >= stepTime then
            self.accumulator = self.accumulator - stepTime
        elseif self:available() <= BUFFER_TARGET or love.timer.getTime() - started > CATCH_UP_BUDGET then
            break
        end
        self:step()
    end
end

return Lockstep
