local Config = require("src.config.game")
local Economy = require("src.modules.game.systems.economy")
local Rails = require("src.modules.game.systems.rails")

local Yields = {}

local REFRESH_TICKS = 10
local TRADE_CYCLE = Config.tradeInterval * 1.5 / Config.tradeChance

local cache = setmetatable({}, { __mode = "k" })

local function railIncome(game, player)
    local finished = {}
    for _, rail in ipairs(game.rails) do
        if rail.a.owner == player and #rail.tiles > 0 and rail.built >= #rail.tiles then
            finished[#finished + 1] = rail
        end
    end
    local income = {}
    for _, rail in ipairs(finished) do
        local perTick = Rails.trainGold(rail, #finished) * Config.trainSpeed / #rail.tiles
        income[rail.a] = (income[rail.a] or 0) + perTick
    end
    return income
end

local function tradeIncome(port)
    if port.blockaded or not port.tradeRoute then return nil end
    local gold = Config.tradeBaseGold + port.tradeRoute * Config.tradeGoldPerTile
    return gold / (port.tradeRoute / Config.tradeSpeed + TRADE_CYCLE)
end

function Yields.compute(game, player)
    local cityHousing, farmHousing = Economy.housing(game, player)
    local housing = cityHousing + farmHousing
    local fit = housing > 0 and math.min(1, Economy.housingCapacity(player) / housing) or 1
    local cities = math.max(1, Economy.built(game, player, "city"))
    local farms = math.max(1, Economy.built(game, player, "farm"))
    local mineIncome = Economy.mineIncome(game, player)
    local owned = game.buildingCounts and game.buildingCounts[player.id]
    local mineGold = owned and owned.mineGold or 0
    local rails = railIncome(game, player)
    local list = {}
    for _, unit in ipairs(game.units) do
        if unit.owner == player and not unit.dead and unit.buildLeft == 0 then
            local kind = unit.kind
            local population, gold
            if kind == "capital" then
                population = Config.capitalPopulation
            elseif kind == "city" then
                population = cityHousing * fit / cities
            elseif kind == "farm" then
                population = farmHousing * fit / farms
            elseif kind == "mine" and mineGold > 0 and unit.richness then
                gold = mineIncome * Config.units.mine.gold * unit.richness / mineGold
            elseif kind == "factory" then
                gold = rails[unit]
            elseif kind == "tradePort" then
                gold = tradeIncome(unit)
            elseif kind == "barracks" and player.upkeepPaid then
                gold = -Config.barracksUpkeep
            elseif kind == "radar" and player.upkeepPaid then
                gold = -Config.radarUpkeep
            end
            if population or gold then
                list[unit] = { population = population, gold = gold and gold * Config.tickRate }
            end
        end
    end
    return list
end

function Yields.of(game, player, unit)
    local entry = cache[game]
    local bucket = math.floor(game.tick / REFRESH_TICKS)
    if not entry or entry.bucket ~= bucket or entry.player ~= player then
        entry = { bucket = bucket, player = player, list = Yields.compute(game, player) }
        cache[game] = entry
    end
    return entry.list[unit]
end

return Yields
