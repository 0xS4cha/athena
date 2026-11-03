local Config = require("src.config.game")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")
local Teams = require("src.modules.game.systems.teams")

local Panel = { id = "teams", title = "TEAMS", panel = true }

local WIDTH = 280
local PAD = 12
local ROW = 34

function Panel.visible(hud)
    local game = hud:game()
    return Teams.enabled(game) and game.phase ~= "ended"
end

function Panel.size(hud)
    return WIDTH, Style.headerHeight + 8 + hud:game().teamCount * ROW + 4
end

function Panel.position(_, w, _, W)
    return W - w - 20, 270
end

function Panel.draw(hud, x, y, w)
    local game = hud:game()
    local u = Pixel.unit
    local land = game.map.landCount
    local human = game.human
    local standings = Teams.standings(game)
    local barW = w - PAD * 2
    local goal = math.floor(barW * game.rules.winRatio)
    for k, standing in ipairs(standings) do
        local top = y + Style.headerHeight + 8 + (k - 1) * ROW
        local color = Teams.color(standing.team)
        local own = human and human.team == standing.team
        local label = Teams.label(standing.team) .. (own and "  (you)" or "")
        local share = standing.tiles / land
        Pixel.text(label, x + PAD, top, 12, standing.alive > 0 and color or Style.colors.muted)
        local detail = string.format("%d/%d  %s", standing.alive, standing.total, Format.percent(share))
        Pixel.text(detail, x + w - PAD - Style.font(11):getWidth(detail), top + 1, 11, Style.colors.text)
        local by = top + 17
        Pixel.color(Pixel.colors.ink)
        love.graphics.rectangle("fill", x + PAD, by, barW, u * 3)
        local eased = Pixel.ease("teams:share:" .. standing.team, share, 6)
        Pixel.color(color)
        love.graphics.rectangle("fill", x + PAD, by, math.floor(barW * math.min(1, eased) / u) * u, u * 3)
        Pixel.color(Style.colors.gold)
        love.graphics.rectangle("fill", x + PAD + goal, by - u, u, u * 5)
    end
end

return Panel
