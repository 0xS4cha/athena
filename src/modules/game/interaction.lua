local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Ships = require("src.modules.game.systems.ships")
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
    local ok, reason = Ships.canSendBoat(game, human, tile)
    if ok then
        game:pushIntent({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio })
        return
    end
    game:addEvent("Cannot reach " .. (target and target.name or "this land") .. ": " .. reason .. ".")
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
    for _, kind in ipairs(Config.buildMenu) do
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

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    local map = game.map
    if map:isWater(tile) or map.owner[tile] == human.id then return end
    local target = game:playerAt(tile)
    if target and human:isAlliedWith(target) then return end
    local name = target and target.name or "Wilderness"
    if Attack.sharesBorder(game, human, map.owner[tile]) then
        items[#items + 1] = {
            label = "Attack " .. name,
            icon = "Skull.png",
            sublabel = Format.number(human.troops * human.attackRatio),
            sublabelColor = { 0.95, 0.35, 0.3, 1 },
            action = function()
                game:pushIntent({ type = "attack", player = human.id, target = map.owner[tile], ratio = human.attackRatio })
            end
        }
    end
    local ok, reason = Ships.canSendBoat(game, human, tile)
    items[#items + 1] = {
        label = "Send Boat",
        icon = "Luggage.png",
        sublabel = ok and Format.number(human.troops * human.attackRatio) or reason,
        sublabelColor = ok and { 0.45, 0.75, 1, 1 } or { 0.95, 0.35, 0.3, 1 },
        disabled = not ok,
        action = function()
            game:pushIntent({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio })
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
