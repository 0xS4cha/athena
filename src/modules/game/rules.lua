local Rules = {}

Rules.fields = {
    { id = "winRatio", label = "Land to win", hint = "Share of the land that wins the game", values = { 0.5, 0.6, 0.7, 0.8, 0.9, 1 }, labels = { "50%", "60%", "70%", "80%", "90%", "100%" } },
    { id = "timeLimit", label = "Time limit", hint = "When time runs out, the largest empire wins", values = { 0, 10, 20, 30, 60 }, labels = { "None", "10m", "20m", "30m", "60m" } },
    { id = "startGold", label = "Starting gold", hint = "Gold of every nation and player at the start", values = { 0, 100000, 500000, 1000000, 5000000 }, labels = { "0", "100K", "500K", "1M", "5M" } },
    { id = "startArmy", label = "Starting army", hint = "Multiplies the first troops and workers", values = { 1, 2, 5, 10 }, labels = { "x1", "x2", "x5", "x10" } },
    { id = "income", label = "Income", hint = "Multiplies the gold earned by workers", values = { 0.5, 1, 2, 4 }, labels = { "x0.5", "x1", "x2", "x4" } },
    { id = "spawnSeconds", label = "Spawn time", hint = "Seconds to choose a starting location", values = { 5, 15, 30, 60 }, labels = { "5s", "15s", "30s", "60s" } },
    { id = "nukes", label = "Nukes", hint = "Off removes missile silos, SAM launchers and nukes", values = { true, false }, labels = { "On", "Off" } },
    { id = "diplomacy", label = "Diplomacy", hint = "Off removes alliances, pacts and coalitions", values = { true, false }, labels = { "On", "Off" } }
}

Rules.defaults = { winRatio = 0.8, timeLimit = 0, startGold = 0, startArmy = 1, income = 1, spawnSeconds = 15, nukes = true, diplomacy = true }

Rules.modes = {
    { id = "classic", label = "Classic", hint = "The standard rules." },
    { id = "blitz", label = "Blitz", hint = "A rich, fast war: 60% of the land or the largest empire after 20 minutes.", rules = { winRatio = 0.6, timeLimit = 20, startGold = 1000000, startArmy = 5, income = 2, spawnSeconds = 5 } },
    { id = "conventional", label = "Conventional", hint = "No nukes: land, sea and gold decide the war.", rules = { nukes = false } },
    { id = "anarchy", label = "Anarchy", hint = "No alliances, pacts or coalitions: everyone for themselves.", rules = { diplomacy = false } },
    { id = "annihilation", label = "Annihilation", hint = "No land victory: only the last nation standing wins.", rules = { winRatio = 1 } },
    { id = "custom", label = "Custom", hint = "Your own rules." }
}

local function mode(id)
    for _, entry in ipairs(Rules.modes) do
        if entry.id == id then return entry end
    end
end

local function preset(entry)
    local rules = { mode = entry.id }
    for key, value in pairs(Rules.defaults) do rules[key] = value end
    for key, value in pairs(entry.rules or {}) do rules[key] = value end
    return rules
end

function Rules.sanitize(raw)
    raw = type(raw) == "table" and raw or {}
    local entry = mode(raw.mode) or mode("classic")
    if entry.id ~= "custom" then return preset(entry) end
    local rules = { mode = "custom" }
    for _, field in ipairs(Rules.fields) do
        rules[field.id] = Rules.defaults[field.id]
        for _, value in ipairs(field.values) do
            if raw[field.id] == value then rules[field.id] = value end
        end
    end
    return rules
end

function Rules.detect(rules)
    for _, entry in ipairs(Rules.modes) do
        if entry.id ~= "custom" then
            local same = true
            local candidate = preset(entry)
            for _, field in ipairs(Rules.fields) do
                if candidate[field.id] ~= rules[field.id] then same = false end
            end
            if same then return entry.id end
        end
    end
    return "custom"
end

function Rules.set(rules, id, value)
    local changed = { mode = "custom" }
    for _, field in ipairs(Rules.fields) do changed[field.id] = rules[field.id] end
    changed[id] = value
    changed.mode = Rules.detect(changed)
    return Rules.sanitize(changed)
end

function Rules.label(rules)
    local entry = mode(rules and rules.mode) or mode("classic")
    return entry.label
end

function Rules.hint(rules)
    local entry = mode(rules and rules.mode) or mode("classic")
    return entry.hint
end

function Rules.modeIndex(rules)
    for k, entry in ipairs(Rules.modes) do
        if entry.id == rules.mode then return k end
    end
    return 1
end

function Rules.valueIndex(field, rules)
    for k, value in ipairs(field.values) do
        if value == rules[field.id] then return k end
    end
    return 1
end

function Rules.encode(rules)
    local parts = { "mode=" .. tostring(rules.mode) }
    for _, field in ipairs(Rules.fields) do
        parts[#parts + 1] = field.id .. "=" .. tostring(rules[field.id])
    end
    return table.concat(parts, ";")
end

function Rules.decode(text)
    local raw = {}
    for key, value in tostring(text or ""):gmatch("(%w+)=([^;]*)") do
        if value == "true" then
            raw[key] = true
        elseif value == "false" then
            raw[key] = false
        else
            raw[key] = tonumber(value) or value
        end
    end
    return Rules.sanitize(raw)
end

function Rules.summary(rules)
    if rules.mode == "classic" then return nil end
    local parts = {}
    for _, field in ipairs(Rules.fields) do
        if rules[field.id] ~= Rules.defaults[field.id] then
            parts[#parts + 1] = field.label .. " " .. field.labels[Rules.valueIndex(field, rules)]
        end
    end
    return Rules.label(rules) .. ": " .. table.concat(parts, ", ")
end

return Rules
