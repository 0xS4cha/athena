local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Ships = require("src.modules.game.systems.ships")
local Nukes = require("src.modules.game.systems.nukes")

local Intents = {}

local floor = math.floor

local function set(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end

local BUILDABLE = {}
for kind, def in pairs(Config.units) do
    if def.buildable ~= false and def.cost > 0 then BUILDABLE[kind] = true end
end
local NUKES = set(Config.nukeTypes)
local EMOJIS = set(Config.emojis)
local LOAN_AMOUNTS = set(Config.loanAmounts)
local LOAN_RATES = set(Config.loanRates)
local DONATIONS = { troops = true, gold = true }

local function integer(v)
    return type(v) == "number" and v == floor(v) and v >= 0 and v < 2 ^ 31 and v or nil
end

local function ratio(v)
    if type(v) ~= "number" or v ~= v then return nil end
    return floor(math.max(0, math.min(1, v)) * 1000 + 0.5) / 1000
end

local FIELDS = {
    tile = integer,
    target = integer,
    from = integer,
    attack = integer,
    ratio = ratio,
    accept = function(v) return v == true end,
    enabled = function(v) return v == true end,
    unit = function(v) return BUILDABLE[v] and v or nil end,
    nukeKind = function(v) return NUKES[v] and v or nil end,
    donation = function(v) return DONATIONS[v] and v or nil end,
    icon = function(v) return EMOJIS[v] and v or nil end,
    amount = function(v) return LOAN_AMOUNTS[v] and v or nil end,
    rate = function(v) return LOAN_RATES[v] and v or nil end
}

local SCHEMAS = {
    spawn = { tile = "tile" },
    start = {},
    attack = { target = "target", ratio = "ratio" },
    retreat = { attack = "attack" },
    boat = { tile = "tile", ratio = "ratio" },
    warship = { tile = "tile" },
    build = { unit = "unit", tile = "tile" },
    nuke = { kind = "nukeKind", tile = "tile" },
    troopRatio = { ratio = "ratio" },
    donate = { target = "target", kind = "donation", ratio = "ratio?" },
    allianceRequest = { target = "target" },
    allianceReply = { from = "from", accept = "accept" },
    allianceBreak = { target = "target" },
    pactRequest = { target = "target" },
    pactReply = { from = "from", accept = "accept" },
    pactEnd = { target = "target" },
    embargo = { target = "target", enabled = "enabled" },
    setTarget = { target = "target?" },
    emoji = { target = "target", icon = "icon" },
    loanRequest = { target = "target", amount = "amount" },
    loanReply = { from = "from", rate = "rate?" },
    loanAnswer = { from = "from", accept = "accept" },
    loanRepay = { target = "target" }
}

local function otherPlayer(game, player, id)
    local other = id and game.players[id]
    if not other or other == player then return nil end
    return other
end

local RULES = {
    spawn = function(game, player, intent)
        if game.phase ~= "spawn" then return "Spawn phase is over" end
        if intent.tile >= game.map.size or not game.map:isLand(intent.tile) then return "Not land" end
        if game.map.owner[intent.tile] ~= 0 then return "Already taken" end
    end,
    attack = function(game, player, intent)
        if game.phase ~= "playing" or not player.alive then return "Not now" end
        if intent.target ~= 0 then
            local target = otherPlayer(game, player, intent.target)
            if not target or not target.alive then return "Unknown target" end
            if not player:canAttack(target) then return "Cannot attack this nation" end
        end
        if not Attack.sharesBorder(game, player, intent.target) then return "No shared border" end
    end,
    boat = function(game, player, intent)
        if game.phase ~= "playing" or not player.alive then return "Not now" end
        if intent.tile >= game.map.size then return "Invalid tile" end
        local ok, reason = Ships.canSendBoat(game, player, intent.tile)
        if not ok then return reason end
    end,
    warship = function(game, player, intent)
        if intent.tile >= game.map.size then return "Invalid tile" end
        if player:unitCount("warship") == 0 then return "No warship" end
    end,
    build = function(game, player, intent)
        if intent.tile >= game.map.size then return "Invalid tile" end
        local ok, reason = Units.check(game, player, intent.unit, intent.tile)
        if not ok then return reason end
    end,
    nuke = function(game, player, intent)
        if intent.tile >= game.map.size then return "Invalid tile" end
        local ok, reason = Nukes.check(game, player, intent.kind, intent.tile)
        if not ok then return reason end
    end,
    donate = function(game, player, intent)
        local target = otherPlayer(game, player, intent.target)
        if not target or not player:isAlliedWith(target) then return "Not an ally" end
    end,
    setTarget = function(game, player, intent)
        if intent.target and not otherPlayer(game, player, intent.target) then return "Unknown target" end
    end
}

local function needsOther(intent, schema)
    return (schema.target == "target" and intent.type ~= "attack") or schema.from == "from"
end

function Intents.sanitize(game, slot, raw)
    if type(raw) ~= "table" or type(raw.type) ~= "string" then return nil, "Malformed intent" end
    local schema = SCHEMAS[raw.type]
    if not schema then return nil, "Unknown intent" end
    local intent = { type = raw.type, player = slot }
    for key, field in pairs(schema) do
        local optional = field:sub(-1) == "?"
        local name = optional and field:sub(1, -2) or field
        local value = FIELDS[name](raw[key])
        if value == nil and not optional then
            return nil, "Invalid " .. key
        end
        intent[key] = value
    end
    local player = game.players[slot]
    if not player then return nil, "No player" end
    if needsOther(intent, schema) and not otherPlayer(game, player, intent.target or intent.from) then
        return nil, "Unknown player"
    end
    local rule = RULES[intent.type]
    local reason = rule and rule(game, player, intent)
    if reason then return nil, reason end
    return intent
end

return Intents
