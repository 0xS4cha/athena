local Class = require("src.core.class")
local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Interaction = require("src.modules.game.interaction")
local Pixel = require("src.modules.hud.pixel")
local Fx = require("src.modules.hud.fx")
local Structures = require("src.modules.game.structures")

local ContextMenu = Class()

function ContextMenu:init(hud)
    self.hud = hud
    self.visible = false
    self.x = 0
    self.y = 0
    self.title = ""
    self.items = {}
    self.stack = {}
    self.hoveredIdx = nil
    self.width = 270
    self.itemHeight = 28
    self.openedAt = 0
    self.direction = 1
    self.pressedX = 0
    self.pressedY = 0
end

function ContextMenu:height()
    return Style.headerHeight + #self.items * self.itemHeight + 8
end

function ContextMenu:layout()
    local W, H = love.graphics.getDimensions()
    if self.x + self.width > W then self.x = W - self.width - 10 end
    if self.y + self:height() > H then self.y = H - self:height() - 10 end
    self.x = math.max(0, self.x)
    self.y = math.max(0, self.y)
end

function ContextMenu:open(mx, my, title, items)
    self.x = mx
    self.y = my
    self.title = title
    self.items = items
    self.stack = {}
    self.visible = #items > 0
    self.hoveredIdx = nil
    self.openedAt = love.timer.getTime()
    self.direction = 1
    self:layout()
end

function ContextMenu:push(title, items)
    table.insert(self.stack, { title = self.title, items = self.items })
    table.insert(items, { label = "Back", icon = "Enter2.png", back = true })
    self.title = title
    self.items = items
    self.openedAt = love.timer.getTime()
    self.direction = 1
    self:layout()
end

function ContextMenu:pop()
    local previous = table.remove(self.stack)
    if previous then
        self.title = previous.title
        self.items = previous.items
        self.openedAt = love.timer.getTime()
        self.direction = -1
        self:layout()
    else
        self:close()
    end
end

function ContextMenu:close()
    local game = self.hud:game()
    if game then
        game.nukeHover = nil
    end
    self.visible = false
    self.items = {}
    self.stack = {}
end

function ContextMenu:update()
    local game = self.hud:game()
    if game then
        game.nukeHover = nil
    end
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    self.hoveredIdx = nil
    if Style.inside(mx, my, self.x, self.y, self.width, self:height()) then
        local localY = my - (self.y + Style.headerHeight + 4)
        if localY >= 0 then
            local idx = math.floor(localY / self.itemHeight) + 1
            if idx >= 1 and idx <= #self.items then
                self.hoveredIdx = idx
                if game then
                    game.nukeHover = self.items[idx].preview
                end
            end
        end
    end
end

function ContextMenu:draw()
    if not self.visible then return end
    love.graphics.push("all")
    local u = Pixel.unit
    local h = self:height()
    local age = love.timer.getTime() - self.openedAt
    local open = Fx.outCubic(age / 0.18)
    Pixel.alpha = open
    local fullH = h
    h = math.max(Style.headerHeight + u * 2, math.floor(fullH * (0.6 + 0.4 * open) / u) * u)
    Style.frame(self.x, self.y, self.width, h, self.title, { grip = false, cornerAlpha = 0.8 })
    love.graphics.setScissor(self.x, self.y, self.width, h)

    local font = Style.font(12)
    local startY = self.y + Style.headerHeight + 4
    local depth = #self.stack
    for i, item in ipairs(self.items) do
        local itemY = startY + (i - 1) * self.itemHeight
        local e = Fx.outCubic(Fx.clamp(age * 8 - i * 0.35, 0, 1))
        Pixel.alpha = e
        local dx = math.floor((1 - e) * 24 * self.direction / u) * u
        local hot = Pixel.ease("ctx:" .. depth .. ":" .. i .. ":" .. item.label, self.hoveredIdx == i and not item.disabled and not item.info, 20)
        local ix = self.x + dx
        if hot > 0.01 then
            Pixel.color(item.color or Pixel.colors.hover, 0.25 + 0.55 * hot)
            Pixel.block(ix + u * 2, itemY + 1, self.width - u * 4, self.itemHeight - 2, u)
            Pixel.color(item.color or Pixel.colors.hover, hot)
            love.graphics.rectangle("fill", ix + u * 2, itemY + u + 1, u, self.itemHeight - 2 - u * 2)
        end
        local shift = math.floor(hot * 2) * u
        local game = self.hud:game()
        local drawn = item.sprite and game and Structures.icon(item.sprite, ix + 9 + shift, itemY + math.floor((self.itemHeight - 22) / 2), 22, game.human.color, (item.disabled and 0.4 or 1) * Pixel.alpha)
        if item.icon and not drawn then
            Pixel.icon(item.icon, ix + 12 + shift, itemY + math.floor((self.itemHeight - 16) / 2), 16, item.disabled and 0.35 or 1)
        end
        local color
        if item.disabled then
            color = Style.colors.disabled
        elseif item.color then
            color = item.color
        else
            color = Pixel.mix({ 0.8, 0.8, 0.85, 1 }, { 1, 1, 1, 1 }, hot)
        end
        Pixel.text(item.label, ix + 36 + shift, itemY + 6, 12, color)
        local right = ix + self.width - 12
        if item.submenu then
            Pixel.color(item.disabled and Style.colors.disabled or Style.colors.gold, 0.6 + 0.4 * hot)
            local bob = math.floor(hot * (math.sin(love.timer.getTime() * 8) + 1)) * u
            Pixel.arrow(right - u * 3 + bob, itemY + math.floor(self.itemHeight / 2), 3, 1)
            right = right - u * 6
        end
        if item.sublabel then
            local color = item.disabled and Style.colors.disabled or (item.sublabelColor or Style.colors.gold)
            Pixel.text(item.sublabel, right - font:getWidth(item.sublabel), itemY + 6, 12, color)
        end
    end
    love.graphics.setScissor()
    Pixel.alpha = 1
    love.graphics.pop()
end

function ContextMenu:activate(item)
    if item.disabled or item.info then return end
    if item.back then
        self:pop()
        return
    end
    if item.submenu then
        local title, items = item.submenu()
        self:push(title, items)
        return
    end
    self:close()
    if item.action then
        item.action()
    end
end

function ContextMenu:mousePressed(x, y, button)
    if button == 2 then
        self.pressedX = x
        self.pressedY = y
    end
    if not self.visible then
        return false
    end
    local inside = Style.inside(x, y, self.x, self.y, self.width, self:height())
    if button == 1 then
        if self.hoveredIdx and self.items[self.hoveredIdx] then
            self:activate(self.items[self.hoveredIdx])
        elseif not inside then
            self:close()
        end
        return true
    end
    if not inside then
        self:close()
    end
    return true
end

function ContextMenu:mouseReleased(x, y, button)
    if button ~= 2 then return end
    local current = self.hud:game()
    if current and (current.nukeAim or current.buildAim) then
        current.nukeAim = nil
        current.buildAim = nil
        return
    end
    local dx = x - self.pressedX
    local dy = y - self.pressedY
    if dx * dx + dy * dy >= 36 then return end
    local game = self.hud:game()
    local camera = self.hud:camera()
    if not game or not camera then return end
    for _, component in ipairs(self.hud.components) do
        if self.hud:hits(component, x, y) then return end
    end
    local wx, wy = camera:toWorld(x, y)
    local tile = game.map:tileAt(wx, wy)
    if not tile then return end
    local title, items = Interaction.menu(game, tile)
    self:open(x, y, title, items)
end

return ContextMenu
