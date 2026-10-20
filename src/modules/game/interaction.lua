local Interaction = {}

function Interaction.click(game, tile)
end

function Interaction.menu(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local items = {}
    items[#items + 1] = { label = "Close Menu", icon = "Exit.png" }
    return string.format("TILE [%d, %d]", x, y), items
end

return Interaction
