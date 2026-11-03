local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")
local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local BuildBar = require("src.modules.hud.components.buildbar")

local Tutorial = { id = "tutorial", title = "TUTORIAL", panel = true, accent = Style.colors.gold, advanceSeconds = 1.2 }

local WIDTH = 340
local TEXT_W = WIDTH - 32
local BUTTON_H = 28
local BUTTON_GAP = 6
local MARKER_REFRESH = 1
local DEFAULT_LAYERS = { terrain = true, political = true, units = true, names = true, supply = false, threat = false, diplomacy = false }

local function layersChanged(game)
    for name, value in pairs(DEFAULT_LAYERS) do
        if (game.renderer.layers[name] == true) ~= value then return true end
    end
    return false
end

local function neighbours(map, i)
    local w = map.width
    local x = i % w
    return x > 0 and i - 1 or nil, x < w - 1 and i + 1 or nil, i >= w and i - w or nil, i < map.size - w and i + w or nil
end

local function borderNeighbour(game, accept)
    local map = game.map
    for i in pairs(game.human.borders) do
        local a, b, c, d = neighbours(map, i)
        for _, j in pairs({ a, b, c, d }) do
            if accept(j) then return j end
        end
    end
    return nil
end

local function wildernessTile(game)
    local map = game.map
    return borderNeighbour(game, function(j) return map:isLand(j) and map.owner[j] == 0 end)
end

local function tribeTile(game)
    local map = game.map
    local tile = borderNeighbour(game, function(j)
        local owner = map:isLand(j) and map.owner[j] or 0
        return owner ~= 0 and owner ~= game.human.id and game.players[owner]:isBot()
    end)
    if tile then return tile end
    local hx, hy = game.human:center()
    local best, bestD
    for _, player in ipairs(game.players) do
        if player:isBot() and player.alive and player.tiles > 0 then
            local x, y = player:center()
            local d = (x - hx) ^ 2 + (y - hy) ^ 2
            if not bestD or d < bestD then best, bestD = player, d end
        end
    end
    return best and map:tileAt(best:center()) or nil
end

local function homeTile(game)
    local capital = game.human.capital
    return capital and capital.tile or game.human.spawnTile
end

local function coastTile(game)
    local map = game.map
    for i in pairs(game.human.borders) do
        if map:isCoast(i) and Units.isSpaced(game, i) then return i end
    end
    return nil
end

