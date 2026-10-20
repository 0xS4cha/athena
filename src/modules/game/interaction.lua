local Attack = require("src.modules.game.systems.attack")

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

function Interaction.menu(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local items = {}
    items[#items + 1] = { label = "Close Menu", icon = "Exit.png" }
    return string.format("TILE [%d, %d]", x, y), items
end

return Interaction
