local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Config = require("src.config.game")
local Format = require("src.core.format")

local Interaction = {}

function Interaction.click(game, tile)
    local human = game.human
    local map = game.map
    if game.phase == "spawn" then
        game:pushIntent({ type = "spawn", player = human.id, tile = tile })
        return
    end
    if game.phase ~= "playing" or not human.alive or map:isWater(tile) then
        return
    end
    local targetId = map.owner[tile]
    if targetId == human.id then
        return
    end
    local target = targetId ~= 0 and game.players[targetId] or nil
    if target and human:isAlliedWith(target) then
        game:addEvent("You cannot attack your ally " .. target.name .. ".")
        return
    end
    if Attack.sharesBorder(game, human, targetId) then
        game:pushIntent({ type = "attack", player = human.id, target = targetId, ratio = human.attackRatio })
        return
    end
    if Interaction.fallback then
        Interaction.fallback(game, tile, targetId)
        return
    end
    game:addEvent("You do not share a border with " .. (target and target.name or "this land") .. ".")
end

function Interaction.unitItem(game, kind, tile)
    local human = game.human
    local def = Config.units[kind]
    local ok, reason = Units.check(game, human, kind, tile)
    return {
        label = def.label,
        icon = def.icon,
        sublabel = ok and Format.number(Units.cost(game, human, kind)) or reason,
        sublabelColor = not ok and { 0.95, 0.35, 0.3, 1 } or nil,
        disabled = not ok,
        action = function()
            game:pushIntent({ type = "build", player = human.id, unit = kind, tile = tile })
        end
    }
end

function Interaction.buildItems(game, tile)
    local items = {}
    for _, kind in ipairs(Config.buildingTypes) do
        items[#items + 1] = Interaction.unitItem(game, kind, tile)
    end
    return items
end

Interaction.sections = {}

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    if game.map.owner[tile] ~= human.id and not game.map:isWater(tile) then return end
    local nearCoast = Units.findPortTile(game, human, tile)
    if game.map.owner[tile] ~= human.id and not nearCoast then return end
    items[#items + 1] = {
        label = "Build",
        icon = "Hammer.png",
        submenu = function()
            return "BUILD", Interaction.buildItems(game, tile)
        end
    }
end

function Interaction.menu(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local items = {}
    if game.phase == "playing" and game.human.alive then
        for _, section in ipairs(Interaction.sections) do
            section(game, tile, items)
        end
    end
    items[#items + 1] = { label = "Close Menu", icon = "Exit.png" }
    local owner = game:playerAt(tile)
    local title = owner and owner.name or string.format("TILE [%d, %d]", x, y)
    return title, items
end

return Interaction
