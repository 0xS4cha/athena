local Class = require("src.core.class")
local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local ContextMenu = require("src.modules.hud.contextmenu")

local Hud = Class()

local CONFIG_FILE = "hud_config.txt"

Hud.componentPaths = {
    "src.modules.hud.components.info",
    "src.modules.hud.components.banner",
    "src.modules.hud.components.layers",
    "src.modules.hud.components.control",
    "src.modules.hud.components.leaderboard",
    "src.modules.hud.components.events",
    "src.modules.hud.components.settings",
    "src.modules.hud.components.endscreen"
}

function Hud:init()
    self.components = {}
    self.positions = {}
    self.dragging = nil
    self.slider = nil
    self.contextMenu = ContextMenu(self)
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

function Hud:Draw()
    if not self:game() then return end
    love.graphics.push("all")
    for _, component in ipairs(self.components) do
        if self:isVisible(component) then
            if component.size then
                local x, y, w, h = self:rect(component)
                if component.panel then
                    Style.frame(x, y, w, h, component.title)
                end
                component.draw(self, x, y, w, h)
            else
                component.draw(self)
            end
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
