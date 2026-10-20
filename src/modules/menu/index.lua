local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local LoadFile = require("src.core.loadFile")
local Renderer = require("src.modules.map.renderer")
local Format = require("src.core.format")
local Config = require("src.config.game")

GM.Menu = {}

GM.Modules:Register("Menu", 90)

local CONFIG_FILE = "menu_config.txt"
local ROW = 26
local DIFFICULTIES = { "easy", "medium", "hard" }
local MAX_BOTS = 400

function GM.Menu:Initialize()
    self.maps = nil
    self.scroll = 0
    self.selected = 1
    self.previews = {}
    self.settings = { map = Config.defaultMap, bots = Config.defaultBots, nations = true, difficulty = "medium", name = "Player" }
    self.slider = nil
    self.loading = nil
    self:loadSettings()
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
end

function GM.Menu:loadSettings()
    local content = love.filesystem.getInfo(CONFIG_FILE) and love.filesystem.read(CONFIG_FILE)
    if not content then return end
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+)=(.*)$")
        if key == "bots" then
            self.settings.bots = tonumber(value) or self.settings.bots
        elseif key == "nations" then
            self.settings.nations = value == "true"
        elseif key == "map" or key == "difficulty" or key == "name" then
            self.settings[key] = value
        end
    end
end

function GM.Menu:saveSettings()
    local s = self.settings
    love.filesystem.write(CONFIG_FILE, string.format("map=%s\nbots=%d\nnations=%s\ndifficulty=%s\nname=%s\n", s.map, s.bots, tostring(s.nations), s.difficulty, s.name))
end

function GM.Menu:Open()
    GM.State = "menu"
    if not self.maps then
        self:loadMaps()
    end
end

function GM.Menu:active()
    return GM.State == "menu"
end

function GM.Menu:layout()
    local W, H = love.graphics.getDimensions()
    local listW = math.min(320, W * 0.3)
    local top = 110
    local list = { x = 40, y = top, w = listW, h = H - top - 40 }
    local panel = { x = list.x + listW + 30, y = top, w = W - listW - 110, h = H - top - 40 }
    return list, panel
end

function GM.Menu:visibleRows()
    local list = self:layout()
    return math.floor((list.h - Style.headerHeight - 10) / ROW)
end

function GM.Menu:current()
    return self.maps and self.maps[self.selected]
end

function GM.Menu:preview(map)
    if self.previews[map.path] == nil then
        self.previews[map.path] = Renderer.preview(map.path, map.manifest) or false
    end
    return self.previews[map.path] or nil
end

function GM.Menu:controls(panel)
    local x = panel.x + 20
    local w = panel.w - 40
    local y = panel.y + panel.h - 250
    return {
        name = { x = x, y = y, w = w, h = 30 },
        bots = { x = x, y = y + 70, w = w },
        nations = { x = x, y = y + 100, w = 180, h = 28 },
        difficulty = { x = x + 200, y = y + 100, w = w - 200, h = 28 },
        start = { x = x, y = y + 150, w = w, h = 46 }
    }
end