local STEPS = {
    {
        chapter = "BASICS",
        title = "Choose your land",
        text = "Click anywhere on land to place your capital. You can click again to move it while the countdown runs.",
        done = function(game) return game.human.spawned end
    },
    {
        chapter = "BASICS",
        title = "Start the game",
        text = "Press SPACE to start right away. Every nation grows from the spot it picked.",
        done = function(game) return game.phase == "playing" end
    },
    {
        chapter = "BASICS",
        title = "Expand",
        text = "Left-click the wilderness next to your border, where the arrow points: your troops march out and claim it tile by tile.",
        marker = wildernessTile,
        start = function(game, state) state.tiles = game.human.tiles end,
        done = function(game, state) return game.human.tiles >= (state.tiles or 0) + 40 end
    },
    {
        chapter = "BASICS",
        title = "Balance your people",
        text = "Drag the Troops / Workers slider in the Empire panel. Workers earn gold, troops attack and defend.",
        highlight = "control",
        start = function(game, state) state.ratio = game.human.troopRatio end,
        done = function(game, state) return math.abs(game.human.troopRatio - (state.ratio or 0)) > 0.02 end
    },
    {
        chapter = "BASICS",
        title = "Size your attacks",
        text = "The Attack Ratio slider sets the share of your troops sent by each click. Change it now.",
        highlight = "control",
        start = function(game, state) state.ratio = game.human.attackRatio end,
        done = function(game, state) return math.abs(game.human.attackRatio - (state.ratio or 0)) > 0.02 end
    },
    {
        chapter = "ECONOMY",
        title = "Build a city",
        text = "Right-click your own land, open Build and pick City. Cities raise your population cap and administer the land around them.",
        marker = homeTile,
        done = function(game) return game.human:unitCount("city") > 0 end
    },
    {
        chapter = "ECONOMY",
        title = "Use the hotkeys",
        text = "This bar lists the key of each building. Press one to aim it, click to place it, and press Escape to cancel. Try a key now.",
        highlight = "buildbar",
        done = function(game) return game.buildAim ~= nil end
    },
    {
        chapter = "ECONOMY",
        title = "Govern your land",
        text = "Land far from your capital and cities earns less gold: the gold panel shows the share you lose. Spread cities across a wide empire, and hover any tile to read its details.",
        highlight = "control",
        info = true
    },
    {
        chapter = "WAR",
        title = "Attack a tribe",
        text = "Find a neighbouring tribe and left-click its land. Each tile costs troops depending on terrain and defenders.",
        marker = tribeTile,
        done = function(game)
            for _, attack in ipairs(Attack.outgoing(game, game.human)) do
                if attack.target then return true end
            end
            return false
        end
    },
    {
        chapter = "WAR",
        title = "Follow your attacks",
        text = "The Empire panel lists your running attacks. Retreat from one there to get most of its troops back. Far from your cities, attacks cost more: press 5 to see your supply range.",
        highlight = "control",
        info = true
    },
    {
        chapter = "WAR",
        title = "Reach the sea",
        text = "Right-click your coast and build a Military Port. Without one you cannot leave your continent.",
        marker = coastTile,
        done = function(game) return game.human:unitCount("militaryPort") > 0 end
    },
    {
        chapter = "WAR",
        title = "Boats and warships",
        text = "With a port, left-click a coast you do not border to send a boat. Warships and submarines are built from the same menu; they sink transports and blockade enemy ports.",
        info = true
    },
    {
        chapter = "WAR",
        title = "Read the map",
        text = "Press the keys 1 to 7 to toggle map layers such as supply lines, threats and diplomacy. H lists every control.",
        highlight = "layers",
        done = function(game) return layersChanged(game) end
    },
    {
        chapter = "WORLD",
        title = "Research",
        text = "Press E or click this button to open the research tree. Technologies are paid over time, and each branch asks you to choose one doctrine. Plan your empire's identity.",
        highlight = "researchbar",
        info = true
    },
    {
        chapter = "WORLD",
        title = "Nukes",
        text = "A missile silo launches nukes at what you right-click. SAM launchers intercept them, bunkers shelter you, and radars reveal hidden silos and warn you of launches.",
        info = true
    },
    {
        chapter = "WORLD",
        title = "Diplomacy",
        text = "Nations, unlike tribes, can be right-clicked for alliances, pacts, loans and coalitions. Breaking your word marks you as a traitor. A coalition can bring down a dominant empire.",
        info = true
    },
    {
        chapter = "WORLD",
        title = "After the battle",
        text = "Every game is saved under Replays in the main menu. New Game has modes and custom rules. If a war is lost, Surrender is in the pause menu.",
        info = true
    },
    {
        chapter = "WORLD",
        title = "You are ready",
        text = "Control 80% of the land or be the last nation standing to win. Good luck, commander!",
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

local function enter(game, tutorial, step, manual)
    tutorial.step = step
    tutorial.data = {}
    tutorial.doneAt = nil
    tutorial.manual = manual == true
    tutorial.marker = nil
    tutorial.markerAt = nil
    local current = STEPS[step]
    if current and current.start then
        current.start(game, tutorial.data)
    end
    if current and current.final and GM.Menu and GM.Menu.setOption then
        GM.Menu:setOption("tutorialDone", true)
    end
end

function Tutorial.next(hud)
    local tutorial = state(hud)
    local step = STEPS[tutorial.step]
    if not step or step.final then
        tutorial.closed = true
    else
        enter(hud:game(), tutorial, tutorial.step + 1)
    end
end

function Tutorial.previous(hud)
    local tutorial = state(hud)
    if tutorial.step > 1 then
        enter(hud:game(), tutorial, tutorial.step - 1, true)
    end
end

local function wrap(text, size, width)
    local _, lines = Style.font(size):getWrap(text, width)
    return lines
end

local function buttons(x, y, w, h)
    local width = math.floor((w - 32 - BUTTON_GAP * 2) / 3)
    local by = y + h - BUTTON_H - 12
    local function at(k)
        return { x = x + 16 + (k - 1) * (width + BUTTON_GAP), y = by, w = width, h = BUTTON_H }
    end
    return at(1), at(2), at(3)
end

function Tutorial.visible(hud)
    local game = hud:game()
    if not game.options.tutorial or game.options.replay or not game.human or game.phase == "ended" then return false end
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
    if step.info or tutorial.manual then return end
    local now = love.timer.getTime()
    if tutorial.doneAt then
        if now - tutorial.doneAt >= Tutorial.advanceSeconds then
            enter(game, tutorial, tutorial.step + 1)
        end
    elseif step.done(game, tutorial.data) then
        tutorial.doneAt = now
    end
end

function Tutorial.markerTile(hud)
    local tutorial = state(hud)
    local step = STEPS[tutorial.step]
    if not step or not step.marker or tutorial.doneAt then return nil end
    local game = hud:game()
    if not game.human.spawned then return nil end
    local now = love.timer.getTime()
    if not tutorial.markerAt or now - tutorial.markerAt >= MARKER_REFRESH then
        tutorial.markerAt = now
        tutorial.marker = step.marker(game)
    end
    return tutorial.marker
end

local function highlightRect(hud, id)
    if id == "buildbar" then
        if not BuildBar.visible(hud) then return nil end
        return BuildBar.bounds(hud:game())
    end
    for _, component in ipairs(hud.components) do
        if component.id == id and hud:isVisible(component) then
            return hud:rect(component)
        end
    end
    return nil
end

local function drawHighlight(hud, id)
    local x, y, w, h = highlightRect(hud, id)
    if not x then return end
    local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 5)
    local u = Pixel.unit
    Pixel.color(Style.colors.gold, pulse)
    love.graphics.rectangle("fill", x - u * 2, y - u * 2, w + u * 4, u)
    love.graphics.rectangle("fill", x - u * 2, y + h + u, w + u * 4, u)
    love.graphics.rectangle("fill", x - u * 2, y - u * 2, u, h + u * 4)
    love.graphics.rectangle("fill", x + w + u, y - u * 2, u, h + u * 4)
end

local function drawMarker(hud)
    local tile = Tutorial.markerTile(hud)
    local camera = hud:camera()
    if not tile or not camera then return end
    local game = hud:game()
    local tx, ty = game.map:coords(tile)
    local sx, sy = camera:toScreen(tx + 0.5, ty + 0.5)
    local W, H = love.graphics.getDimensions()
    sx, sy = math.max(24, math.min(W - 24, sx)), math.max(44, math.min(H - 24, sy))
    local u = Pixel.unit
    local bounce = math.floor(math.abs(math.sin(love.timer.getTime() * 4)) * 8 / u) * u
    Pixel.color(Pixel.colors.ink)
    love.graphics.rectangle("fill", sx - u * 2, sy - u * 12 - bounce, u * 4, u * 7)
    for k = 0, 4 do
        love.graphics.rectangle("fill", sx - (5 - k) * u, sy - u * (6 - k) - bounce, (5 - k) * 2 * u, u)
    end
    Pixel.color(Style.colors.gold)
    love.graphics.rectangle("fill", sx - u, sy - u * 11 - bounce, u * 2, u * 6)
    for k = 0, 3 do
        love.graphics.rectangle("fill", sx - (4 - k) * u, sy - u * (5 - k) - bounce, (4 - k) * 2 * u, u)
    end
end

function Tutorial.draw(hud, x, y, w, h)
    Tutorial.update(hud)
    local tutorial = state(hud)
    local step = STEPS[tutorial.step] or STEPS[#STEPS]
    local u = Pixel.unit
    local done = tutorial.doneAt ~= nil
    if step.highlight and not done then
        drawHighlight(hud, step.highlight)
    end
    drawMarker(hud)
    local top = y + Style.headerHeight + 10
    local progress = string.format("%s  -  STEP %d / %d", step.chapter, tutorial.step, #STEPS)
    Pixel.text(progress, x + 16, top, 11, Style.colors.muted)
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
    local back, forward, close = buttons(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    Style.button(back.x, back.y, back.w, back.h, "BACK", {
        id = "tutorial:back", hot = Style.inside(mx, my, back.x, back.y, back.w, back.h), size = 11, color = tutorial.step > 1 and nil or Style.colors.muted
    })
    local waiting = not (step.info or step.final or tutorial.manual)
    Style.button(forward.x, forward.y, forward.w, forward.h, step.final and "FINISH" or waiting and "SKIP" or "NEXT", {
        id = "tutorial:next", hot = Style.inside(mx, my, forward.x, forward.y, forward.w, forward.h), color = not waiting and Style.colors.good or nil, size = 11
    })
    Style.button(close.x, close.y, close.w, close.h, "END", {
        id = "tutorial:close", hot = Style.inside(mx, my, close.x, close.y, close.w, close.h), color = Style.colors.bad, size = 11
    })
end

function Tutorial.mousePressed(hud, mx, my, button, x, y, w, h)
    if button ~= 1 then return end
    local tutorial = state(hud)
    local back, forward, close = buttons(x, y, w, h)
    if Style.inside(mx, my, back.x, back.y, back.w, back.h) then
        Tutorial.previous(hud)
    elseif Style.inside(mx, my, forward.x, forward.y, forward.w, forward.h) then
        Tutorial.next(hud)
    elseif Style.inside(mx, my, close.x, close.y, close.w, close.h) then
        tutorial.closed = true
    end
end

function Tutorial.keyPressed(hud, key)
    if (key ~= "return" and key ~= "kpenter") or hud.settingsOpen or not Tutorial.visible(hud) then return false end
    local tutorial = state(hud)
    local step = STEPS[tutorial.step]
    if step and (step.info or step.final or tutorial.manual) then
        Tutorial.next(hud)
        return true
    end
    return false
end

return Tutorial
