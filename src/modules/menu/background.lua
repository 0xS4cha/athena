local Class = require("src.core.class")
local Camera = require("src.core.camera")
local Game = require("src.modules.game.game")
local Overlay = require("src.modules.game.overlay")
local Fx = require("src.modules.hud.fx")

local Background = Class()

local POOL = { "world", "pangaea", "oceania", "italia", "japan", "danishstraits", "bosphorusstraits", "caribbean", "archipelagosea", "falklandislands" }
local BOTS = 40
local PREWARM_TICKS = 160
local SHOT_SECONDS = 9
local END_HOLD_SECONDS = 6
local MAX_AGE_SECONDS = 420
local FEED_SIZE = 4
local PARALLAX = 22

function Background:init()
    self.game = nil
    self.camera = nil
    self.feed = {}
    self.fade = 1
    self.lastMap = nil
end

function Background:start(speedIndex)
    local choices = {}
    for _, name in ipairs(POOL) do
        if name ~= self.lastMap and love.filesystem.getInfo("assets/maps/" .. name .. "/manifest.json") then
            choices[#choices + 1] = name
        end
    end
    if #choices == 0 then return end
    local name = choices[love.math.random(#choices)]
    self.lastMap = name
    self.game = nil
    collectgarbage()

    local game = Game({
        map = "assets/maps/" .. name .. "/",
        bots = BOTS,
        nations = true,
        difficulty = "hard",
        spectator = true,
        playerName = "Spectator",
        seed = os.time() + love.math.random(1, 100000)
    })
    game.spawnTicksLeft = 1
    for _ = 1, PREWARM_TICKS do
        game:step()
    end
    game.speedIndex = speedIndex or 2
    self.game = game
    self.mapName = game.map.manifest.name or name
    self.lastEvent = game.eventSerial
    self.feed = {}
    self.age = 0
    self.ended = 0
    self.fade = 1
    self.statsTick = -1
    self:refreshStats()

    local camera = Camera()
    camera.mapW = game.map.width
    camera.mapH = game.map.height
    self.camera = camera
    local x, y, zoom = self:pickShot()
    self.view = { x = x, y = y, zoom = zoom * 0.85 }
    self.target = { x = x, y = y, zoom = zoom }
    self.shotTimer = SHOT_SECONDS
    self.parallaxX, self.parallaxY = 0, 0
    self:applyCamera()
end

function Background:stop()
    self.game = nil
    self.camera = nil
    self.feed = {}
end

function Background:setSpeed(speedIndex)
    if self.game then
        self.game.speedIndex = speedIndex
    end
end

function Background:pickShot()
    local game = self.game
    local map = game.map
    local roll = love.math.random()
    local explosion = game.explosions and game.explosions[#game.explosions]
    if explosion and roll < 0.8 then
        return explosion.x, explosion.y, 2.6
    end
    local combat = game.combat
    if combat and combat.head > 0 and roll < 0.55 then
        local tile = combat.tiles[combat.head]
        if tile and game.tick - combat.ticks[combat.head] < 40 then
            local x, y = map:coords(tile)
            return x, y, 2 + love.math.random() * 1.2
        end
    end
    local leaders = self.stats and self.stats.leaders or {}
    if #leaders > 0 and roll < 0.85 then
        local player = leaders[love.math.random(#leaders)]
        local x, y = player:center()
        return x, y, 1.3 + love.math.random() * 0.6
    end
    return map.width / 2, map.height / 2, 1.05
end

function Background:refreshStats()
    local game = self.game
    local list = {}
    local nations, tribes = 0, 0
    for _, player in ipairs(game.players) do
        if player.alive and player.spawned and player.tiles > 0 then
            list[#list + 1] = player
            if player:isBot() then
                tribes = tribes + 1
            else
                nations = nations + 1
            end
        end
    end
    table.sort(list, function(a, b) return a.tiles > b.tiles end)
    self.stats = {
        nations = nations,
        tribes = tribes,
        leaders = { list[1], list[2], list[3] },
        land = game.map.landCount
    }
end

function Background:collectEvents()
    local game = self.game
    for _, event in ipairs(game.events) do
        if event.id > self.lastEvent then
            self.lastEvent = event.id
            table.insert(self.feed, 1, { text = event.text, color = event.color, time = love.timer.getTime() })
            if #self.feed > FEED_SIZE then
                table.remove(self.feed)
            end
        end
    end
end

function Background:applyCamera()
    local camera = self.camera
    local W, H = love.graphics.getDimensions()
    local base = math.max(W / camera.mapW, H / camera.mapH)
    camera.scale = math.min(base * self.view.zoom, math.max(base, 5))
    camera:centerOn(self.view.x + self.parallaxX / camera.scale, self.view.y + self.parallaxY / camera.scale)
end

function Background:update(dt, canRestart)
    local game = self.game
    if not game then return end
    dt = math.min(dt, 0.1)
    game:update(dt)
    self.age = self.age + dt
    self:collectEvents()
    if game.tick ~= self.statsTick and game.tick % 10 == 0 then
        self.statsTick = game.tick
        self:refreshStats()
    end

    self.shotTimer = self.shotTimer - dt
    if self.shotTimer <= 0 then
        self.shotTimer = SHOT_SECONDS
        local x, y, zoom = self:pickShot()
        self.target = { x = x, y = y, zoom = zoom }
    end
    local view, target = self.view, self.target
    view.x = Fx.approach(view.x, target.x, 0.45, dt)
    view.y = Fx.approach(view.y, target.y, 0.45, dt)
    view.zoom = Fx.approach(view.zoom, target.zoom, 0.35, dt)

    local W, H = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    self.parallaxX = Fx.approach(self.parallaxX, (mx / W - 0.5) * PARALLAX, 3, dt)
    self.parallaxY = Fx.approach(self.parallaxY, (my / H - 0.5) * PARALLAX, 3, dt)
    self:applyCamera()

    local finished = game.phase == "ended" or self.age > MAX_AGE_SECONDS
    if finished then
        self.ended = self.ended + dt
    end
    if finished and self.ended > END_HOLD_SECONDS and canRestart then
        self.fade = Fx.approach(self.fade, 1.05, 3, dt)
        if self.fade >= 1 then
            self:start(game.speedIndex)
        end
    else
        self.fade = Fx.approach(self.fade, 0, 1.6, dt)
    end
end

function Background:draw()
    local game = self.game
    if not game then return end
    love.graphics.push("all")
    self.camera:apply()
    game.renderer:draw()
    self.camera:clear()
    Overlay.draw(game, self.camera)
    love.graphics.pop()
    if self.fade > 0.005 then
        love.graphics.setColor(0.02, 0.03, 0.06, math.min(1, self.fade))
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
end

return Background