function GM.Menu:Draw()
    if not self:active() then return end
    local W, H = love.graphics.getDimensions()
    love.graphics.push("all")
    love.graphics.setColor(0.05, 0.06, 0.09, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    if self.loading then
        local font = Style.font(28)
        love.graphics.setFont(font)
        Style.setColor(Style.colors.text)
        local text = "Loading " .. self.loading.label .. "..."
        love.graphics.print(text, (W - font:getWidth(text)) / 2, H / 2 - 20)
        love.graphics.pop()
        return
    end

    local title = Style.font(40)
    love.graphics.setFont(title)
    Style.setColor(Style.colors.text)
    love.graphics.print("ATHENA", 40, 26)
    love.graphics.setFont(Style.font(14))
    Style.setColor(Style.colors.muted)
    love.graphics.print("Conquer the world, one tile at a time.", 44, 76)

    local list, panel = self:layout()
    local mx, my = love.mouse.getPosition()
    Style.frame(list.x, list.y, list.w, list.h, string.format("MAPS (%d)", #self.maps))
    local font = Style.font(13)
    love.graphics.setFont(font)
    love.graphics.setScissor(list.x, list.y + Style.headerHeight + 4, list.w, list.h - Style.headerHeight - 8)
    for k = 1, self:visibleRows() do
        local index = k + self.scroll
        local map = self.maps[index]
        if not map then break end
        local ry = list.y + Style.headerHeight + 6 + (k - 1) * ROW
        if index == self.selected then
            Style.setColor(Style.colors.hover)
            love.graphics.rectangle("fill", list.x + 4, ry, list.w - 8, ROW - 2)
        elseif Style.inside(mx, my, list.x + 4, ry, list.w - 8, ROW - 2) then
            Style.setColor(Style.colors.hover, 0.3)
            love.graphics.rectangle("fill", list.x + 4, ry, list.w - 8, ROW - 2)
        end
        Style.setColor(map.featured and Style.colors.gold or Style.colors.text)
        love.graphics.print(map.name, list.x + 14, ry + 5)
    end
    love.graphics.setScissor()

    local map = self:current()
    Style.frame(panel.x, panel.y, panel.w, panel.h, map and string.upper(map.name) or "")
    if map then
        local image = self:preview(map)
        local controls = self:controls(panel)
        local areaW = panel.w - 40
        local areaH = controls.name.y - panel.y - Style.headerHeight - 70
        if image then
            local scale = math.min(areaW / image:getWidth(), areaH / image:getHeight())
            local iw, ih = image:getWidth() * scale, image:getHeight() * scale
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, panel.x + (panel.w - iw) / 2, panel.y + Style.headerHeight + 14, 0, scale, scale)
        end
        local m = map.manifest
        local info = string.format("%d x %d  |  %s land tiles  |  %d nations", m.map.width, m.map.height, Format.number(m.map.num_land_tiles or 0), #(m.nations or {}))
        love.graphics.setFont(Style.font(13))
        Style.setColor(Style.colors.muted)
        love.graphics.print(info, panel.x + 20, controls.name.y - 44)

        local c = controls
        love.graphics.setFont(Style.font(12))
        Style.setColor(Style.colors.text)
        love.graphics.print("Player name", c.name.x, c.name.y - 18)
        Style.setColor(Style.colors.header)
        love.graphics.rectangle("fill", c.name.x, c.name.y, c.name.w, c.name.h)
        Style.setColor(Style.colors.accent)
        love.graphics.rectangle("line", c.name.x, c.name.y, c.name.w, c.name.h)
        Style.setColor(Style.colors.text)
        love.graphics.setFont(Style.font(14))
        local cursor = (love.timer.getTime() % 1 < 0.5) and "_" or ""
        love.graphics.print(self.settings.name .. cursor, c.name.x + 10, c.name.y + 6)

        love.graphics.setFont(Style.font(12))
        Style.setColor(Style.colors.text)
        love.graphics.print("Bots", c.bots.x, c.bots.y - 20)
        local botsText = tostring(self.settings.bots)
        love.graphics.print(botsText, c.bots.x + c.bots.w - font:getWidth(botsText), c.bots.y - 20)
        Style.slider(c.bots.x, c.bots.y, c.bots.w, self.settings.bots / MAX_BOTS, Style.colors.troops, self.slider ~= nil)

        Style.button(c.nations.x, c.nations.y, c.nations.w, c.nations.h, self.settings.nations and "Nations: On" or "Nations: Off", { active = self.settings.nations })
        local dw = c.difficulty.w / #DIFFICULTIES
        for k, d in ipairs(DIFFICULTIES) do
            local label = d:sub(1, 1):upper() .. d:sub(2)
            Style.button(c.difficulty.x + (k - 1) * dw, c.difficulty.y, dw - 6, c.difficulty.h, label, { active = self.settings.difficulty == d })
        end
        Style.button(c.start.x, c.start.y, c.start.w, c.start.h, "START GAME", { size = 18, color = { 0.15, 0.55, 0.35, 0.9 } })
    end
    love.graphics.pop()
end

function GM.Menu:start()
    local map = self:current()
    if not map then return end
    self.settings.map = map.path
    self:saveSettings()
    self.loading = { label = map.name, frames = 0 }
end

function GM.Menu:Think()
    if not self:active() then return end
    if self.loading then
        self.loading.frames = self.loading.frames + 1
        if self.loading.frames >= 2 then
            self.loading = nil
            local s = self.settings
            GM.Session:Start({
                map = s.map,
                bots = s.bots,
                nations = s.nations,
                difficulty = s.difficulty,
                playerName = s.name ~= "" and s.name or "Player",
                seed = os.time()
            })
        end
        return
    end
    if self.slider then
        if love.mouse.isDown(1) then
            local mx = love.mouse.getPosition()
            local pct = math.max(0, math.min(1, (mx - self.slider.x) / self.slider.w))
            self.settings.bots = math.floor(pct * MAX_BOTS / 5 + 0.5) * 5
        else
            self.slider = nil
        end
    end
end

function GM.Menu:MousePressed(x, y, button)
    if not self:active() or self.loading or button ~= 1 then return end
    local list, panel = self:layout()
    if Style.inside(x, y, list.x, list.y + Style.headerHeight, list.w, list.h - Style.headerHeight) then
        local k = math.floor((y - list.y - Style.headerHeight - 6) / ROW) + 1
        local index = k + self.scroll
        if self.maps[index] then
            if index == self.selected and self.lastClick and love.timer.getTime() - self.lastClick < 0.4 then
                self:start()
                return
            end
            self.selected = index
            self.lastClick = love.timer.getTime()
        end
        return
    end
    local c = self:controls(panel)
    if Style.sliderHit(x, y, c.bots.x, c.bots.y, c.bots.w) then
        self.slider = { x = c.bots.x, w = c.bots.w }
    elseif Style.inside(x, y, c.nations.x, c.nations.y, c.nations.w, c.nations.h) then
        self.settings.nations = not self.settings.nations
    elseif Style.inside(x, y, c.start.x, c.start.y, c.start.w, c.start.h) then
        self:start()
    else
        local dw = c.difficulty.w / #DIFFICULTIES
        for k, d in ipairs(DIFFICULTIES) do
            if Style.inside(x, y, c.difficulty.x + (k - 1) * dw, c.difficulty.y, dw - 6, c.difficulty.h) then
                self.settings.difficulty = d
            end
        end
    end
end

function GM.Menu:WheelMoved(_, y)
    if not self:active() then return end
    local maxScroll = math.max(0, #self.maps - self:visibleRows())
    self.scroll = math.max(0, math.min(maxScroll, self.scroll - y * 3))
end

function GM.Menu:TextInput(text)
    if not self:active() or self.loading then return end
    if #self.settings.name < 24 and text:match("^[%w%s%-_%.']$") then
        self.settings.name = self.settings.name .. text
    end
end

function GM.Menu:KeyPressed(key)
    if not self:active() or self.loading then return end
    if key == "backspace" then
        self.settings.name = self.settings.name:sub(1, -2)
    elseif key == "return" or key == "kpenter" then
        self:start()
    elseif key == "up" then
        self.selected = math.max(1, self.selected - 1)
    elseif key == "down" then
        self.selected = math.min(#self.maps, self.selected + 1)
    end
    if key == "up" or key == "down" then
        local rows = self:visibleRows()
        if self.selected <= self.scroll then
            self.scroll = self.selected - 1
        elseif self.selected > self.scroll + rows then
            self.scroll = self.selected - rows
        end
    end
end

return GM.Menu
