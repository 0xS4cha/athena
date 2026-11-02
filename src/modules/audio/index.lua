local GM = require("src.core.index")
local Synth = require("src.modules.audio.synth")
local Sounds = require("src.modules.audio.sounds")
local Cues = require("src.modules.audio.cues")

GM.Audio = {}

GM.Modules:Register("Audio", 30)

local DEFAULT_COOLDOWN = 0.05
local DEFAULT_VOICES = 2

GM.Audio.levels = { 0, 0.25, 0.5, 0.75, 1 }
GM.Audio.labels = { "Off", "25%", "50%", "75%", "100%" }

function GM.Audio:Initialize()
    self.bank = {}
    self.lastPlayed = {}
    self.enabled = love.audio ~= nil and love.sound ~= nil
    if not self.enabled then return end
    local started = love.timer.getTime()
    for name, recipe in pairs(Sounds) do
        local source = love.audio.newSource(Synth.soundData(recipe), "static")
        self.bank[name] = { recipe = recipe, voices = { source } }
    end
    Logger:info("Audio", string.format("Rendered sounds in %.1f ms", (love.timer.getTime() - started) * 1000))
end

function GM.Audio:Master()
    local index = GM.Menu and GM.Menu.settings and GM.Menu.settings.soundVolume or 4
    return self.levels[index] or 1
end

local function freeVoice(entry)
    for _, voice in ipairs(entry.voices) do
        if not voice:isPlaying() then return voice end
    end
    if #entry.voices < (entry.recipe.voices or DEFAULT_VOICES) then
        local voice = entry.voices[1]:clone()
        entry.voices[#entry.voices + 1] = voice
        return voice
    end
    return nil
end

function GM.Audio:Play(name, gain)
    if not self.enabled then return end
    local master = self:Master()
    if master <= 0 then return end
    local entry = self.bank[name]
    if not entry then
        Logger:warn("Audio", "Unknown sound " .. tostring(name))
        return
    end
    local now = love.timer.getTime()
    if now - (self.lastPlayed[name] or -math.huge) < (entry.recipe.cooldown or DEFAULT_COOLDOWN) then return end
    local voice = freeVoice(entry)
    if not voice then return end
    self.lastPlayed[name] = now
    local jitter = entry.recipe.jitter or 0
    voice:setPitch(1 + (love.math.random() * 2 - 1) * jitter)
    voice:setVolume(math.min(1, (entry.recipe.volume or 1) * (gain or 1) * master))
    voice:play()
end

function GM.Audio:Observe(game, name, ...)
    local sound, gain = Cues.resolve(game, name, ...)
    if sound then
        self:Play(sound, gain)
    end
end

function GM.Audio:Attach(game)
    game.observer = function(name, ...)
        self:Observe(game, name, ...)
    end
end

return GM.Audio
