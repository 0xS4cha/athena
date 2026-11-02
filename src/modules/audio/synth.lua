local Synth = {}

Synth.rate = 22050

local TAU = math.pi * 2
local NOTES = { c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11 }

function Synth.note(name)
    local letter, sharp, octave = name:lower():match("^([a-g])(#?)(%d)$")
    if not letter then error("Synth: unknown note " .. tostring(name)) end
    local semitone = NOTES[letter] + (sharp == "#" and 1 or 0) + (tonumber(octave) + 1) * 12
    return 440 * 2 ^ ((semitone - 69) / 12)
end

function Synth.melody(notes, options)
    local layers = {}
    local at = options.start or 0
    for _, entry in ipairs(notes) do
        local frequency = Synth.note(entry[1])
        layers[#layers + 1] = {
            wave = options.wave or "square",
            duty = options.duty,
            from = frequency,
            start = at,
            length = entry[2] * (options.sustain or 1.4),
            attack = options.attack or 0.004,
            curve = options.curve or 1.6,
            volume = options.volume or 0.5
        }
        at = at + entry[2]
    end
    return layers
end

local function noiseSource()
    local register = 0x4001
    return function()
        local bit = (register % 2 + math.floor(register / 2) % 2) % 2
        register = math.floor(register / 2) + bit * 0x4000
        return register % 2 == 1 and 1 or -1
    end
end

local WAVES = {
    square = function(phase, duty) return phase < duty and 1 or -1 end,
    triangle = function(phase) return phase < 0.5 and phase * 4 - 1 or 3 - phase * 4 end,
    saw = function(phase) return phase * 2 - 1 end,
    sine = function(phase) return math.sin(phase * TAU) end
}

local function renderLayer(layer, out, count, rate)
    local first = math.floor((layer.start or 0) * rate)
    local length = math.floor(layer.length * rate)
    local attack = math.max(1, math.floor((layer.attack or 0.002) * rate))
    local curve = layer.curve or 1.5
    local volume = layer.volume or 0.5
    local duty = layer.duty or 0.5
    local from, to = layer.from, layer.to or layer.from
    local vibrato, vibratoDepth = layer.vibrato or 0, layer.vibratoDepth or 0
    local wave = WAVES[layer.wave]
    local noise = layer.wave == "noise" and noiseSource() or nil
    if not wave and not noise then error("Synth: unknown wave " .. tostring(layer.wave)) end
    local cutoffFrom = layer.cutoff
    local cutoffTo = layer.cutoffTo or cutoffFrom
    local phase, held, filtered = 0, 0, 0
    for k = 0, length - 1 do
        local index = first + k
        if index >= count then break end
        local t = k / length
        local frequency = from + (to - from) * t
        if vibrato > 0 then
            frequency = frequency * (1 + vibratoDepth * math.sin(k / rate * vibrato * TAU))
        end
        phase = phase + frequency / rate
        local sample
        if noise then
            if phase >= 1 then
                held = noise()
            end
            sample = held
        else
            sample = wave(phase % 1, duty)
        end
        phase = phase % 1
        if cutoffFrom then
            local cutoff = cutoffFrom + (cutoffTo - cutoffFrom) * t
            filtered = filtered + (1 - math.exp(-TAU * cutoff / rate)) * (sample - filtered)
            sample = filtered
        end
        local envelope = k < attack and k / attack or (1 - (k - attack) / math.max(1, length - attack)) ^ curve
        out[index] = out[index] + sample * envelope * volume
    end
end

function Synth.duration(recipe)
    local duration = 0
    for _, layer in ipairs(recipe.layers) do
        duration = math.max(duration, (layer.start or 0) + layer.length)
    end
    return duration
end

function Synth.render(recipe, rate)
    rate = rate or Synth.rate
    local count = math.ceil(Synth.duration(recipe) * rate)
    local out = {}
    for k = 0, count - 1 do
        out[k] = 0
    end
    for _, layer in ipairs(recipe.layers) do
        renderLayer(layer, out, count, rate)
    end
    local peak = 0
    for k = 0, count - 1 do
        peak = math.max(peak, math.abs(out[k]))
    end
    if peak > 0.95 then
        local scale = 0.95 / peak
        for k = 0, count - 1 do
            out[k] = out[k] * scale
        end
    end
    return out, count
end

function Synth.soundData(recipe)
    local samples, count = Synth.render(recipe, Synth.rate)
    local data = love.sound.newSoundData(count, Synth.rate, 16, 1)
    for k = 0, count - 1 do
        data:setSample(k, samples[k])
    end
    return data
end

return Synth
