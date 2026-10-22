local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")
local ArgParser = require("src.core.args")
local Threads = require("src.core.thread")
local Config = require("src.config.game")


local flags
local frames = 0
local defaultErrorHandler = love.errorhandler

function love.errorhandler(msg)
    print(debug.traceback(tostring(msg), 3))
    if flags and flags.frames then
        return nil
    end
    return defaultErrorHandler(msg)
end

function love.load(args)
    env:Load(".env")
    modules:Load("src/modules")

    local parser = ArgParser.new()
    parser:add_argument("map", { default = Config.defaultMap, type = "value" })
    parser:add_argument("bots", { default = Config.defaultBots, type = "value" })
    parser:add_argument("seed", { default = nil, type = "value" })
    parser:add_argument("ticks", { default = 600, type = "value" })
    parser:add_argument("difficulty", { default = "medium", type = "value" })
    parser:add_argument("autostart", { default = false, type = "boolean" })
    parser:add_argument("autoplay", { default = false, type = "boolean" })
    parser:add_argument("screenshot", { default = nil, type = "value" })
    parser:add_argument("ci", { default = false, type = "boolean" })
    parser:add_argument("menu", { default = false, type = "boolean" })
    parser:add_argument("screen", { default = nil, type = "value" })
    parser:add_argument("nations", { default = "on", type = "value" })
    parser:add_argument("zoom", { default = nil, type = "value" })
    parser:add_argument("frames", { default = nil, type = "value" })
    parser:add_argument("layer", { default = nil, type = "value" })
    parser:add_argument("focus", { default = nil, type = "value" })
    flags = parser:parse(args)
    GM.Flags = flags

    GM:InitializeModules()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.10)

    local options = {
        map = flags.map,
        bots = flags.bots,
        seed = flags.seed,
        difficulty = flags.difficulty,
        autoplay = flags.autoplay,
        nations = flags.nations ~= "off"
    }

    if flags.menu then
        GM.Menu:Open()
        love.draw()
        local canvas = love.graphics.newCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.08, 0.08, 0.10)
        love.draw()
        love.graphics.setCanvas()
        canvas:newImageData():encode("png", flags.screenshot or "menu.png")
        love.event.quit()
        return
    end

    if flags.ci then
        local ok, err = xpcall(function()
            local game = GM.Session:Start(options)
            local started = love.timer.getTime()
            for _ = 1, flags.ticks do
                if game.phase == "ended" then break end
                game:step()
            end
            Logger:info("ci", string.format("Simulated %d ticks in %.2fs", flags.ticks, love.timer.getTime() - started))
            if game.report then
                game:report()
            end
            if flags.layer then
                game.renderer.layers[flags.layer] = true
            end
            if flags.focus then
                local tile = game.combat.tiles[game.combat.head]
                if tile then
                    local x, y = game.map:coords(tile)
                    GM.Session.Camera:zoom(flags.focus)
                    GM.Session.Camera:centerOn(x, y)
                end
            end
            if flags.zoom then
                local camera = GM.Session.Camera
                camera:zoom(flags.zoom)
                camera:centerOn(game.human:center())
            end
            GM:Think(1 / 60)
            local canvas = love.graphics.newCanvas()
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0.08, 0.08, 0.10)
            love.draw()
            love.graphics.setCanvas()
            if flags.screenshot then
                canvas:newImageData():encode("png", flags.screenshot)
                Logger:info("ci", "Screenshot saved to " .. love.filesystem.getSaveDirectory() .. "/" .. flags.screenshot)
            end
        end, debug.traceback)
        if not ok then
            print(err)
            love.event.quit(1)
            return
        end
        love.event.quit()
        return
    end

    if flags.autostart or not GM.Menu then
        GM.Session:Start(options)
    else
        GM.Menu:Open()
    end
end

function love.update(dt)
    Threads.updateScheduler()
    GM:Think(dt)
    if flags.frames then
        frames = frames + 1
        if frames >= flags.frames then
            love.event.quit()
        end
    end
end

function love.draw()
    GM:Draw()
end

function love.wheelmoved(x, y)
    GM:WheelMoved(x, y)
end

function love.textinput(text)
    GM:TextInput(text)
end

function love.keypressed(key, scancode, isrepeat)
    GM:KeyPressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    GM:MousePressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    GM:MouseReleased(x, y, button, istouch, presses)
end
