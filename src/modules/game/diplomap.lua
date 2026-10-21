local Diplomap = {}

Diplomap.categories = {
    { key = "self", label = "You", color = { 1, 0.82, 0.25 }, fill = 0.65 },
    { key = "ally", label = "Ally", color = { 0.25, 0.8, 0.4 }, fill = 0.65 },
    { key = "war", label = "At war", color = { 0.95, 0.18, 0.16 }, fill = 0.65 },
    { key = "pact", label = "Pact", color = { 0.35, 0.65, 1 }, fill = 0.65 },
    { key = "traitor", label = "Traitor", color = { 0.72, 0.3, 0.9 }, fill = 0.65 },
    { key = "hostile", label = "Hostile", color = { 0.95, 0.55, 0.2 }, fill = 0.6 },
    { key = "friendly", label = "Friendly", color = { 0.6, 0.9, 0.65 }, fill = 0.5 },
    { key = "neutral", label = "Neutral", color = { 0.62, 0.64, 0.7 }, fill = 0.3 },
    { key = "tribe", label = "Tribe", color = { 0.3, 0.31, 0.36 }, fill = 0.45 }
}

local byKey = {}
for _, category in ipairs(Diplomap.categories) do
    byKey[category.key] = category
end

local function atWar(game, a, b)
    for _, attack in ipairs(game.attacks) do
        if not attack.done and ((attack.attacker == a and attack.target == b) or (attack.attacker == b and attack.target == a)) then
            return true
        end
    end
    return false
end

function Diplomap.category(game, viewer, player)
    if player == viewer then return byKey.self end
    if viewer:isAlliedWith(player) then return byKey.ally end
    if atWar(game, viewer, player) then return byKey.war end
    if viewer:hasPact(player) then return byKey.pact end
    if player.traitorUntil > game.tick then return byKey.traitor end
    if player:isBot() then return byKey.tribe end
    local relation = math.min(viewer:relation(player), player:relation(viewer))
    if relation <= -30 then return byKey.hostile end
    if relation >= 20 then return byKey.friendly end
    return byKey.neutral
end

function Diplomap.refresh(game)
    local renderer = game.renderer
    if not renderer.paletteData or game.diplomapTick == game.tick then return end
    game.diplomapTick = game.tick
    local viewer = game.human
    for _, player in ipairs(game.players) do
        local category = Diplomap.category(game, viewer, player)
        local c = category.color
        renderer:setPaletteColor(player.id, c[1], c[2], c[3], category.fill)
    end
end

return Diplomap
