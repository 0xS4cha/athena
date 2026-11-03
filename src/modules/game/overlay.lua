local Diplomap = require("src.modules.game.diplomap")
local Overlay = require("src.modules.game.overlay.shared")

require("src.modules.game.overlay.labels")
require("src.modules.game.overlay.buildings")
require("src.modules.game.overlay.radar")
require("src.modules.game.overlay.nukes")
require("src.modules.game.overlay.orders")
require("src.modules.game.overlay.threats")
require("src.modules.game.overlay.units")
require("src.modules.game.overlay.battle")

function Overlay.draw(game, camera)
    love.graphics.push("all")
    local W, H = love.graphics.getDimensions()
    local layers = game.renderer.layers
    if layers.diplomacy then
        Diplomap.refresh(game)
    end
    if layers.supply and game.phase == "playing" then
        Overlay.drawSupply(game, camera)
    end
    Overlay.drawCombat(game, camera, W, H)
    if layers.units then
        Overlay.drawTroops(game, camera, W, H)
    end
    if layers.units then
        Overlay.drawRails(game, camera)
        Overlay.drawRadarSweeps(game, camera)
        Overlay.drawUnits(game, camera, W, H)
        Overlay.drawEchoes(game, camera)
        Overlay.drawNukeAlerts(game, camera)
        Overlay.drawNukePreview(game, camera)
        Overlay.drawHoveredStructure(game, camera)
    end
    Overlay.drawExplosions(game, camera)
    Overlay.drawBuildPreview(game, camera)
    Overlay.drawPending(game, camera)
    if layers.threat then
        Overlay.drawThreats(game, camera, W, H)
    end
    if layers.names and layers.political then
        for _, player in ipairs(game.players) do
            if player.alive and player.tiles > 0 then
                Overlay.drawLabel(game, camera, player, W, H)
            end
        end
    end
    if layers.threat then
        Overlay.drawThreatLegend(game)
    elseif layers.diplomacy and layers.political then
        Overlay.drawDiplomacyLegend()
    end
    love.graphics.pop()
end

return Overlay
