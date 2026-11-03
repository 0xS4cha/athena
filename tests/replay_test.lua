local Codec = require("src.net.codec")
local NetConfig = require("src.net.config")
local Game = require("src.modules.game.game")
local ReplayFile = require("src.modules.replay.file")
local Recorder = require("src.modules.replay.recorder")
local Player = require("src.modules.replay.player")
local T = require("tests.helpers")

local DIR = "test_replays"
local HUMANS = { { name = "A" }, { name = "B", team = nil } }

local function clean()
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        love.filesystem.remove(DIR .. "/" .. item)
    end
    love.filesystem.remove(DIR)
end

local function isolated(run)
    return function()
        local dir, keep = ReplayFile.dir, ReplayFile.keep
        ReplayFile.dir = DIR
        clean()
        local ok, err = xpcall(run, debug.traceback)
        clean()
        ReplayFile.dir, ReplayFile.keep = dir, keep
        if not ok then error(err, 0) end
    end
end

local function settings(extra)
    local s = { map = T.MAP, bots = 10, nations = true, difficulty = "hard", teams = 0, rules = { mode = "classic" } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

local function play(ticks, s, script)
    s = s or settings()
    local server = Game({
        map = s.map, bots = s.bots, nations = s.nations, difficulty = s.difficulty, teams = s.teams, rules = s.rules,
        seed = 77, humans = HUMANS, headless = true, authority = true
    })
    local queue = {}
    server.commandSink = function(intent) queue[#queue + 1] = intent end
    local recorder = Recorder({ seed = 77, settings = s, players = HUMANS, slot = 1 })
    for _ = 1, ticks do
        if script then script(server, queue) end
        local commands = queue
        queue = {}
        for _, intent in ipairs(commands) do server:pushIntent(intent) end
        local tick = server.tick
        server:step()
        recorder:add({ t = tick, c = Codec.decode(Codec.encode(commands)), h = server.tick % 10 == 0 and server:checksum() or nil })
    end
    return server, recorder
end

local function watch(name, seek)
    local replay = T.expect(ReplayFile.load(name))
    local options = Player.gameOptions(replay.header)
    options.headless = true
    local game = Game(options)
    local player = Player(replay, { seek = seek })
    player:attach(game)
    return game, player, replay
end

return {
    {
        name = "a replay rebuilds the game exactly, through the file and in full vision",
        run = isolated(function()
            local server, recorder = play(600)
            local name = T.expect(recorder:save(server), "replay saved")
            local game, player = watch(name)
            T.expect(game.options.spectator, "full vision")
            while not player.finished do player:step() end
            T.expect(not player.desynced, "every recorded hash matches")
            T.equal(game.tick, server.tick, "same length")
            T.equal(game:checksum(), server:checksum(), "same final state")
            player:update(1)
            T.equal(game.tick, server.tick, "the replay stops at its end")
        end)
    },
    {
        name = "a human who never picked a land spawns the same way in the replay",
        run = isolated(function()
            local server, recorder = play(320)
            T.expect(server.players[1].spawned, "the server gave a random land")
            local game, player = watch(T.expect(recorder:save(server)))
            while not player.finished do player:step() end
            T.expect(game.players[1].spawned, "same in the replay")
            T.equal(game.players[1].spawnTile, server.players[1].spawnTile, "same land")
            T.expect(not player.desynced, "no desync")
        end)
    },
    {
        name = "rules, surrender and teams replay identically",
        run = isolated(function()
            local s = settings({ teams = 2, rules = { mode = "blitz" } })
            local server, recorder = play(400, s, function(game, queue)
                if game.tick == 200 then queue[#queue + 1] = { type = "surrender", player = 2 } end
            end)
            T.expect(server.players[2].surrendered, "the surrender happened")
            local game, player = watch(T.expect(recorder:save(server)))
            T.equal(game.rules.mode, "blitz", "rules restored")
            while not player.finished do player:step() end
            T.expect(not player.desynced, "no desync")
            T.expect(game.players[2].surrendered, "surrender replayed")
            T.equal(game:checksum(), server:checksum(), "same final state")
        end)
    },
    {
        name = "the player controls speed and pause, and seeks both ways",
        run = isolated(function()
            local server, recorder = play(400)
            local name = T.expect(recorder:save(server))
            local game, player, replay = watch(name)
            local restarted
            player.onRestart = function(tick) restarted = tick end
            T.expect(player:canControl(), "always controllable")
            player:control(true, nil)
            player:update(1)
            T.equal(game.tick, 0, "paused")
            player:control(false, 2)
            T.equal(game.speedIndex, 2, "speed")
            player:update(0.5)
            T.equal(game.tick, 10, "speed x2 plays twice as fast")
            player:seek(200)
            while player.seekTarget do player:update(0) end
            T.equal(game.tick, 200, "seeked forward")
            player:seek(5000)
            T.equal(player.seekTarget, 400, "clamped to the end")
            player.seekTarget = nil
            player:seek(50)
            T.equal(restarted, 50, "going back restarts")
            T.equal(game.tick, 200, "the running game is left to the restart")

            local fresh = Game((function()
                local options = Player.gameOptions(replay.header)
                options.headless = true
                return options
            end)())
            local again = Player(replay, { seek = 400 })
            again:attach(fresh)
            while again.seekTarget do again:update(0) end
            T.expect(again.finished, "seek reaches the end")
            T.equal(fresh:checksum(), server:checksum(), "seeking does not change the result")
            player:submit({ type = "surrender", player = 1 })
            T.equal(#game.intents, 0, "a replay ignores orders")
        end)
    },
    {
        name = "short, tutorial and interrupted games are not saved",
        run = isolated(function()
            local server, recorder = play(50)
            T.equal(recorder:save(server), nil, "too short")
            local long, broken = play(320)
            broken:invalidate()
            T.equal(broken:save(long), nil, "snapshot restored")
            local _, gap = play(320)
            gap:add({ t = 9999, c = {} })
            T.expect(gap.broken, "a missing frame breaks the record")
            local tutorial = Recorder({ seed = 1, settings = settings({ tutorial = true }), players = HUMANS, slot = 1 })
            T.expect(tutorial.broken, "no replay of the tutorial")
            T.equal(#ReplayFile.names(), 0, "nothing on disk")
        end)
    },
    {
        name = "the list reads headers, keeps the newest files and refuses bad ones",
        run = isolated(function()
            local server, recorder = play(320)
            ReplayFile.keep = 3
            local names = {}
            for k = 1, 5 do
                local header = { seed = 77, settings = settings(), players = HUMANS, slot = 1, ticks = 320, mapName = "Italia", date = 1000 + k, result = "A won" }
                names[k] = T.expect(ReplayFile.save(header, recorder.frames))
            end
            local list = ReplayFile.list()
            T.equal(#list, 3, "old replays are pruned")
            T.equal(list[1].name, names[5], "newest first")
            T.equal(list[1].header.result, "A won", "header")
            T.equal(ReplayFile.slug("Hong Kong / 2"), "hong-kong-2", "file names are safe")

            local function write(name, content)
                love.filesystem.write(DIR .. "/" .. name, content)
                return name
            end
            local _, err = ReplayFile.load("missing.replay")
            T.equal(err, "This replay no longer exists", "missing")
            _, err = ReplayFile.load(write("junk.replay", "not a replay"))
            T.equal(err, "This file is not a valid replay", "junk")
            local good = love.filesystem.read(DIR .. "/" .. names[5])
            _, err = ReplayFile.load(write("cut.replay", good:sub(1, #good - 40)))
            T.equal(err, "This replay is damaged", "truncated")
            local evil = good:gsub('assets/maps/italia/', '../../secret/')
            local head = evil:match("^ATHENA%-REPLAY %d+ %d+\n")
            local size = tonumber(head:match("(%d+)\n$")) + #'../../secret/' - #'assets/maps/italia/'
            evil = evil:gsub("^ATHENA%-REPLAY %d+ %d+\n", "ATHENA-REPLAY 1 " .. size .. "\n")
            _, err = ReplayFile.load(write("evil.replay", evil))
            T.equal(err, "This replay is damaged", "a map path outside the maps is refused")

            local version = NetConfig.version
            NetConfig.version = version + 1
            _, err = ReplayFile.load(names[5])
            local outdated = ReplayFile.list()[1].outdated
            NetConfig.version = version
            T.equal(err, "This replay was recorded with another version of the game", "other version")
            T.expect(outdated, "flagged in the list")
            T.expect(ReplayFile.delete(names[5]), "deleted")
            T.equal(love.filesystem.getInfo(DIR .. "/" .. names[5]), nil, "gone")
        end)
    },
    {
        name = "a replay whose hashes do not match reports it",
        run = isolated(function()
            local server, recorder = play(320)
            for k, raw in ipairs(recorder.frames) do
                local frame = Codec.decode(raw)
                if frame[3] then
                    frame[3] = frame[3] + 1
                    recorder.frames[k] = Codec.encode(frame)
                end
            end
            local game, player = watch(T.expect(recorder:save(server)))
            while not player.finished do player:step() end
            T.expect(player.desynced, "mismatch detected")
            T.expect(player:status():find("OUT OF SYNC", 1, true), "shown to the viewer")
            T.equal(game.tick, server.tick, "the replay still plays")
        end)
    }
}
