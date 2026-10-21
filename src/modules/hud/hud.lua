local Class = require("src.core.class")
local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local ContextMenu = require("src.modules.hud.contextmenu")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")

local Hud = Class()

local CONFIG_FILE = "hud_config.txt"
local APPEAR_SECONDS = 0.45
local MODAL_SECONDS = 0.3
local STAGGER = 0.07
local SLIDE = 56

Hud.componentPaths = {
    "src.modules.hud.components.info",
    "src.modules.hud.components.banner",
    "src.modules.hud.components.clock",
    "src.modules.hud.components.layers",
    "src.modules.hud.components.control",
    "src.modules.hud.components.leaderboard",
    "src.modules.hud.components.events",
    "src.modules.hud.components.settings",
    "src.modules.hud.components.endscreen",
    "src.modules.hud.components.help"
}

function Hud:init()
    self.components = {}
    self.positions = {}
    self.dragging = nil
    self.slider = nil
    self.contextMenu = ContextMenu(self)
    self.appear = {}
    for _, path in ipairs(self.componentPaths) do
        self:add(require(path))
    end
    self:loadConfig()
end

function Hud:add(component)
    table.insert(self.components, component)
    if component.init then
        component.init(self)
    end
end

function Hud:game()
    return GM.Session and GM.Session.Game
end

function Hud:camera()
    return GM.Session and GM.Session.Camera
end

function Hud:isVisible(component)
    if component.visible then
        return component.visible(self)
    end
    return true
end

function Hud:rect(component)
    local W, H = love.graphics.getDimensions()
    local w, h = component.size(self)
    local x, y
    local saved = component.panel and self.positions[component.id]
    if saved then
        x, y = saved.x, saved.y
    else
        x, y = component.position(self, w, h, W, H)
    end
    x = math.max(0, math.min(W - w, x))
    y = math.max(0, math.min(H - h, y))
    return x, y, w, h
end

function Hud:hits(component, mx, my)
    if not self:isVisible(component) then
        return false
    end
    if component.hit then
        return component.hit(self, mx, my)
    end
    if not component.size then
        return false
    end
    local x, y, w, h = self:rect(component)
    return Style.inside(mx, my, x, y, w, h)
end

function Hud:Captures(mx, my)
    if self.contextMenu.visible or self.dragging or self.slider then
        return true
    end
    for _, component in ipairs(self.components) do
        if component.modal and self:isVisible(component) then
            return true
        end
        if self:hits(component, mx, my) then
            return true
        end
    end
    return false
end

function Hud:startSlider(x, w, setter)
    self.slider = { x = x, w = w, set = setter }
    self:updateSlider()
end

function Hud:updateSlider()
    local mx = love.mouse.getPosition()
    local pct = math.max(0, math.min(1, (mx - self.slider.x) / self.slider.w))
    self.slider.set(pct)
end

function Hud:appearance(component)
    if GM.Flags and GM.Flags.ci then
        return 100
    end
    local now = love.timer.getTime()
    if not self.appear[component.id] then
        self.appear[component.id] = now + self.stagger
        self.stagger = self.stagger + STAGGER
    end
    return now - self.appear[component.id]
end

function Hud:appeared(component)
    if GM.Flags and GM.Flags.ci then
        return 100
    end
    local id = component.id
    return id and self.appear[id] and love.timer.getTime() - self.appear[id] or 0
end

