local GM = require("src.core.index")
local ReplayFile = require("src.modules.replay.file")
local Player = require("src.modules.replay.player")

GM.Replay = {}

local function start(replay, seek, controls)
    local options = Player.gameOptions(replay.header)
    options.lockstep = Player(replay, {
        seek = seek,
        controls = controls,
        onRestart = function(tick, current)
            local camera = GM.Session.Camera
            local x, y, scale = camera.x, camera.y, camera.scale
            start(replay, tick > 0 and tick or nil, current)
            local fresh = GM.Session.Camera
            fresh.x, fresh.y, fresh.scale = x, y, scale
            fresh:clamp()
        end
    })
    if GM.Menu and GM.Menu.background then
        GM.Menu.background:stop()
    end
    return GM.Session:Start(options)
end

function GM.Replay:Watch(name)
    local replay, err = ReplayFile.load(name)
    if not replay then return false, err end
    if not GM.Menu:active() then
        GM.Session:Stop()
        GM.Menu:Open()
    end
    GM.Menu:Launch(replay.header.mapName or "replay", function() start(replay) end)
    return true
end

return GM.Replay
