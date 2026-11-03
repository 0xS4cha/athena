local Class = require("src.core.class")
local Codec = require("src.net.codec")
local Config = require("src.config.game")

local Player = Class()

local SEEK_BUDGET = 0.03

function Player.gameOptions(header)
    local s = header.settings
    return {
        map = s.map,
        bots = s.bots,
        nations = s.nations,
        difficulty = s.difficulty,
        teams = s.teams,
        rules = s.rules,
        seed = header.seed,
        humans = header.players,
        localSlot = header.slot,
        authority = false,
        spectator = true,
        replay = true
    }
end

function Player:init(replay, options)
    options = options or {}
    self.replay = replay
    self.ticks = replay.header.ticks
    self.controls = options.controls or { paused = false, speed = 1, solo = true }
    self.onRestart = options.onRestart
    self.game = nil
    self.index = 1
    self.pendingFrame = nil
    self.seekTarget = options.seek
    self.desynced = false
    self.finished = false
end

function Player:attach(game)
    self.game = game
    game.lockstep = self
    self:applyControls(self.controls)
end

function Player:detach()
    self.game = nil
end

function Player:applyControls(controls)
    self.controls = controls
    if self.game then
        self.game.paused = controls.paused == true
        self.game.speedIndex = controls.speed or 1
    end
end

function Player:canControl()
    return true
end

function Player:control(paused, speed)
    local controls = { paused = self.controls.paused, speed = self.controls.speed, solo = true }
    if paused ~= nil then controls.paused = paused == true end
    if speed then controls.speed = speed end
    self:applyControls(controls)
    return true
end

function Player:submit() end

function Player:pendingList()
    return {}
end

function Player:pendingField()
    return nil
end

function Player:status()
    if self.desynced then
        return "REPLAY OUT OF SYNC  -  it does not match this version of the game"
    end
    if self.seekTarget then
        return string.format("SEEKING  -  %d%%", math.floor(self.game.tick / math.max(1, self.seekTarget) * 100))
    end
    return nil
end

function Player:frameAt(tick)
    local frame = self.pendingFrame
    if not frame and self.replay.frames[self.index] then
        frame = Codec.decode(self.replay.frames[self.index])
        self.pendingFrame = frame
    end
    if frame and frame[1] == tick then
        self.pendingFrame = nil
        self.index = self.index + 1
        return frame
    end
    return nil
end

function Player:step()
    local game = self.game
    local frame = self:frameAt(game.tick)
    if frame then
        for _, intent in ipairs(frame[2] or {}) do
            game:pushIntent(intent)
        end
    end
    game:step()
    if frame and frame[3] and game:checksum() ~= frame[3] then
        self.desynced = true
    end
    if game.tick >= self.ticks then
        self.finished = true
    end
end

function Player:seek(tick)
    tick = math.max(0, math.min(self.ticks, math.floor(tick)))
    if tick < self.game.tick then
        if self.onRestart then self.onRestart(tick, self.controls) end
        return
    end
    self.seekTarget = tick > self.game.tick and tick or nil
end

function Player:runSeek()
    local game = self.game
    local observer = game.observer
    game.observer = nil
    local started = love.timer.getTime()
    while game.tick < self.seekTarget and not self.finished and love.timer.getTime() - started < SEEK_BUDGET do
        self:step()
    end
    game.observer = observer
    if game.tick >= self.seekTarget or self.finished then
        self.seekTarget = nil
    end
end

function Player:update(dt)
    local game = self.game
    if not game then return end
    if self.seekTarget then
        self:runSeek()
        return
    end
    if self.controls.paused or self.finished or game.phase == "ended" then
        game.accumulator = 0
        return
    end
    local speed = Config.speeds[self.controls.speed or 1] or 1
    local stepTime = 1 / Config.tickRate
    game.accumulator = game.accumulator + dt * speed
    local steps = 0
    while game.accumulator >= stepTime and not self.finished and game.phase ~= "ended" do
        self:step()
        game.accumulator = game.accumulator - stepTime
        steps = steps + 1
        if steps >= Config.maxStepsPerFrame * speed then
            game.accumulator = 0
        end
    end
end

return Player