function Hud:drawPanel(component, x, y, w, h)
    local age = self:appearance(component)
    local W, H = love.graphics.getDimensions()
    love.graphics.push()
    if component.modal then
        local t = Fx.clamp(age / MODAL_SECONDS, 0, 1)
        local scale = 0.9 + 0.1 * Fx.outBack(t)
        local cx, cy = x + w / 2, y + h / 2
        love.graphics.translate(cx, cy)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-cx, -cy)
        Pixel.alpha = Fx.outCubic(t)
    else
        local t = Fx.outCubic(age / APPEAR_SECONDS)
        local cx, cy = x + w / 2, y + h / 2
        local dx, dy = 0, 0
        if cx < W * 0.35 then
            dx = -1
        elseif cx > W * 0.65 then
            dx = 1
        else
            dy = cy < H / 2 and -1 or 1
        end
        love.graphics.translate(math.floor((1 - t) * SLIDE * dx), math.floor((1 - t) * SLIDE * dy))
        Pixel.alpha = math.max(0, t)
    end
    if age >= 0 then
        if component.panel then
            Style.frame(x, y, w, h, component.title, { accent = component.accent })
        end
        component.draw(self, x, y, w, h)
    end
    love.graphics.pop()
    Pixel.alpha = 1
end

function Hud:Draw()
    local game = self:game()
    if not game then return end
    if self.drawnGame ~= game then
        self.drawnGame = game
        self.appear = {}
    end
    love.graphics.push("all")
    self.stagger = 0
    for _, component in ipairs(self.components) do
        if self:isVisible(component) then
            if component.size then
                self:drawPanel(component, self:rect(component))
            else
                component.draw(self)
            end
        elseif component.id then
            self.appear[component.id] = nil
        end
    end
    self.contextMenu:draw()
    love.graphics.pop()
end

function Hud:Think(dt)
    if not self:game() then return end
    local mx, my = love.mouse.getPosition()
    if self.dragging then
        if love.mouse.isDown(1) then
            self.positions[self.dragging.id] = { x = mx - self.dragging.ox, y = my - self.dragging.oy }
        else
            self.dragging = nil
            self:saveConfig()
        end
    end
    if self.slider then
        if love.mouse.isDown(1) then
            self:updateSlider()
        else
            self.slider = nil
        end
    end
    for _, component in ipairs(self.components) do
        if component.think then
            component.think(self, dt)
        end
    end
    self.contextMenu:update()
end

function Hud:MousePressed(x, y, button)
    if not self:game() then return end
    if self.contextMenu:mousePressed(x, y, button) then
        return
    end
    for k = #self.components, 1, -1 do
        local component = self.components[k]
        if self:isVisible(component) and (component.modal or self:hits(component, x, y)) then
            if button == 1 and component.panel then
                local px, py = self:rect(component)
                if y <= py + Style.headerHeight then
                    self.dragging = { id = component.id, ox = x - px, oy = y - py }
                    return
                end
            end
            if component.mousePressed then
                if component.size then
                    local px, py, pw, ph = self:rect(component)
                    component.mousePressed(self, x, y, button, px, py, pw, ph)
                else
                    component.mousePressed(self, x, y, button)
                end
            end
            return
        end
    end
end

function Hud:MouseReleased(x, y, button)
    if not self:game() then return end
    self.contextMenu:mouseReleased(x, y, button)
end

function Hud:KeyPressed(key)
    if not self:game() then return end
    if key == "escape" then
        if self.contextMenu.visible then
            self.contextMenu:close()
            return
        end
        if self.helpOpen then
            self.helpOpen = false
            return
        end
    end
    for _, component in ipairs(self.components) do
        if component.keyPressed and component.keyPressed(self, key) then
            return
        end
    end
end

function Hud:resetPositions()
    self.positions = {}
    self:saveConfig()
end

function Hud:saveConfig()
    local lines = {}
    for id, pos in pairs(self.positions) do
        lines[#lines + 1] = string.format("%s=%d,%d", id, math.floor(pos.x), math.floor(pos.y))
    end
    love.filesystem.write(CONFIG_FILE, table.concat(lines, "\n"))
end

function Hud:loadConfig()
    local content = love.filesystem.getInfo(CONFIG_FILE) and love.filesystem.read(CONFIG_FILE)
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local id, x, y = line:match("^([%w_]+)=(%-?%d+),(%-?%d+)$")
        if id then
            self.positions[id] = { x = tonumber(x), y = tonumber(y) }
        end
    end
end

return Hud
