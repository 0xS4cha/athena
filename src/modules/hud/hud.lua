local Class = require("src.core.class")
local GM = require("src.core.index")
local Flags = require("src.modules.hud.flags")
local ContextMenu = require("src.modules.hud.contextmenu")

local Layers = require("src.modules.hud.components.layers")
local Power = require("src.modules.hud.components.power")
local Settings = require("src.modules.hud.components.settings")

local Hud = Class()

function Hud:init()
    self.width = 200
    self.height = 145
    self.margin = 20
    self.hoveredLayerIdx = nil
    self.headerHeight = 26
    self.contextMenu = ContextMenu()
    self.powerAllocation = {
        expansion = 34,
        diplomacy = 33,
        army = 33
    }
    self.sliderDragging = nil
    self.layersX = nil
    self.layersY = nil
    self.powerX = nil
    self.powerY = nil
    self.settingsOpen = false
    self.settingSliderDragging = nil
    self.draggingPanel = nil
    self.gearRotation = 0
    self.gearImage = love.graphics.newImage("assets/Icons/Gear.png")
    self:loadConfig()
end

function Hud:drawFlag(flagKey, x, y, size)
    if not flagKey or flagKey == "" then return end
    local flag = Flags[flagKey]
    if not flag then return end
    local flagWidth = flag:getWidth()
    local flagHeight = flag:getHeight()
    if flagWidth <= 0 or flagHeight <= 0 then return end
    local scale = math.min(size / flagWidth, size / flagHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(flag, x, y, 0, scale, scale)
end

function Hud:getPanelRect()
    return self:getLayersRect()
end

function Hud:Draw()
    local map = GM.Game and GM.Game.Map
    if not map then return end

    love.graphics.push("all")

    Layers.draw(self)
    Power.draw(self)
    Settings.draw(self)

    if self.contextMenu then
        self.contextMenu:update()
        self.contextMenu:draw()
    end

    love.graphics.pop()
end

function Hud:MousePressed(x, y, button, istouch, presses)
    if self.contextMenu then
        local wasVisible = self.contextMenu.visible
        self.contextMenu:MousePressed(x, y, button, istouch, presses)
        if wasVisible then return end
    end

    if button ~= 1 then return end

    local mx, my = love.mouse.getPosition()
    local lx, ly, lw, _ = self:getLayersRect()
    local px2, py2, pw2, _ = self:getPowerRect()

    if Settings.mousePressed(self, mx, my, button) then
        return
    end

    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + self.headerHeight then
        self.draggingPanel = "layers"
        self.dragOffsetX = mx - lx
        self.dragOffsetY = my - ly
        return
    end

    if mx >= px2 and mx <= px2 + pw2 and my >= py2 and my <= py2 + self.headerHeight then
        self.draggingPanel = "power"
        self.dragOffsetX = mx - px2
        self.dragOffsetY = my - py2
        return
    end

    if Power.mousePressed(self, mx, my, button) then
        return
    end

    if Layers.mousePressed(self, mx, my, button) then
        return
    end
end

function Hud:MouseReleased(x, y, button, istouch, presses)
    if self.contextMenu then
        self.contextMenu:MouseReleased(x, y, button, istouch, presses)
    end
    if button == 1 then
        if self.sliderDragging or self.settingSliderDragging or self.draggingPanel then
            self:saveConfig()
        end
        self.sliderDragging = nil
        self.settingSliderDragging = nil
        self.draggingPanel = nil
    end
end

function Hud:KeyPressed(key, _, _)
    local map = GM.Game and GM.Game.Map
    if not map then return end
    if key == "1" then
        map:toggleLayer("terrain")
    elseif key == "2" then
        map:toggleLayer("political")
    elseif key == "3" then
        map:toggleLayer("buildings")
    end
end

function Hud:adjustSliders(changedKey, newValue)
    newValue = math.max(0, math.min(100, newValue))
    local keys = { "expansion", "diplomacy", "army" }
    local otherKeys = {}
    for _, k in ipairs(keys) do
        if k ~= changedKey then
            table.insert(otherKeys, k)
        end
    end
    local otherSum = 0
    for _, k in ipairs(otherKeys) do
        otherSum = otherSum + self.powerAllocation[k]
    end
    self.powerAllocation[changedKey] = newValue
    local remaining = 100 - newValue
    if otherSum > 0 then
        local val1 = math.floor((self.powerAllocation[otherKeys[1]] / otherSum) * remaining + 0.5)
        local val2 = remaining - val1
        self.powerAllocation[otherKeys[1]] = val1
        self.powerAllocation[otherKeys[2]] = val2
    else
        local val1 = math.floor(remaining / 2)
        local val2 = remaining - val1
        self.powerAllocation[otherKeys[1]] = val1
        self.powerAllocation[otherKeys[2]] = val2
    end
end

function Hud:getLayersRect()
    local W, _ = love.graphics.getDimensions()
    local x = self.layersX or (W - self.width - self.margin)
    local y = self.layersY or self.margin
    return x, y, self.width, self.height
end

function Hud:getPowerRect()
    local W, _ = love.graphics.getDimensions()
    local _, ly, _, lh = self:getLayersRect()
    local x = self.powerX or (W - self.width - self.margin)
    local y = self.powerY or (ly + lh + self.margin)
    return x, y, self.width, 170
end

function Hud:isMouseOver()
    local mx, my = love.mouse.getPosition()
    local lx, ly, lw, lh = self:getLayersRect()
    local px2, py2, pw2, ph2 = self:getPowerRect()
    if mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh then return true end
    if mx >= px2 and mx <= px2 + pw2 and my >= py2 and my <= py2 + ph2 then return true end
    if self.settingsOpen then
        local W, H = love.graphics.getDimensions()
        local sw, sh = 280, 380
        local sx = (W - sw) / 2
        local sy = (H - sh) / 2
        if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + sh then return true end
    end
    if mx >= 16 and mx <= 48 and my >= 16 and my <= 48 then return true end
    return false
end

function Hud:saveConfig()
    local data = string.format("layersX=%d\nlayersY=%d\npowerX=%d\npowerY=%d\n",
        math.floor(self.layersX or -1),
        math.floor(self.layersY or -1),
        math.floor(self.powerX or -1),
        math.floor(self.powerY or -1)
    )
    love.filesystem.write("hud_config.txt", data)
end

function Hud:loadConfig()
    if love.filesystem.getInfo("hud_config.txt") then
        local content = love.filesystem.read("hud_config.txt")
        if content then
            for line in string.gmatch(content, "[^\r\n]+") do
                local key, val = string.match(line, "([^=]+)=([^=]+)")
                if key and val then
                    val = tonumber(val)
                    if val and val >= 0 then
                        if key == "layersX" then
                            self.layersX = val
                        elseif key == "layersY" then
                            self.layersY = val
                        elseif key == "powerX" then
                            self.powerX = val
                        elseif key == "powerY" then
                            self.powerY = val
                        end
                    end
                end
            end
        end
    end
end

function Hud:Think(dt)
    local mx, my = love.mouse.getPosition()
    local gearHovered = mx >= 16 and mx <= 48 and my >= 16 and my <= 48
    if gearHovered then
        self.gearRotation = (self.gearRotation or 0) + dt * 2
    end

    if self.draggingPanel then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.draggingPanel = nil
            return
        end
        if self.draggingPanel == "layers" then
            self.layersX = mx - self.dragOffsetX
            self.layersY = my - self.dragOffsetY
        elseif self.draggingPanel == "power" then
            self.powerX = mx - self.dragOffsetX
            self.powerY = my - self.dragOffsetY
        end
    elseif self.settingSliderDragging then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.settingSliderDragging = nil
            return
        end
        local W, H = love.graphics.getDimensions()
        local sw = 280
        local sx = (W - sw) / 2
        local sliderX = sx + 15
        local sliderWidth = sw - 30
        local pct = math.max(0, math.min(1.0, (mx - sliderX) / sliderWidth))

        local _, _, lw, lh = self:getLayersRect()
        local _, _, pw, ph = self:getPowerRect()

        if self.settingSliderDragging == "layersX" then
            self.layersX = pct * (W - lw)
        elseif self.settingSliderDragging == "layersY" then
            self.layersY = pct * (H - lh)
        elseif self.settingSliderDragging == "powerX" then
            self.powerX = pct * (W - pw)
        elseif self.settingSliderDragging == "powerY" then
            self.powerY = pct * (H - ph)
        end
    elseif self.sliderDragging then
        if not love.mouse.isDown(1) then
            self:saveConfig()
            self.sliderDragging = nil
            return
        end
        local px2, _, pw2, _ = self:getPowerRect()
        local sliderX = px2 + 15
        local sliderWidth = pw2 - 30
        local pct = math.max(0, math.min(100, math.floor(((mx - sliderX) / sliderWidth) * 100 + 0.5)))
        self:adjustSliders(self.sliderDragging, pct)
    end
end

return Hud
