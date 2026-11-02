local Config = require("src.config.game")
local Palette = require("src.modules.player.palette")

local Teams = {}

local HUMAN_TINT = 0.15
local NATION_TINT = 0.3

Teams.modes = { 0, 2, 3, 4 }
Teams.modeLabels = { "Off", "2", "3", "4" }
Teams.colors = {
    { 0.2, 0.5, 1.0 },
    { 0.92, 0.22, 0.22 },
    { 0.22, 0.78, 0.35 },
    { 0.98, 0.76, 0.12 }
}
Teams.names = { "Blue", "Red", "Green", "Gold" }

function Teams.validCount(value)
    value = tonumber(value)
    for _, mode in ipairs(Teams.modes) do
        if value == mode then return mode end
    end
    return 0
end

function Teams.modeIndex(value)
    for k, mode in ipairs(Teams.modes) do
        if value == mode then return k end
    end
    return 1
end

function Teams.enabled(game)
    return (game.teamCount or 0) > 0
end

function Teams.label(team)
    return "Team " .. Teams.names[team]
end

function Teams.color(team)
    return Teams.colors[team]
end

function Teams.playerColor(player)
    local base = Teams.colors[player.team]
    local own = Palette.color(player.id)
    local tint = player:isHuman() and HUMAN_TINT or NATION_TINT
    return {
        base[1] + (own[1] - base[1]) * tint,
        base[2] + (own[2] - base[2]) * tint,
        base[3] + (own[3] - base[3]) * tint
    }
end

local function assignHumans(game, sizes)
    for _, player in ipairs(game.players) do
        if player:isHuman() then
            if player.team and player.team >= 1 and player.team <= game.teamCount then
                sizes[player.team] = sizes[player.team] + 1
            else
                player.team = nil
            end
        end
    end
    for _, player in ipairs(game.players) do
        if player:isHuman() and not player.team then
            local smallest = 1
            for team = 2, game.teamCount do
                if sizes[team] < sizes[smallest] then smallest = team end
            end
            player.team = smallest
            sizes[smallest] = sizes[smallest] + 1
        end
    end
end

local function assignNations(game, sizes)
    local nations, total = {}, 0
    for _, player in ipairs(game.players) do
        if player:isNation() and player.alive and player.spawnTile then
            nations[#nations + 1] = player
        end
    end
    for team = 1, game.teamCount do
        total = total + sizes[team]
    end
    table.sort(nations, function(a, b)
        local ax, bx = game.map:coords(a.spawnTile), game.map:coords(b.spawnTile)
        if ax ~= bx then return ax < bx end
        return a.id < b.id
    end)
    local target = math.ceil((total + #nations) / game.teamCount)
    local team = math.floor(game.seed) % game.teamCount + 1
    for _, nation in ipairs(nations) do
        while sizes[team] >= target do
            team = team % game.teamCount + 1
        end
        nation.team = team
        sizes[team] = sizes[team] + 1
    end
end

local function bind(game)
    local expires = game.tick + Config.allianceTicks
    for _, a in ipairs(game.players) do
        for _, b in ipairs(game.players) do
            if a:isTeammate(b) then
                a.allies[b.id] = expires
                a:changeRelation(b, 50)
            end
        end
    end
end

function Teams.init(game)
    game.teamCount = game.options.tutorial and 0 or Teams.validCount(game.options.teams)
    game.winningTeam = nil
end

function Teams.setup(game)
    if not Teams.enabled(game) then return end
    local sizes = {}
    for team = 1, game.teamCount do sizes[team] = 0 end
    assignHumans(game, sizes)
    assignNations(game, sizes)
    bind(game)
    for _, player in ipairs(game.players) do
        if player.team then
            player:setColor(Teams.playerColor(player))
        end
    end
    game.renderer:repaintAll()
    local human = game.human
    if human then
        game:addEvent("You fight for " .. Teams.label(human.team) .. ". Spawn near your teammates!", {
            color = Teams.color(human.team),
            duration = game.spawnTicksTotal
        })
    end
end

function Teams.members(game, team)
    local list = {}
    for _, player in ipairs(game.players) do
        if player.team == team then list[#list + 1] = player end
    end
    return list
end

function Teams.standings(game)
    local list = {}
    for team = 1, game.teamCount do
        list[team] = { team = team, tiles = 0, alive = 0, total = 0 }
    end
    for _, player in ipairs(game.players) do
        local entry = player.team and list[player.team]
        if entry then
            entry.total = entry.total + 1
            if player.alive and player.spawned then
                entry.alive = entry.alive + 1
                entry.tiles = entry.tiles + player.tiles
            end
        end
    end
    return list
end

return Teams
