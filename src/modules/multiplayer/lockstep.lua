local Class = require("src.core.class")
local Config = require("src.config.game")
local Palette = require("src.modules.player.palette")
local Snapshot = require("src.net.snapshot")

local Lockstep = Class()

local BUFFER_TARGET = 2
local CATCH_UP_FRAMES = 20
local CATCH_UP_BUDGET = 0.03
local STALL_SECONDS = 1
local GAP_SECONDS = 1
local PENDING_SECONDS = 5
local BAD = { 0.95, 0.35, 0.3, 1 }

function Lockstep:init(connection, options)
    options = options or {}
    self.connection = connection
    self.room = options.room
    self.slot = options.slot
    self.hashTicks = options.hashTicks or 10
    self.controls = options.controls or { paused = false, speed = 1, solo = false }
    self.game = nil
    self.frames = {}
    self.latest = -1
    self.outbox = {}
    self.seq = 0
    self.pending = {}
    self.accumulator = 0
    self.lastFrameTime = love.timer.getTime()
    self.gapSince = nil
    self.finished = false
    self.resyncing = false
    self.verified = 0
end

function Lockstep:attach(game)
    self.game = game
    game.lockstep = self
    self:applyControls(self.controls)
end

function Lockstep:detach()
    if self.connection.lockstep == self then
        self.connection:LeaveGame(self)
    end
    self.game = nil
end

function Lockstep:applyControls(controls)
    self.controls = controls
    local game = self.game
    if game then
        game.paused = controls.paused == true
        game.speedIndex = controls.speed or 1
    end
end

function Lockstep:canControl()
    return self.controls.solo == true
end

function Lockstep:control(paused, speed)
    if not self:canControl() then return false end
    return self.connection:Send("control", { paused = paused, speed = speed })
end

function Lockstep:submit(intent, preview)
    if intent.type == "troopRatio" then
        for k = #self.outbox, 1, -1 do
            if self.outbox[k].type == "troopRatio" then
                self.pending[self.outbox[k].seq] = nil
                table.remove(self.outbox, k)
            end
        end
    end
    self.seq = self.seq + 1
    intent.seq = self.seq
    self.pending[self.seq] = { intent = intent, preview = preview, time = love.timer.getTime() }
    self.outbox[#self.outbox + 1] = intent
end

function Lockstep:flush()
    if #self.outbox == 0 then return end
    for _, intent in ipairs(self.outbox) do
        self.connection:Send("intent", intent)
    end
    self.outbox = {}
end

function Lockstep:reject(data)
    local seq = tonumber(data.seq)
    if seq then
        self.pending[seq] = nil
    end
    if self.game and data.reason then
        self.game:addEvent("Action refused by the server: " .. tostring(data.reason) .. ".", { color = BAD, minor = true })
    end
end

function Lockstep:pendingList()
    local list = {}
    local now = love.timer.getTime()
    for seq, entry in pairs(self.pending) do
        if now - entry.time > PENDING_SECONDS then
            self.pending[seq] = nil
        else
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b) return a.intent.seq < b.intent.seq end)
    return list
end

function Lockstep:pendingField(kind, field)
    local latest
    for _, entry in pairs(self.pending) do
        if entry.intent.type == kind and (not latest or entry.intent.seq > latest.intent.seq) then
            latest = entry
        end
    end
    return latest and latest.intent[field]
end

function Lockstep:receive(frame)
    if type(frame) ~= "table" or type(frame.t) ~= "number" then return end
    if self.game and frame.t < self.game.tick then return end
    self.frames[frame.t] = frame
    self.latest = math.max(self.latest, frame.t)
    self.lastFrameTime = love.timer.getTime()
end

function Lockstep:lastContiguous()
    local game = self.game
    if not game then return nil end
    local t = game.tick
    while self.frames[t] do
        t = t + 1
    end
    return t - 1
end

function Lockstep:resume(tick)
    local game = self.game
    if not game then return end
    for t in pairs(self.frames) do
        if t >= tick then self.frames[t] = nil end
    end
    self.latest = tick - 1
    self.gapSince = nil
    self.lastFrameTime = love.timer.getTime()
