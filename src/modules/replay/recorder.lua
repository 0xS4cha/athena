local Class = require("src.core.class")
local Codec = require("src.net.codec")
local ReplayFile = require("src.modules.replay.file")
local Teams = require("src.modules.game.systems.teams")

local Recorder = Class()

Recorder.minTicks = 300

function Recorder:init(start)
    self.seed = start.seed
    self.settings = start.settings
    self.players = start.players
    self.slot = start.slot
    self.frames = {}
    self.nextTick = 0
    self.broken = (start.settings.autoplay or start.settings.tutorial) == true
end

function Recorder:add(frame)
    if self.broken then return end
    if frame.t ~= self.nextTick then
        self.broken = true
        return
    end
    self.nextTick = frame.t + 1
    local commands = frame.c or {}
    if #commands > 0 or frame.h then
        self.frames[#self.frames + 1] = Codec.encode({ frame.t, commands, frame.h })
    end
end

function Recorder:invalidate()
    self.broken = true
    self.frames = {}
end

local function result(game)
    if game.phase ~= "ended" then return "Unfinished" end
    if game.winningTeam then return Teams.label(game.winningTeam) .. " won" end
    return game.winner and (game.winner.name .. " won") or "Finished"
end

function Recorder:save(game)
    if self.broken or game.tick < Recorder.minTicks then
        Logger:info("replay", string.format("Not saved: tick %d, broken %s", game.tick, tostring(self.broken)))
        return nil
    end
    local ok, name = pcall(ReplayFile.save, {
        seed = self.seed,
        settings = self.settings,
        players = self.players,
        slot = self.slot,
        ticks = game.tick,
        mapName = game.map.manifest and game.map.manifest.name or game.map.name,
        result = result(game)
    }, self.frames)
    if not ok then
        Logger:warn("replay", "Could not save the replay: " .. tostring(name))
        return nil
    end
    return name
end

return Recorder
