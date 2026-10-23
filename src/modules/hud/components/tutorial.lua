local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Attack = require("src.modules.game.systems.attack")

local Tutorial = { id = "tutorial", title = "TUTORIAL", panel = true, accent = Style.colors.gold }

local WIDTH = 340
local TEXT_W = WIDTH - 32
local BUTTON_H = 28
local ADVANCE_SECONDS = 1.2
local DEFAULT_LAYERS = { terrain = true, political = true, units = true, names = true, supply = false, threat = false, diplomacy = false }

local function layersChanged(game)
    for name, value in pairs(DEFAULT_LAYERS) do
        if (game.renderer.layers[name] == true) ~= value then return true end
    end
    return false
end

local STEPS = {
    {
        title = "Choose your land",
        text = "Click anywhere on land to place your capital. You can click again to move it while the countdown runs.",
        done = function(game) return game.human.spawned end
    },
    {
        title = "Start the game",
        text = "Press SPACE to start right away. Every nation grows from the spot it picked.",
        done = function(game) return game.phase == "playing" end
    },
    {
        title = "Expand",
        text = "Left-click the wilderness next to your border: your troops march out and claim it tile by tile.",
        start = function(game, state) state.tiles = game.human.tiles end,
        done = function(game, state) return game.human.tiles >= (state.tiles or 0) + 40 end
    },
    {
        title = "Balance your people",
        text = "Drag the Troops / Workers slider in the Empire panel. Workers earn gold, troops attack and defend.",
        start = function(game, state) state.ratio = game.human.troopRatio end,
        done = function(game, state) return math.abs(game.human.troopRatio - (state.ratio or 0)) > 0.02 end
    },
    {
        title = "Size your attacks",
        text = "The Attack Ratio slider sets the share of your troops sent by each click. Change it now.",
        start = function(game, state) state.ratio = game.human.attackRatio end,
        done = function(game, state) return math.abs(game.human.attackRatio - (state.ratio or 0)) > 0.02 end
    },
    {
        title = "Build a city",
        text = "Right-click your own land, open Build and pick City. You start with enough gold for one; cities raise your population cap.",
        done = function(game) return game.human:unitCount("city") > 0 end
    },
    {
        title = "Attack a tribe",
        text = "Find a neighbouring tribe and left-click its land. Each tile costs troops depending on terrain and defenders.",
        done = function(game)
            for _, attack in ipairs(Attack.outgoing(game, game.human)) do
                if attack.target then return true end
            end
            return false
        end
    },
    {
        title = "Read the map",
        text = "Press the keys 1 to 7 to toggle map layers such as supply lines, threats and diplomacy. H lists every control.",
        done = function(game) return layersChanged(game) end
    },
    {
        title = "You are ready",
        text = "Control 80% of the land or be the last nation standing to win. Right-click other nations for diplomacy and keep exploring!",
        final = true
    }
}

Tutorial.steps = STEPS

local function state(hud)
    local game = hud:game()
    if hud.tutorialGame ~= game then
        hud.tutorialGame = game
        hud.tutorial = { step = 1, data = {}, closed = false }
    end
    return hud.tutorial
end

local function enter(game, tutorial, step)
    tutorial.step = step
    tutorial.data = {}
    tutorial.doneAt = nil
    local current = STEPS[step]
    if current and current.start then
        current.start(game, tutorial.data)
    end
end

local function wrap(text, size, width)
    local _, lines = Style.font(size):getWrap(text, width)
    return lines
end

local function buttons(x, y, w, h)
    local half = math.floor((w - 32 - 8) / 2)
    local by = y + h - BUTTON_H - 12
    return { x = x + 16, y = by, w = half, h = BUTTON_H }, { x = x + 16 + half + 8, y = by, w = half, h = BUTTON_H }
end

function Tutorial.visible(hud)
    local game = hud:game()
    if not game.options.tutorial or not game.human or game.phase == "ended" then return false end
    return not state(hud).closed
end

function Tutorial.size(hud)
    local step = STEPS[state(hud).step] or STEPS[#STEPS]
    local lines = wrap(step.text, 12, TEXT_W)
    return WIDTH, Style.headerHeight + 64 + #lines * 17 + BUTTON_H + 24
end

function Tutorial.position(_, w, _, W)
    return W - w - 15, 270
end

function Tutorial.update(hud)
    local game = hud:game()
    local tutorial = state(hud)
    local step = STEPS[tutorial.step]
    if not step or step.final then return end
    if not tutorial.started then
        tutorial.started = true
        enter(game, tutorial, tutorial.step)
    end
    local now = love.timer.getTime()
    if tutorial.doneAt then
        if now - tutorial.doneAt >= ADVANCE_SECONDS then
            enter(game, tutorial, tutorial.step + 1)
        end
    elseif step.done(game, tutorial.data) then
        tutorial.doneAt = now
    end
end

function Tutorial.draw(hud, x, y, w, h)
    Tutorial.update(hud)
    local tutorial = state(hud)
    local step = STEPS[tutorial.step] or STEPS[#STEPS]
    local u = Pixel.unit
    local top = y + Style.headerHeight + 10
    local progress = string.format("STEP %d / %d", tutorial.step, #STEPS)
    Pixel.text(progress, x + 16, top, 11, Style.colors.muted)
    local done = tutorial.doneAt ~= nil
    local font = Style.font(11)
    if done then
        local label = "DONE!"
        Pixel.text(label, x + w - 16 - font:getWidth(label), top, 11, Style.colors.good)
    end
    Pixel.text(step.title, x + 16, top + 18, 16, done and Style.colors.good or Style.colors.gold)
    local ty = top + 44
    for _, line in ipairs(wrap(step.text, 12, TEXT_W)) do
        Pixel.text(line, x + 16, ty, 12, Style.colors.text)
        ty = ty + 17
    end
    local fraction = (tutorial.step - 1 + (done and 1 or 0)) / #STEPS
    Pixel.meter("tutorial:progress", x + 16, ty + 4, w - 32, u * 2, fraction, Style.colors.gold)
    local skip, close = buttons(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    Style.button(skip.x, skip.y, skip.w, skip.h, step.final and "FINISH" or "SKIP STEP", {
        id = "tutorial:skip", hot = Style.inside(mx, my, skip.x, skip.y, skip.w, skip.h), color = step.final and Style.colors.good or nil, size = 11
    })
    Style.button(close.x, close.y, close.w, close.h, "END TUTORIAL", {
        id = "tutorial:close", hot = Style.inside(mx, my, close.x, close.y, close.w, close.h), color = Style.colors.bad, size = 11
    })
end

function Tutorial.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    local tutorial = state(hud)
    local skip, close = buttons(x, y, w, h)
    if Style.inside(mx, my, skip.x, skip.y, skip.w, skip.h) then
        local step = STEPS[tutorial.step]
        if not step or step.final then
            tutorial.closed = true
        else
            enter(hud:game(), tutorial, tutorial.step + 1)
        end
    elseif Style.inside(mx, my, close.x, close.y, close.w, close.h) then
        tutorial.closed = true
    end
end

return Tutorial