end

function Lockstep:colorFor(player)
    if player.id == self.slot then return Palette.human end
    if player:isBot() then return Palette.tribe end
    return Palette.color(player.id)
end

function Lockstep:applySnapshot(tick, data)
    local game = self.game
    if not game then return false end
    local ok, restored, expected = pcall(Snapshot.apply, game, data, function(player) return self:colorFor(player) end)
    if not ok then
        Logger:error("multiplayer", "Failed to apply snapshot: " .. tostring(restored))
        self.connection:notify("Could not load the server state.")
        return false
    end
    for t in pairs(self.frames) do
        if t < restored then self.frames[t] = nil end
    end
    self.latest = math.max(self.latest, restored - 1)
    self.resyncing = false
    self.gapSince = nil
    self.accumulator = 0
    local human = game.players[self.slot]
    if human then
        game.human = human
        human:setColor(Palette.human)
    end
    game.renderer:repaintAll()
    if game.renderer.idData then
        game.renderer:buildIds()
    end
    if game:checksum() ~= expected then
        Logger:warn("multiplayer", string.format("Snapshot at tick %d restored with a different checksum", restored))
    end
    Logger:info("multiplayer", string.format("Snapshot applied at tick %d", restored))
    return true
end

function Lockstep:desync(tick)
    if self.resyncing then return end
    self.resyncing = true
    Logger:warn("multiplayer", "Desync detected at tick " .. tostring(tick))
    self.connection:Send("resync")
end

function Lockstep:available()
    if not self.game then return 0 end
    return self.latest - self.game.tick + 1
end

function Lockstep:catchingUp()
    return self:available() > CATCH_UP_FRAMES
end

function Lockstep:stalled()
    if self.controls.paused then return false end
    return self:available() <= 0 and love.timer.getTime() - self.lastFrameTime > STALL_SECONDS
end

function Lockstep:status()
    local game = self.game
    if not game or game.phase == "ended" then return nil end
    if self.connection.lockstep ~= self then return nil end
    if self.connection.state ~= "online" then
        return self.connection.reconnecting and "CONNECTION LOST  -  reconnecting..." or "CONNECTION LOST"
    end
    if self.resyncing then
        return "RESYNCHRONIZING WITH THE SERVER..."
    end
    if self:catchingUp() then
        return string.format("CATCHING UP  -  %d%%", math.floor(game.tick / math.max(1, self.latest) * 100))
    end
    if self:stalled() then
        return "WAITING FOR SERVER..."
    end
    return nil
end

function Lockstep:step()
    local game = self.game
    local frame = self.frames[game.tick]
    self.frames[game.tick] = nil
    for _, intent in ipairs(frame.c or {}) do
        game:pushIntent(intent)
        if intent.seq and intent.player == self.slot then
            self.pending[intent.seq] = nil
        end
    end
    game:step()
    if frame.h then
        if game:checksum() ~= frame.h then
            self:desync(game.tick)
        else
            self.verified = game.tick
        end
    end
end

function Lockstep:checkGap()
    local game = self.game
    if self.frames[game.tick] or self.latest < game.tick then
        self.gapSince = nil
        return
    end
    local now = love.timer.getTime()
    if not self.gapSince then
        self.gapSince = now
    elseif now - self.gapSince > GAP_SECONDS then
        self.gapSince = now
        self.connection:Send("catchup", { lastTick = game.tick - 1 })
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
    if self.resyncing then return end
    self:checkGap()
    local speed = Config.speeds[self.controls.speed or 1] or 1
    local stepTime = 1 / (Config.tickRate * speed)
    self.accumulator = math.min(self.accumulator + dt, stepTime * 2)
    local started = love.timer.getTime()
    while self.frames[game.tick] and game.phase ~= "ended" and not self.resyncing do
        if self.accumulator >= stepTime then
            self.accumulator = self.accumulator - stepTime
        elseif self:available() <= BUFFER_TARGET or love.timer.getTime() - started > CATCH_UP_BUDGET then
            break
        end
        self:step()
    end
    game.accumulator = self.accumulator * speed
end

return Lockstep
