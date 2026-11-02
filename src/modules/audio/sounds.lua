local Synth = require("src.modules.audio.synth")

local Sounds = {}

local function merge(...)
    local layers = {}
    for _, list in ipairs({ ... }) do
        for _, layer in ipairs(list) do
            layers[#layers + 1] = layer
        end
    end
    return layers
end

Sounds.hover = {
    volume = 0.18, cooldown = 0.04,
    layers = { { wave = "square", duty = 0.25, from = 980, length = 0.025, volume = 0.4 } }
}

Sounds.click = {
    volume = 0.4, cooldown = 0.04, jitter = 0.03,
    layers = {
        { wave = "square", duty = 0.25, from = 660, to = 880, length = 0.05, volume = 0.5 },
        { wave = "noise", from = 9000, length = 0.015, volume = 0.15 }
    }
}

Sounds.refused = {
    volume = 0.45, cooldown = 0.2,
    layers = merge(Synth.melody({ { "d3", 0.07 }, { "c3", 0.12 } }, { wave = "square", duty = 0.4, volume = 0.5 }))
}

Sounds.launch = {
    volume = 0.5, cooldown = 0.5,
    layers = {
        { wave = "noise", from = 2000, to = 9000, length = 0.5, attack = 0.2, curve = 2, volume = 0.3, cutoff = 700, cutoffTo = 5000 },
        { wave = "triangle", from = 110, to = 440, length = 0.5, attack = 0.1, volume = 0.45 }
    }
}

Sounds.start = {
    volume = 0.5, cooldown = 1,
    layers = merge(
        Synth.melody({ { "c4", 0.1 }, { "g4", 0.1 }, { "c5", 0.26 } }, { wave = "square", duty = 0.25, volume = 0.4 }),
        Synth.melody({ { "c3", 0.46 } }, { wave = "triangle", volume = 0.5 })
    )
}

Sounds.attack = {
    volume = 0.4, cooldown = 0.12, jitter = 0.05,
    layers = {
        { wave = "noise", from = 5000, to = 1800, length = 0.12, volume = 0.35, cutoff = 4000 },
        { wave = "square", duty = 0.25, from = 300, to = 130, length = 0.13, volume = 0.45 }
    }
}

Sounds.underAttack = {
    volume = 0.55, cooldown = 3,
    layers = merge(Synth.melody({ { "a4", 0.1 }, { "e4", 0.1 }, { "a4", 0.1 }, { "e4", 0.16 } }, { wave = "square", duty = 0.5, volume = 0.45 }))
}

Sounds.build = {
    volume = 0.4, cooldown = 0.15, jitter = 0.04,
    layers = {
        { wave = "noise", from = 3000, length = 0.05, volume = 0.3, cutoff = 2500 },
        { wave = "triangle", from = 330, to = 495, length = 0.1, start = 0.04, volume = 0.5 },
        { wave = "square", duty = 0.25, from = 660, length = 0.12, start = 0.09, volume = 0.25 }
    }
}

Sounds.coin = {
    volume = 0.22, cooldown = 1.5, jitter = 0.03,
    layers = merge(Synth.melody({ { "b5", 0.05 }, { "e6", 0.14 } }, { wave = "square", duty = 0.25, volume = 0.4 }))
}

Sounds.alliance = {
    volume = 0.45, cooldown = 0.5,
    layers = merge(Synth.melody({ { "c5", 0.09 }, { "e5", 0.09 }, { "g5", 0.09 }, { "c6", 0.22 } }, { wave = "triangle", volume = 0.6 }))
}

Sounds.betrayal = {
    volume = 0.55, cooldown = 0.5,
    layers = merge(
        Synth.melody({ { "e4", 0.13 }, { "d#4", 0.13 }, { "c#4", 0.32 } }, { wave = "saw", volume = 0.35 }),
        Synth.melody({ { "a#2", 0.58 } }, { wave = "square", duty = 0.5, volume = 0.3 })
    )
}

Sounds.request = {
    volume = 0.4, cooldown = 0.4,
    layers = merge(Synth.melody({ { "g5", 0.08 }, { "c6", 0.16 } }, { wave = "triangle", volume = 0.65 }))
}

Sounds.chat = {
    volume = 0.3, cooldown = 0.2,
    layers = merge(Synth.melody({ { "e5", 0.05 }, { "a5", 0.08 } }, { wave = "square", duty = 0.25, volume = 0.35 }))
}

Sounds.conquest = {
    volume = 0.5, cooldown = 0.8,
    layers = merge(Synth.melody({ { "g4", 0.08 }, { "c5", 0.08 }, { "e5", 0.08 }, { "g5", 0.26 } }, { wave = "square", duty = 0.25, volume = 0.4 }))
}

Sounds.capitalLost = {
    volume = 0.65, cooldown = 1,
    layers = merge(
        Synth.melody({ { "g3", 0.16 }, { "e3", 0.16 }, { "c3", 0.42 } }, { wave = "saw", volume = 0.4 }),
        { { wave = "noise", from = 1200, length = 0.6, curve = 2, volume = 0.3, cutoff = 900, cutoffTo = 150 } }
    )
}

Sounds.blockade = {
    volume = 0.45, cooldown = 3,
    layers = {
        { wave = "saw", from = 165, length = 0.6, attack = 0.05, curve = 0.6, volume = 0.4, cutoff = 700 },
        { wave = "saw", from = 220, length = 0.6, attack = 0.05, curve = 0.6, volume = 0.3, cutoff = 700 }
    }
}

Sounds.nukeLaunch = {
    volume = 0.6, cooldown = 0.3,
    layers = {
        { wave = "noise", from = 1500, to = 7000, length = 1.1, attack = 0.15, curve = 1.2, volume = 0.45, cutoff = 400, cutoffTo = 4500 },
        { wave = "saw", from = 70, to = 420, length = 1.1, attack = 0.2, curve = 1.2, volume = 0.3, cutoff = 900 }
    }
}

Sounds.nukeAlarm = {
    volume = 0.6, cooldown = 2.5,
    layers = {
        { wave = "square", duty = 0.5, from = 500, to = 950, length = 0.5, attack = 0.03, curve = 0.3, volume = 0.4 },
        { wave = "square", duty = 0.5, from = 950, to = 500, start = 0.5, length = 0.5, attack = 0.03, curve = 0.3, volume = 0.4 },
        { wave = "square", duty = 0.5, from = 500, to = 950, start = 1, length = 0.5, attack = 0.03, curve = 0.3, volume = 0.4 },
        { wave = "square", duty = 0.5, from = 950, to = 500, start = 1.5, length = 0.5, attack = 0.03, curve = 1.2, volume = 0.4 }
    }
}

Sounds.nukeBlast = {
    volume = 1, cooldown = 0.35, jitter = 0.06, voices = 4,
    layers = {
        { wave = "noise", from = 7000, length = 0.35, attack = 0.002, curve = 2, volume = 0.9, cutoff = 6000, cutoffTo = 1200 },
        { wave = "noise", from = 2600, length = 2.8, attack = 0.02, curve = 2.4, volume = 1.2, cutoff = 900, cutoffTo = 70 },
        { wave = "sine", from = 80, to = 28, length = 2.4, attack = 0.01, curve = 1.6, volume = 0.9 }
    }
}

Sounds.intercept = {
    volume = 0.55, cooldown = 0.25,
    layers = {
        { wave = "noise", from = 6000, length = 0.3, curve = 2.2, volume = 0.5, cutoff = 3500, cutoffTo = 500 },
        { wave = "square", duty = 0.25, from = 1200, to = 300, length = 0.22, volume = 0.3 }
    }
}

Sounds.victory = {
    volume = 0.6, cooldown = 2,
    layers = merge(
        Synth.melody({ { "c5", 0.13 }, { "c5", 0.07 }, { "c5", 0.07 }, { "e5", 0.13 }, { "g5", 0.13 }, { "c6", 0.5 } }, { wave = "square", duty = 0.25, volume = 0.35 }),
        Synth.melody({ { "c4", 0.2 }, { "g3", 0.2 }, { "c4", 0.13 }, { "e4", 0.13 }, { "c4", 0.5 } }, { wave = "triangle", volume = 0.5 })
    )
}

Sounds.defeat = {
    volume = 0.6, cooldown = 2,
    layers = merge(
        Synth.melody({ { "g4", 0.22 }, { "d#4", 0.22 }, { "c4", 0.22 }, { "g3", 0.7 } }, { wave = "saw", volume = 0.3, curve = 1.2 }),
        Synth.melody({ { "c3", 0.66 }, { "g2", 0.7 } }, { wave = "triangle", volume = 0.5, curve = 1 })
    )
}

return Sounds
