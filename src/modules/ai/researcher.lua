local Data = require("src.config.research")
local Research = require("src.modules.game.systems.research")
local Personality = require("src.modules.ai.personality")

local Researcher = {}

local function traitValue(player, trait)
    local traits = Personality.of(player)
    if trait == "naval" then
        return player:unitCount("militaryPort") > 0 and 1.1 or 0.2
    end
    return traits[trait] or 1
end

function Researcher.choose(game, player)
    local best, bestScore
    for _, tech in ipairs(Data.list) do
        if Research.status(game, player, tech.id) == "available" and Research.canQueue(game, player, tech.id) and Research.nextReady(player, tech.id) then
            local score = traitValue(player, tech.trait) * (0.8 + game.aiRng:random() * 0.4) / math.sqrt(tech.tier)
            if not bestScore or score > bestScore then
                best, bestScore = tech, score
            end
        end
    end
    return best
end

function Researcher.think(game, player)
    if not Research.enabled(game) or game.options.difficulty == "easy" then return end
    if game.tick < Data.aiStartTicks or #player.research.queue > 0 then return end
    if player.income <= 0 or (player.aiMemory and player.aiMemory.saving) then return end
    if game.options.difficulty ~= "hard" and game.aiRng:random() > 0.5 then return end
    local tech = Researcher.choose(game, player)
    if tech and player.gold >= Research.cost(game, player, tech.id) * Data.aiGoldShare then
        game:command({ type = "researchQueue", player = player.id, tech = tech.id })
    end
end

return Researcher
