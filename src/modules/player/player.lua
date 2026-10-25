local Class = require("src.core.class")
local Config = require("src.config.game")

local Player = Class()

function Player:init(id, name, kind, color, flag)
    self.id = id
    self.name = name
    self.kind = kind
    self.flag = flag
    self:setColor(color)
    self.alive = true
    self.spawned = false
    self.troops = 0
    self.workers = 0
    self.gold = 0
    self.troopRatio = Config.defaultTroopRatio
    self.attackRatio = Config.defaultAttackRatio
    self.maxPopulation = Config.basePopulation
    self.growth = 0
    self.income = 0
    self.tiles = 0
    self.cities = 0
    self.biomeTiles = { [0] = 0, 0, 0, 0, 0 }
    self.unitCounts = {}
    self.sumX = 0
    self.sumY = 0
    self.sumX2 = 0
    self.sumY2 = 0
    self.administration = 1
    self.borders = {}
    self.allies = {}
    self.allianceRequests = {}
    self.requestEvents = {}
    self.pacts = {}
    self.pactRequests = {}
    self.pactEvents = {}
    self.loanRequests = {}
    self.loanOffers = {}
    self.embargo = {}
    self.coalition = nil
    self.coalitionInvites = {}
    self.coalitionEvents = {}
    self.relations = {}
    self.traitorUntil = -1
end

function Player:setColor(color)
    self.color = color
    self.color255 = {
        math.floor(color[1] * 255),
        math.floor(color[2] * 255),
        math.floor(color[3] * 255)
    }
end

function Player:isHuman()
    return self.kind == "human"
end

function Player:isBot()
    return self.kind == "bot"
end

function Player:isNation()
    return self.kind == "nation"
end

function Player:population()
    return self.troops + self.workers
end

function Player:center()
    if self.tiles == 0 then
        return 0, 0
    end
    return self.sumX / self.tiles + 0.5, self.sumY / self.tiles + 0.5
end

function Player:spread()
    if self.tiles == 0 then
        return 0, 0
    end
    local cx, cy = self.sumX / self.tiles, self.sumY / self.tiles
    return math.sqrt(math.max(0, self.sumX2 / self.tiles - cx * cx)), math.sqrt(math.max(0, self.sumY2 / self.tiles - cy * cy))
end

function Player:familiarity(biomeId)
    if self.tiles == 0 then return 0 end
    return math.min(1, (self.biomeTiles[biomeId] or 0) / self.tiles / Config.biomeFamiliarShare)
end

function Player:unitCount(kind)
    return self.unitCounts[kind] or 0
end

function Player:isAlliedWith(other)
    return other ~= nil and other ~= self and self.allies[other.id] ~= nil
end

function Player:hasPact(other)
    return other ~= nil and other ~= self and self.pacts[other.id] ~= nil
end

function Player:canAttack(other)
    return other == nil or (other ~= self and not self:isAlliedWith(other) and not self:hasPact(other))
end

function Player:isFriendly(other)
    return other == self or self:isAlliedWith(other)
end

function Player:relation(other)
    return self.relations[other.id] or 0
end

function Player:changeRelation(other, delta)
    self.relations[other.id] = math.max(-100, math.min(100, self:relation(other) + delta))
end

return Player
