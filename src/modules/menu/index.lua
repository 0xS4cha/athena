local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local LoadFile = require("src.core.loadFile")
local Renderer = require("src.modules.map.renderer")
local Config = require("src.config.game")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Background = require("src.modules.menu.background")

GM.Menu = {}

GM.Modules:Register("Menu", 90)

local CONFIG_FILE = "menu_config.txt"
local SETTING_KEYS = { "map", "bots", "nations", "difficulty", "name", "server", "fullscreen", "vsync", "background", "battleSpeed", "particles", "advancedEvents" }
local SWITCH_IN = 0.6
local SWITCH_OUT = 0.22
local WIPE_SECONDS = 0.65
local EMBERS = 70

local Screens = {
    root = require("src.modules.menu.screens.root"),
    play = require("src.modules.menu.screens.play"),
    multiplayer = require("src.modules.menu.screens.multiplayer"),
    settings = require("src.modules.menu.screens.settings"),
    keybinds = require("src.modules.menu.screens.keybinds"),
    howto = require("src.modules.menu.screens.howto")
}

function GM.Menu:Initialize()
    self.maps = nil
    self.filtered = {}
    self.search = ""
    self.scroll = 0
    self.selected = 1
    self.previews = {}
    self.previewTime = 0
    self.settings = {
        map = Config.defaultMap,
        bots = Config.defaultBots,
        nations = true,
        difficulty = "medium",
        name = "Player",
        server = "localhost:6789",
        fullscreen = false,
        vsync = false,
        background = true,
        battleSpeed = 2,
        particles = true,
        advancedEvents = false
    }
    self:loadSettings()
    self.background = Background()
    self.embers = Fx.embers(EMBERS)
    self.screen = "root"
    self.previous = nil
    self.direction = 1
    self.switchTime = 0
    self.openTime = 0
    self.focus = nil
    self.editing = nil
    self.dragging = nil
    self.wipe = nil
    self.dim = 0.2
    local flags = GM.Flags or {}
    if not (flags.ci or flags.menu or flags.autostart) then
        self:applyDisplay()
    end
end

function GM.Menu:loadMaps()
    local list = {}
    for _, dir in ipairs(love.filesystem.getDirectoryItems("assets/maps")) do
        local path = "assets/maps/" .. dir .. "/"
        if love.filesystem.getInfo(path .. "manifest.json") then
            local ok, manifest = pcall(LoadFile.Json, LoadFile, path .. "manifest.json")
            if ok and manifest and manifest.map then
                list[#list + 1] = {
                    path = path,
                    name = manifest.name or dir,
                    manifest = manifest,
                    featured = manifest.featured_rank
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.featured ~= nil) ~= (b.featured ~= nil) then return a.featured ~= nil end
        if a.featured and b.featured and a.featured ~= b.featured then return a.featured < b.featured end
        return a.name < b.name
    end)
    self.maps = list
    for k, map in ipairs(list) do
        if map.path == self.settings.map then
            self.selected = k
        end
    end
    self:refreshFilter()
end

function GM.Menu:loadSettings()
    local content = love.filesystem.getInfo(CONFIG_FILE) and love.filesystem.read(CONFIG_FILE)
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+)=(.*)$")
        local default = key and self.settings[key]
        if type(default) == "number" then
            self.settings[key] = tonumber(value) or default
        elseif type(default) == "boolean" then
            self.settings[key] = value == "true"
        elseif type(default) == "string" then
            self.settings[key] = value
        end
    end
end

