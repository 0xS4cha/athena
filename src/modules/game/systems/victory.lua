local Config = require("src.config.game")

local Victory = {}

function Victory.init(game)
    game.winner = nil
    game.stats = { peakTiles = 0, peakRank = nil }
end

function Victory.started(game)
    local count = 0
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned then count = count + 1 end
    end
    game.startingPlayers = count
end

function Victory.declare(game, winner)
    game.winner = winner
    game.phase = "ended"
    game.endTick = game.tick
    if winner == game.human then
        game:addEvent("Victory! You dominate the world.", { color = { 1, 0.85, 0.3, 1 }, duration = 100000 })
    else
        game:addEvent(winner.name .. " has won the game.", { color = { 0.95, 0.6, 0.3, 1 }, duration = 100000 })
    end
end

function Victory.step(game)
    if game.phase ~= "playing" or game.tick % Config.victoryCheckTicks ~= 0 then return end
    local land = game.map.landCount
    local alive = 0
    local last
    local human = game.human
    if human then
        game.stats.peakTiles = math.max(game.stats.peakTiles, human.tiles)
    end
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned then
            alive = alive + 1
            last = player
            if player.tiles / land >= Config.winRatio then
                Victory.declare(game, player)
                return
            end
        end
    end
    if alive == 1 and (game.startingPlayers or 0) > 1 then
        Victory.declare(game, last)
    end
end

function Victory.eliminated(game, player)
    if player == game.human then
        game.humanDefeatedTick = game.tick
    end
end

return Victory
