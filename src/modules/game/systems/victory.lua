local Config = require("src.config.game")
local Teams = require("src.modules.game.systems.teams")

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
    local teams = 0
    for _, standing in ipairs(Teams.standings(game)) do
        if standing.alive > 0 then teams = teams + 1 end
    end
    game.startingTeams = teams
end

function Victory.won(game, player)
    if not player then return false end
    return game.winner == player or (game.winningTeam ~= nil and player.team == game.winningTeam)
end

function Victory.declare(game, winner)
    game.winner = winner
    game.phase = "ended"
    game.endTick = game.tick
    game:emit("gameEnded", winner)
    if Victory.won(game, game.human) then
        game:addEvent("Victory! You dominate the world.", { color = { 1, 0.85, 0.3, 1 }, duration = 100000 })
    elseif game.winningTeam then
        game:addEvent(Teams.label(game.winningTeam) .. " has won the game.", { color = { 0.95, 0.6, 0.3, 1 }, duration = 100000 })
    else
        game:addEvent(winner.name .. " has won the game.", { color = { 0.95, 0.6, 0.3, 1 }, duration = 100000 })
    end
end

local function declareTeam(game, team)
    local leader
    for _, player in ipairs(Teams.members(game, team)) do
        if player.alive and (not leader or player.tiles > leader.tiles) then
            leader = player
        end
    end
    game.winningTeam = team
    Victory.declare(game, leader)
end

local function stepTeams(game, land)
    local remaining, last = 0, nil
    for _, standing in ipairs(Teams.standings(game)) do
        if standing.alive > 0 then
            remaining = remaining + 1
            last = standing.team
            if standing.tiles / land >= Config.winRatio then
                declareTeam(game, standing.team)
                return true
            end
        end
    end
    if remaining == 1 and (game.startingTeams or 0) > 1 then
        declareTeam(game, last)
        return true
    end
    return remaining > 0
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
    if Teams.enabled(game) and stepTeams(game, land) then return end
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
