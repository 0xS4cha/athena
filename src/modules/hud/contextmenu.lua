local Class = require("src.core.class")
local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Interaction = require("src.modules.game.interaction")
local Icons = require("src.modules.hud.icons")

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
    self.width = 230
    self.itemHeight = 26
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
    self:layout()
end

function ContextMenu:push(title, items)
    table.insert(self.stack, { title = self.title, items = self.items })
    table.insert(items, { label = "Back", icon = "Enter2.png", back = true })
    self.title = title
    self.items = items
    self:layout()
end

function ContextMenu:pop()
    local previous = table.remove(self.stack)
    if previous then
        self.title = previous.title
        self.items = previous.items
        self:layout()
    else
        self:close()
    end
end

function ContextMenu:close()
    self.visible = false
    self.items = {}
    self.stack = {}
end

function ContextMenu:update()
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    self.hoveredIdx = nil
    if Style.inside(mx, my, self.x, self.y, self.width, self:height()) then
        local localY = my - (self.y + Style.headerHeight + 4)
        if localY >= 0 then
            local idx = math.floor(localY / self.itemHeight) + 1
            if idx >= 1 and idx <= #self.items then
                self.hoveredIdx = idx
            end
        end
    end
end

function ContextMenu:draw()
    if not self.visible then return end
    love.graphics.push("all")
    local h = self:height()
    Style.frame(self.x, self.y, self.width, h, self.title)

    local font = Style.font(12)
    love.graphics.setFont(font)
    local startY = self.y + Style.headerHeight + 4
    for i, item in ipairs(self.items) do
        local itemY = startY + (i - 1) * self.itemHeight
        local hovered = self.hoveredIdx == i and not item.disabled
        if hovered then
            Style.setColor(Style.colors.hover)
            love.graphics.rectangle("fill", self.x + 4, itemY, self.width - 8, self.itemHeight)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("line", self.x + 4, itemY, self.width - 8, self.itemHeight)
        end

        local icon = Icons.get(item.icon)
        if icon then
            love.graphics.setColor(1, 1, 1, item.disabled and 0.35 or 1)
            love.graphics.draw(icon, self.x + 10, math.floor(itemY + (self.itemHeight - icon:getHeight()) / 2))
        end

        if item.disabled then
            Style.setColor(Style.colors.disabled)
        elseif item.color then
            Style.setColor(item.color)
        elseif hovered then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.85, 1)
        end
        local label = item.label .. (item.submenu and "  >" or "")
        love.graphics.print(label, self.x + 32, itemY + 6)

        if item.sublabel then
            Style.setColor(item.disabled and Style.colors.disabled or (item.sublabelColor or Style.colors.gold))
            love.graphics.print(item.sublabel, self.x + self.width - 12 - font:getWidth(item.sublabel), itemY + 6)
        end
    end
    love.graphics.pop()
end

function ContextMenu:activate(item)
    if item.disabled then return end
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