function GM.Menu:saveSettings()
    local lines = {}
    for _, key in ipairs(SETTING_KEYS) do
        lines[#lines + 1] = key .. "=" .. tostring(self.settings[key])
    end
    love.filesystem.write(CONFIG_FILE, table.concat(lines, "\n") .. "\n")
end

function GM.Menu:applyDisplay()
    local s = self.settings
    if love.window.getFullscreen() ~= s.fullscreen then
        love.window.setFullscreen(s.fullscreen, "desktop")
    end
    love.window.setVSync(s.vsync and 1 or 0)
end

function GM.Menu:setOption(key, value)
    self.settings[key] = value
    if key == "fullscreen" or key == "vsync" then
        self:applyDisplay()
    elseif key == "background" then
        if value and not self.background.game then
            self.background:start(self.settings.battleSpeed)
        elseif not value then
            self.background:stop()
            collectgarbage()
        end
    elseif key == "battleSpeed" then
        self.background:setSpeed(value)
    end
    self:saveSettings()
end

function GM.Menu:nextBattle()
    if not self.settings.background then
        self:setOption("background", true)
        return
    end
    self.background:start(self.settings.battleSpeed)
end

function GM.Menu:Open()
    GM.State = "menu"
    if not self.maps then
        self:loadMaps()
    end
    if self.settings.background and not self.background.game then
        self.background:start(self.settings.battleSpeed)
    end
    local flags = GM.Flags or {}
    local now = love.timer.getTime()
    self.openTime = now
    self.previous = nil
    self:switch(Screens[flags.screen] and flags.screen or "root", 1)
    self.previous = nil
    self.dim = self:dimTarget()
    if flags.menu then
        self.openTime = now - 100
        self.switchTime = now - 100
        self.previewTime = now - 100
        self.background.fade = 0
    else
        self.wipe = { phase = "reveal", start = now }
    end
end

function GM.Menu:dimTarget()
    return self.screen == "root" and 0.12 or 0.62
end

function GM.Menu:active()
    return GM.State == "menu"
end

function GM.Menu:switch(name, direction)
    if not Screens[name] then return end
    self.previous = self.screen ~= name and self.screen or nil
    self.screen = name
    self.direction = direction or 1
    self.switchTime = love.timer.getTime()
    self.focus = nil
    self.editing = nil
    self.dragging = nil
    if Screens[name].enter then
        Screens[name].enter(self)
    end
end

function GM.Menu:stagger(p, k)
    return Fx.outCubic(Fx.clamp(p * 1.7 - (k - 1) * 0.09, 0, 1))
end

function GM.Menu:current()
    return self.maps and self.maps[self.selected]
end

function GM.Menu:preview(map)
    if self.previews[map.path] == nil then
        local image = Renderer.preview(map.path, map.manifest)
        if image then
            image:setFilter("nearest", "nearest")
        end
        self.previews[map.path] = image or false
    end
    return self.previews[map.path] or nil
end

function GM.Menu:revealPreview()
    self.previewTime = love.timer.getTime()
end

function GM.Menu:refreshFilter()
    local query = self.search:lower()
    local list = {}
    local keep = false
    for k, map in ipairs(self.maps or {}) do
        if query == "" or map.name:lower():find(query, 1, true) then
            list[#list + 1] = k
            if k == self.selected then keep = true end
        end
    end
    self.filtered = list
    self.scroll = 0
    if not keep and list[1] then
        self:select(list[1])
    end
    self:ensureVisible()
end

function GM.Menu:select(index)
    if index ~= self.selected then
        self.selected = index
        self:revealPreview()
    end
end

function GM.Menu:ensureVisible()
    local rows = Screens.play.visibleRows()
    local position
    for k, index in ipairs(self.filtered) do
        if index == self.selected then position = k end
    end
    if not position then return end
    if position <= self.scroll then
        self.scroll = position - 1
    elseif position > self.scroll + rows then
        self.scroll = position - rows
    end
end

function GM.Menu:moveSelection(delta)
    local position = 1
    for k, index in ipairs(self.filtered) do
        if index == self.selected then position = k end
    end
    local target = self.filtered[Fx.clamp(position + delta, 1, #self.filtered)]
    if target then
        self:select(target)
        self:ensureVisible()
    end
end

function GM.Menu:start()
    local map = self:current()
    if not map or self.wipe then return end
    self.settings.map = map.path
    self:saveSettings()
    self.launchError = nil
    self.wipe = { phase = "cover", start = love.timer.getTime(), label = map.name }
    local s = self.settings
    GM.Multiplayer:PlaySolo({
        map = s.map,
        bots = s.bots,
        nations = s.nations,
        difficulty = s.difficulty
    }, s.name ~= "" and s.name or "Player")
end

function GM.Menu:Launch(label, action)
    local wipe = self.wipe
    if wipe and wipe.phase == "cover" then
        wipe.action = action
        wipe.label = wipe.label or label
        return
    end
    self.wipe = { phase = "cover", start = love.timer.getTime(), label = label, action = action }
end

function GM.Menu:CancelLaunch(reason)
    self.launchError = reason
    if self.wipe and self.wipe.phase == "cover" then
        self.wipe = { phase = "reveal", start = love.timer.getTime() }
    end
end

function GM.Menu:updateWipe()
    local wipe = self.wipe
    local t = (love.timer.getTime() - wipe.start) / WIPE_SECONDS
    if t < 1 then return end
    if wipe.phase == "cover" then
        if not wipe.held then
            wipe.held = true
            return
        end
        if not wipe.action then return end
        wipe.action()
        self.wipe = { phase = "reveal", start = love.timer.getTime() }
    else
        self.wipe = nil
    end
end

function GM.Menu:drawWipe()
    local wipe = self.wipe
    local t = Fx.clamp((love.timer.getTime() - wipe.start) / WIPE_SECONDS, 0, 1)
    love.graphics.push("all")
    love.graphics.origin()
    Fx.wipe(t, wipe.phase == "cover")
    if wipe.phase == "cover" and t >= 1 then
        local W, H = love.graphics.getDimensions()
        local font = Style.font(22)
        local text = "DEPLOYING TO " .. string.upper(wipe.label or "")
        love.graphics.setFont(font)
        local x = math.floor((W - font:getWidth(text)) / 2)
        local y = math.floor(H / 2 - font:getHeight())
        UI.alpha = 1
        UI.shadowText(text, x, y, 22, UI.colors.gold)
        local u = UI.unit
        local frame = math.floor(love.timer.getTime() * 8)
        for k = 0, 5 do
            UI.color(UI.colors.gold, (frame - k) % 6 == 0 and 1 or 0.25)
            love.graphics.rectangle("fill", math.floor(W / 2) - 15 * u + k * 5 * u, y + font:getHeight() + 16, u * 3, u * 3)
        end
    end
    love.graphics.pop()
end

function GM.Menu:elements()
    return Screens[self.screen].build(self)
end

local function find(elements, id)
    for _, element in ipairs(elements) do
        if element.id == id then return element end
    end
end

function GM.Menu:drawBackdrop(W, H)
    love.graphics.setColor(0.03, 0.04, 0.07, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if self.background.game then
        self.background:draw()
    else
        local u = UI.unit * 2
        local time = love.timer.getTime()
        for y = 0, H, u * 8 do
            for x = 0, W, u * 8 do
                local wave = math.sin(x * 0.01 + y * 0.013 + time * 0.6)
                love.graphics.setColor(0.2, 0.45, 0.8, 0.04 + 0.04 * wave)
                love.graphics.rectangle("fill", x, y, u, u)
            end
        end
    end
    local ink = UI.colors.ink
    love.graphics.setColor(ink[1], ink[2], ink[3], self.dim)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Fx.gradient(0, 0, math.floor(W * 0.55), H, ink, 0.85)
    Fx.gradient(0, math.floor(H * 0.7), W, math.ceil(H * 0.3), ink, 0.7, "bottom")
    Fx.gradient(0, 0, W, 90, ink, 0.6, "top")
    Fx.vignette(0.9)
    Fx.scanlines(0.12)
    if self.settings.particles then
        Fx.drawEmbers(self.embers, 1)
    end
end

function GM.Menu:drawScreen(name, p, direction)
    love.graphics.push()
    love.graphics.translate(math.floor((1 - Fx.outCubic(p)) * 50 * direction), 0)
    Screens[name].draw(self, Screens[name].build(self), p)
    love.graphics.pop()
    UI.alpha = 1
end

function GM.Menu:Draw()
    if self:active() then
        local W, H = love.graphics.getDimensions()
        love.graphics.push("all")
        self:drawBackdrop(W, H)
        local now = love.timer.getTime()
        local delay = 0
        if self.previous then
            local out = 1 - Fx.clamp((now - self.switchTime) / SWITCH_OUT, 0, 1)
            if out > 0 then
                self:drawScreen(self.previous, out, -self.direction)
            end
            delay = SWITCH_OUT * 0.5
        end
        local p = Fx.clamp((now - self.switchTime - delay) / SWITCH_IN, 0, 1)
        self:drawScreen(self.screen, p, self.direction)
        love.graphics.pop()
    end
    if self.wipe then
        self:drawWipe()
    end
end

function GM.Menu:Think(dt)
    if self.wipe then
        self:updateWipe()
    end
    if not self:active() then return end
    local now = love.timer.getTime()
    if self.previous and now - self.switchTime > SWITCH_OUT then
        self.previous = nil
    end
    self.dim = Fx.approach(self.dim, self:dimTarget(), 6, dt)
    local screen = Screens[self.screen]
    if screen.update then
        screen.update(self, dt)
    end
    if self.settings.background then
        self.background:update(dt, self.screen ~= "play" and not self.wipe)
    end
    if self.settings.particles then
        Fx.updateEmbers(self.embers, dt)
    end

    local mx, my = love.mouse.getPosition()
    local elements = self:elements()
    if mx ~= self.mouseX or my ~= self.mouseY then
        self.mouseX, self.mouseY = mx, my
        local hovered
        for _, element in ipairs(elements) do
            if (element.press or element.drag) and UI.hotspot(element, mx, my) then
                hovered = element.id
            end
        end
        self.focus = hovered
    end
    if self.dragging then
        local element = find(elements, self.dragging)
        if element and love.mouse.isDown(1) then
            element.drag(self, mx, my)
        else
            self.dragging = nil
            self:saveSettings()
        end
    end
end

function GM.Menu:MousePressed(x, y, button)
    if not self:active() or self.wipe then return end
    local screen = Screens[self.screen]
    if button == 4 and screen.back then
        screen.back(self)
        return
    end
    if button ~= 1 then return end
    for _, element in ipairs(self:elements()) do
        if UI.hotspot(element, x, y) then
            self.focus = element.id
            if element.drag then
                self.dragging = element.id
                element.drag(self, x, y)
            end
            if element.press then
                element.press(self, x, y)
                self:saveSettings()
            end
            return
        end
    end
end

function GM.Menu:WheelMoved(_, y)
    if not self:active() or self.wipe then return end
    local screen = Screens[self.screen]
    if screen.wheel then
        screen.wheel(self, y)
    end
end

function GM.Menu:TextInput(text)
    if not self:active() or self.wipe or not self.editing then return end
    local element = find(self:elements(), self.editing)
    if element and element.text then
        element.text(self, text)
    end
end

function GM.Menu:KeyPressed(key)
    if not self:active() or self.wipe then return end
    local screen = Screens[self.screen]
    if screen.capture and screen.capture(self, key) then
        return
    end
    if key == "escape" then
        if screen.back then
            screen.back(self)
        end
        return
    end
    local elements = self:elements()
    if key == "backspace" and self.editing then
        local element = find(elements, self.editing)
        if element and element.text then
            element.text(self, nil)
        end
        return
    end
    if screen.keyPressed and screen.keyPressed(self, key) then
        return
    end
    local focused = self.focus and find(elements, self.focus)
    if key == "up" or key == "down" then
        if focused and focused[key] then
            focused[key](self)
            return
        end
        local nav = {}
        local position
        for _, element in ipairs(elements) do
            if element.nav ~= false and (element.press or element.drag or element.left) then
                nav[#nav + 1] = element
                if element == focused then position = #nav end
            end
        end
        if #nav == 0 then return end
        if position then
            position = (position - 1 + (key == "down" and 1 or -1)) % #nav + 1
        else
            position = 1
        end
        self.focus = nav[position].id
        if nav[position].text then
            self.editing = nav[position].id
        end
    elseif (key == "left" or key == "right") and focused and focused[key] then
        focused[key](self)
        self:saveSettings()
    elseif (key == "return" or key == "kpenter") and focused and focused.press then
        focused.press(self)
        self:saveSettings()
    elseif key == "tab" then
        local fields = {}
        for _, element in ipairs(elements) do
            if element.text then fields[#fields + 1] = element.id end
        end
        for k, id in ipairs(fields) do
            if id == self.editing then
                self.editing = fields[k % #fields + 1]
                return
            end
        end
        self.editing = fields[1]
    end
end

return GM.Menu
