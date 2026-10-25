local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")
local Palette = require("src.modules.player.palette")
local ChatLog = require("src.modules.hud.chatlog")

local Multiplayer = { id = "multiplayer" }

local ROW = 30
local CONTROLS_H = 300
local MAX_BOTS = 400
local SYNC_DELAY = 0.25
local CHAT_W = 380
local CHAT_INPUT_H = 38
local DIFFICULTIES = { "easy", "medium", "hard" }
local DIFFICULTY_LABELS = { "Easy", "Medium", "Hard" }
local FIELDS = {
    name = { limit = 24, pattern = "^[%w%s%-_%.']$" },
    server = { limit = 64, pattern = "^[%w%.%-:]$" },
    flag = { limit = 24, pattern = "^[%w%-]$" }
}

local function net()
    return GM.Multiplayer
end

local function phase()
    local mp = net()
    if mp.state ~= "online" then return "connect" end
    if mp.room then return "lobby" end
    return "browse"
end

local function difficultyIndex(difficulty)
    for k, d in ipairs(DIFFICULTIES) do
        if difficulty == d then return k end
    end
    return 2
end

local function mapByPath(menu, path)
    for k, map in ipairs(menu.maps or {}) do
        if map.path == path then return map, k end
    end
end

local function settingsKey(s)
    return string.format("%s|%d|%s|%s", tostring(s.map), s.bots or 0, tostring(s.nations), tostring(s.difficulty))
end

local function hostSettings(menu)
    local map = menu:current()
    local s = menu.settings
    return { map = map and map.path, bots = s.bots, nations = s.nations, difficulty = s.difficulty }
end

local function roomSettings(menu)
    local mp = net()
    if mp:IsHost() then
        return hostSettings(menu)
    end
    return mp.room and mp.room.settings or {}
end

local function fieldHandler(menu, field)
    local rule = FIELDS[field]
    return function(_, text)
        local value = menu.settings[field]
        if text then
            if #value < rule.limit and text:match(rule.pattern) then
                menu.settings[field] = value .. text
            end
        else
            menu.settings[field] = value:sub(1, -2)
        end
    end
end

local function passwordHandler(menu)
    return function(_, text)
        local value = menu.password or ""
        if text then
            if #value < 24 and text:match("^[%w%-_%.!@#%$%%%^&%*]$") then
                menu.password = value .. text
            end
        else
            menu.password = value:sub(1, -2)
        end
    end
end

local function colorFor(player, slot)
    return player.color and Palette.choices[player.color] or Palette.color(slot)
end

local function chipLabel(mp, player)
    local ping = mp.pings[player.id]
    return player.name .. (player.id == mp.id and " (you)" or "") .. (ping and string.format("  %dms", ping) or "")
end

local function chipLayout(mp, x, y)
    local u = UI.unit
    local list = {}
    local font = Style.font(11)
    for k, player in ipairs(mp.room and mp.room.players or {}) do
        local label = chipLabel(mp, player)
        local icon = player.id == mp.room.host and "Trophy.png" or (player.ready and "Unlocked.png" or "Locked.png")
        local h = font:getHeight() + u * 3
        local w = font:getWidth(label) + u * 6 + (h - u * 4) + u * 2
        list[#list + 1] = { player = player, slot = k, label = label, icon = icon, x = x, y = y, w = w, h = h }
        x = x + w + (player.flag and 18 or 0) + u * 3
    end
    return list
end

local function cycleColor(menu)
    local mp = net()
    local taken = {}
    for _, player in ipairs(mp.room.players or {}) do
        if player.id ~= mp.id and player.color then taken[player.color] = true end
    end
    local color = menu.settings.color or 0
    for _ = 1, #Palette.choices + 1 do
        color = (color + 1) % (#Palette.choices + 1)
        if color == 0 or not taken[color] then break end
    end
    menu.settings.color = color
    menu:saveSettings()
    mp:SendProfile()
end

local function clickPlayers(menu, x, y, mx)
    local mp = net()
    for _, chip in ipairs(chipLayout(mp, x, y)) do
        if mx >= chip.x and mx < chip.x + chip.w then
            if chip.player.id == mp.id then
                cycleColor(menu)
            elseif mp:IsHost() then
                mp:Kick(chip.player.id)
            end
            return
        end
    end
end

local function toggleReady()
    local me = net():Me()
    if me then net():SetReady(not me.ready) end
end

local function searchHandler(menu)
    return function(_, text)
        if text then
            if #menu.search < 32 and text:match("^[%w%s%-']$") then
                menu.search = menu.search .. text
                menu:refreshFilter()
            end
        else
            menu.search = menu.search:sub(1, -2)
            menu:refreshFilter()
        end
    end
end

local function chatArea(l)
    local area = l.preview
    local w = math.min(CHAT_W, math.floor(area.w * 0.45))
    return { x = area.x + area.w - w, y = area.y, w = w, h = area.h - UI.unit * 2 }
end

local function lobbyLayout(l)
    local area = chatArea(l)
    local preview = { x = l.preview.x, y = l.preview.y, w = area.x - l.preview.x - 18, h = l.preview.h }
    return { M = l.M, list = l.list, panel = l.panel, rows = l.rows, preview = preview }
end

local function sendChat(menu)
    local text = menu.chatText or ""
    menu.chatText = ""
    if text:match("%S") then
        net():SendChat(text)
    end
end

local function connect(menu)
    local mp = net()
    if mp.state == "connecting" then
        mp:Disconnect()
        return
    end
    local name = menu.settings.name ~= "" and menu.settings.name or "Player"
    mp:Connect(menu.settings.server, name)
    menu:saveSettings()
end

local function selectedRoom(menu)
    return net().rooms[menu.roomIndex or 1]
end

local function joinSelected(menu)
    local room = selectedRoom(menu)
    if room then
        net():JoinRoom(room.id, menu.password)
    end
end

local function createRoom(menu)
    local settings = hostSettings(menu)
    settings.name = (menu.settings.name ~= "" and menu.settings.name or "Player") .. "'s game"
    settings.password = menu.password
    menu.hostRoom = nil
    net():CreateRoom(settings)
end

local function moveRoom(menu, delta)
    local count = #net().rooms
    if count == 0 then return end
    menu.roomIndex = Fx.clamp((menu.roomIndex or 1) + delta, 1, count)
end

local function editable(menu, fn)
    return function(...)
        if net():IsHost() then fn(...) end
    end
end

function Multiplayer.enter(menu)
    menu.editing = nil
    menu.roomIndex = menu.roomIndex or 1
    if phase() == "connect" then
        menu.editing = "name"
    end
    menu:revealPreview()
end

function Multiplayer.update(menu)
    local mp = net()
    local count = #mp.rooms
    if (menu.roomIndex or 1) > count then
        menu.roomIndex = math.max(1, count)
    end
    if phase() ~= "lobby" or not mp:IsHost() or mp.room.state ~= "lobby" then return end
    if menu.hostRoom ~= mp.room.id then
        menu.hostRoom = mp.room.id
        local s = mp.room.settings
        local _, index = mapByPath(menu, s.map)
        if index then
            menu:select(index)
            menu:ensureVisible()
        end
        menu.settings.bots = s.bots
        menu.settings.nations = s.nations
        menu.settings.difficulty = s.difficulty
        menu.syncedKey = settingsKey(s)
    end
    local settings = hostSettings(menu)
    local key = settingsKey(settings)
    local now = love.timer.getTime()
    if key ~= menu.syncedKey and now - (menu.syncTime or 0) > SYNC_DELAY then
        menu.syncedKey = key
        menu.syncTime = now
        mp:Configure(settings)
    end
end

function Multiplayer.build(menu)
    local l = Play.layout()
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - CONTROLS_H + 12
    local half = math.floor((cw - 24) / 2)
    local elements = {
        { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() Multiplayer.back(menu) end }
    }
    local function add(element) elements[#elements + 1] = element end
    local current = phase()

    if current == "connect" then
        add({
            id = "lan", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
            press = function(_, _, my) Multiplayer.clickLan(menu, my) end
        })
        add({ id = "name", x = cx, y = cy + 22, w = half, h = 42, press = function() menu.editing = "name" end, text = fieldHandler(menu, "name") })
        add({ id = "server", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 42, press = function() menu.editing = "server" end, text = fieldHandler(menu, "server") })
        local count = #Palette.choices + 1
        add({
            id = "color", x = cx, y = cy + 106, w = half, h = 34,
            press = function(_, mx)
                if not mx then
                    menu.settings.color = (menu.settings.color + 1) % count
                else
                    menu.settings.color = Fx.clamp(math.floor((mx - cx) / (half / count)), 0, count - 1)
                end
                menu:saveSettings()
            end,
            left = function() menu.settings.color = (menu.settings.color - 1) % count end,
            right = function() menu.settings.color = (menu.settings.color + 1) % count end
        })
        add({ id = "flag", x = cx + half + 24, y = cy + 106, w = cw - half - 24, h = 34, press = function() menu.editing = "flag" end, text = fieldHandler(menu, "flag") })
        add({ id = "connect", x = cx, y = cy + 222, w = cw, h = 58, press = function() connect(menu) end })
    elseif current == "browse" then
        add({
            id = "rooms", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
            press = function(_, _, my) Multiplayer.clickRoom(menu, my) end,
            up = function() moveRoom(menu, -1) end, down = function() moveRoom(menu, 1) end
        })
        add({ id = "password", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 40, press = function() menu.editing = "password" end, text = passwordHandler(menu) })
        add({ id = "refresh", x = cx, y = cy + 90, w = half, h = 44, press = function() net():ListRooms() end })
        add({ id = "disconnect", x = cx + half + 24, y = cy + 90, w = cw - half - 24, h = 44, press = function() net():Disconnect() end })
        if net():CanRejoin() then
            add({ id = "create", x = cx, y = cy + 156, w = half, h = 50, press = function() createRoom(menu) end })
            add({ id = "rejoin", x = cx + half + 24, y = cy + 156, w = cw - half - 24, h = 50, press = function() net():Rejoin() end })
        else
            add({ id = "create", x = cx, y = cy + 156, w = cw, h = 50, press = function() createRoom(menu) end })
        end
        add({ id = "join", x = cx, y = cy + 222, w = cw, h = 58, press = function() joinSelected(menu) end })
    else
        local host = net():IsHost()
        local s = menu.settings
        if host then
            local function moveSelection(delta)
                return function() menu:moveSelection(delta) end
            end
            add({
                id = "search", x = l.list.x + 12, y = l.list.y + 14, w = l.list.w - 24, h = 40,
                press = function() menu.editing = "search" end,
                text = searchHandler(menu), up = moveSelection(-1), down = moveSelection(1)
            })
            add({
                id = "list", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
                press = function(_, _, my) menu:select(menu.filtered[math.floor((my - l.rows.y) / ROW) + 1 + menu.scroll] or menu.selected) end,
                up = moveSelection(-1), down = moveSelection(1)
            })
        end
        add({
            id = "nations", x = cx, y = cy + 90, w = half, h = 40,
            press = editable(menu, function() s.nations = not s.nations end),
            left = editable(menu, function() s.nations = false end),
            right = editable(menu, function() s.nations = true end)
        })
        add({
            id = "difficulty", x = cx + half + 24, y = cy + 90, w = cw - half - 24, h = 40,
            press = editable(menu, function(_, mx)
                local dx, dw = cx + half + 24, cw - half - 24
                if not mx then
                    s.difficulty = DIFFICULTIES[difficultyIndex(s.difficulty) % #DIFFICULTIES + 1]
                    return
                end
                s.difficulty = DIFFICULTIES[Fx.clamp(math.floor((mx - dx) / (dw / #DIFFICULTIES)) + 1, 1, #DIFFICULTIES)]
            end),
            left = editable(menu, function() s.difficulty = DIFFICULTIES[math.max(1, difficultyIndex(s.difficulty) - 1)] end),
            right = editable(menu, function() s.difficulty = DIFFICULTIES[math.min(#DIFFICULTIES, difficultyIndex(s.difficulty) + 1)] end)
        })
        add({
            id = "bots", x = cx, y = cy + 166, w = cw, h = 24,
            drag = host and function(_, mx)
                s.bots = math.floor(Fx.clamp((mx - cx) / cw, 0, 1) * MAX_BOTS / 5 + 0.5) * 5
            end or nil,
            left = editable(menu, function() s.bots = math.max(0, s.bots - 10) end),
            right = editable(menu, function() s.bots = math.min(MAX_BOTS, s.bots + 10) end)
        })
        add({ id = "players", x = cx, y = cy + 24, w = cw, h = 24, nav = false, press = function(_, mx) clickPlayers(menu, cx, cy + 24, mx) end })
        local chat = chatArea(l)
        add({
            id = "chat", x = chat.x, y = chat.y + chat.h - CHAT_INPUT_H, w = chat.w, h = CHAT_INPUT_H, nav = false,
            press = function() menu.editing = "chat" end,
            text = function(_, text) menu.chatText = ChatLog.edit(menu.chatText or "", text) end
        })
        local third = math.floor((cw - 24) / 3)
        add({ id = "leave", x = cx, y = cy + 222, w = third, h = 58, press = function() net():LeaveRoom() end })
        add({ id = "start", x = cx + third + 24, y = cy + 222, w = cw - third - 24, h = 58, press = function()
            if net():IsHost() then net():StartGame() else toggleReady() end
        end })
    end
    return elements
end

function Multiplayer.clickLan(menu, my)
    local l = Play.layout()
    local game = net():LanGames()[math.floor((my - l.rows.y) / ROW) + 1]
    if not game then return end
    menu:saveSettings()
    net():JoinLan(game, menu.settings.name ~= "" and menu.settings.name or "Player", menu.password)
end

function Multiplayer.clickRoom(menu, my)
    local l = Play.layout()
    local k = math.floor((my - l.rows.y) / ROW) + 1
    if not net().rooms[k] then return end
    local now = love.timer.getTime()
    if k == menu.roomIndex and menu.lastClick and now - menu.lastClick < 0.4 then
        joinSelected(menu)
        return
    end
    menu.roomIndex = k
    menu.lastClick = now
end

local function find(elements, id)
    for _, element in ipairs(elements) do
        if element.id == id then return element end
    end
end

local function drawRows(menu, l, e, rows, selected)
    local u = UI.unit
    local mx, my = love.mouse.getPosition()
    local area = l.rows
    love.graphics.setScissor(area.x - u * 4, area.y, area.w + u * 8, area.h)
    for k, row in ipairs(rows) do
        local ry = area.y + (k - 1) * ROW
        if ry > area.y + area.h then break end
        local rowIn = Fx.clamp(e * 2 - k * 0.04, 0, 1)
        local isSelected = k == selected
        local hovered = UI.hotspot({ x = area.x, y = ry, w = area.w, h = ROW - 2 }, mx, my)
        local hot = UI.ease("mprow:" .. k, isSelected and 1 or (hovered and 0.45 or 0), 18)
        UI.alpha = rowIn * e
        if hot > 0.01 then
            UI.color(isSelected and UI.colors.hover or UI.colors.raised, 0.25 + 0.6 * hot)
            UI.block(area.x, ry, area.w, ROW - 3, u)
            if isSelected then
                UI.color(UI.colors.gold)
                love.graphics.rectangle("fill", area.x, ry + u, u, ROW - 3 - 2 * u)
            end
        end
        local tx = area.x + u * 4 + math.floor(hot * 2) * u
        if row.icon then
            UI.icon(row.icon, tx, ry + 6, 14)
            tx = tx + 20
        end
        UI.text(row.label, tx, ry + 4, 13, row.color or UI.colors.text, isSelected and 1 or 0.85)
        if row.detail then
            local font = Style.font(11)
            UI.text(row.detail, area.x + area.w - u * 4 - font:getWidth(row.detail), ry + 6, 11, UI.colors.muted)
        end
    end
    love.graphics.setScissor()
    UI.alpha = e
end

local function drawStatus(menu, x, y)
    local mp = net()
    if mp.state == "connecting" then
        local dots = string.rep(".", math.floor(love.timer.getTime() * 3) % 4)
        UI.text("Connecting to " .. tostring(mp.address) .. dots, x, y, 13, UI.colors.troops)
    elseif mp.error then
        UI.text(mp.error, x, y, 13, UI.colors.bad)
    end
end

local function drawConnect(menu, elements, l)
    local s = menu.settings
    local area = l.preview
    UI.shadowText("PLAY WITH FRIENDS", area.x + 12, area.y + 12, 22, UI.colors.gold)
    local lines = {
        "Join a server, create a room and pick the battlefield.",
        "Games hosted on your network appear on the left: click one to join.",
        "Host a LAN game from New Game, or a server with  love . --server  (UDP 6789)."
    }
    for k, line in ipairs(lines) do
        UI.text(line, area.x + 12, area.y + 40 + k * 26, 13, UI.colors.muted)
    end

    local name = find(elements, "name")
    UI.text("COMMANDER", name.x, name.y - 22, 11, UI.colors.muted)
    UI.field("name", name.x, name.y, name.w, name.h, s.name, { editing = menu.editing == "name", hot = menu.focus == "name", icon = "Pencil.png", placeholder = "Player" })
    local server = find(elements, "server")
    UI.text("SERVER", server.x, server.y - 22, 11, UI.colors.muted)
    UI.field("server", server.x, server.y, server.w, server.h, s.server, { editing = menu.editing == "server", hot = menu.focus == "server", icon = "Monitor.png", placeholder = "localhost:6789" })

    local u = UI.unit
    local color = find(elements, "color")
    UI.text("COLOR", color.x, color.y - 22, 11, UI.colors.muted)
    local count = #Palette.choices + 1
    local cell = color.w / count
    for k = 0, count - 1 do
        local x0 = math.floor(color.x + k * cell)
        local x1 = math.floor(color.x + (k + 1) * cell) - u
        local selected = (s.color or 0) == k
        UI.color(selected and UI.colors.gold or UI.colors.ink, selected and 1 or 0.85)
        UI.block(x0, color.y, x1 - x0, color.h, u)
        if k == 0 then
            UI.color(UI.colors.raised)
            UI.block(x0 + u, color.y + u, x1 - x0 - 2 * u, color.h - 2 * u, u)
            UI.text("A", x0 + math.floor((x1 - x0) / 2) - 3, color.y + 8, 11, UI.colors.muted)
        else
            UI.color(Palette.choices[k])
            UI.block(x0 + u, color.y + u, x1 - x0 - 2 * u, color.h - 2 * u, u)
        end
    end
    local flag = find(elements, "flag")
    UI.text("FLAG (COUNTRY CODE)", flag.x, flag.y - 22, 11, UI.colors.muted)
    UI.field("flag", flag.x, flag.y, flag.w, flag.h, s.flag, { editing = menu.editing == "flag", hot = menu.focus == "flag", icon = "Pencil.png", placeholder = "fr, us, jp...", size = 13 })
    if s.flag ~= "" then
        Style.flag(s.flag, flag.x + flag.w - 34, flag.y + 5, 24)
    end
    drawStatus(menu, name.x, name.y + 134)

    local button = find(elements, "connect")
    local connecting = net().state == "connecting"
    UI.button("connect", button.x, button.y, button.w, button.h, connecting and "CANCEL" or "CONNECT", {
        hot = menu.focus == "connect", primary = not connecting, size = 20, icon = "Team.png", hint = "ENTER"
    })
end

local function drawBrowse(menu, elements, l, e)
    local mp = net()
    local room = selectedRoom(menu)
    local map = room and mapByPath(menu, room.map)
    if map then
        Play.drawPreview(menu, l, e, map, true)
        Play.drawChips(l, map, true, 0)
    else
        UI.text(#mp.rooms == 0 and "No open room yet. Create one!" or "Unknown map", l.preview.x + 12, l.preview.y + 12, 14, UI.colors.muted)
    end

    local password = find(elements, "password")
    UI.text("ROOM PASSWORD", password.x, password.y - 22, 11, UI.colors.muted)
    UI.field("password", password.x, password.y, password.w, password.h, string.rep("*", #(menu.password or "")), {
        editing = menu.editing == "password", hot = menu.focus == "password", icon = "Key.png", placeholder = "Optional", size = 13
    })
    local refresh = find(elements, "refresh")
    UI.text(string.format("Connected to %s as %s", tostring(mp.address), mp.name), refresh.x, refresh.y - 66, 12, UI.colors.muted)
    drawStatus(menu, refresh.x, refresh.y - 42)
    UI.button("refresh", refresh.x, refresh.y, refresh.w, refresh.h, "REFRESH", { hot = menu.focus == "refresh", icon = "Restart.png", size = 14 })
    local disconnect = find(elements, "disconnect")
    UI.button("disconnect", disconnect.x, disconnect.y, disconnect.w, disconnect.h, "DISCONNECT", { hot = menu.focus == "disconnect", icon = "Exit.png", size = 14, color = UI.colors.bad })
    local create = find(elements, "create")
    local current = menu:current()
    UI.button("create", create.x, create.y, create.w, create.h, "CREATE ROOM", {
        hot = menu.focus == "create", icon = "Home.png", size = 16, sublabel = current and ("on " .. current.name) or nil, align = "left"
    })
    local rejoin = find(elements, "rejoin")
    if rejoin then
        UI.button("rejoin", rejoin.x, rejoin.y, rejoin.w, rejoin.h, "REJOIN GAME", {
            hot = menu.focus == "rejoin", icon = "Restart.png", size = 16, sublabel = "Your last game is still running", align = "left", color = UI.colors.gold
        })
    end
    local join = find(elements, "join")
    UI.button("join", join.x, join.y, join.w, join.h, room and ("JOIN " .. string.upper(room.name)) or "JOIN ROOM", {
        hot = menu.focus == "join", primary = room ~= nil, disabled = room == nil, size = 18, icon = "Play.png", hint = "ENTER"
    })
end

local function drawLobby(menu, elements, l, e)
    local mp = net()
    local room = mp.room
    local host = mp:IsHost()
    local s = roomSettings(menu)
    local map = mapByPath(menu, s.map)
    if map then
        Play.drawPreview(menu, lobbyLayout(l), e, map, s.nations)
        Play.drawChips(l, map, s.nations, s.bots or 0)
    else
        UI.text("Missing map " .. tostring(s.map), l.preview.x + 12, l.preview.y + 12, 14, UI.colors.bad)
    end

    local u = UI.unit
    local area = chatArea(l)
    local input = find(elements, "chat")
    UI.panel(area.x, area.y, area.w, area.h, {})
    UI.text("CHAT", area.x + u * 4, area.y + u * 3, 11, UI.colors.muted)
    local indexes = {}
    for k, player in ipairs(room.players or {}) do
        indexes[player.id] = { player = player, slot = k }
    end
    local entries = {}
    for _, message in ipairs(mp.chat) do
        local member = indexes[message.id]
        entries[#entries + 1] = { message = message, color = member and colorFor(member.player, member.slot) or ChatLog.color(message) }
    end
    ChatLog.draw(entries, area.x + u * 2, input.y - u * 2, area.w - u * 4, { top = area.y + 24 })
    ChatLog.input(input.x + u * 2, input.y, input.w - u * 4, input.h - u * 2, menu.chatText or "", {
        editing = menu.editing == "chat",
        placeholder = menu.editing == "chat" and "" or "Click to chat"
    })
    local nations = find(elements, "nations")
    local players = room.players or {}
    UI.text(string.format("PLAYERS  %d / %d", #players, room.max or #players), nations.x, nations.y - 88, 11, UI.colors.muted)
    local area = find(elements, "players")
    local mx, my = love.mouse.getPosition()
    local hint
    for _, chip in ipairs(chipLayout(mp, area.x, area.y)) do
        local player = chip.player
        local isHost = player.id == room.host
        local textColor = isHost and UI.colors.gold or (player.ready and UI.colors.good or UI.colors.text)
        UI.chip(chip.x, chip.y, chip.label, chip.icon, textColor)
        local c = colorFor(player, chip.slot)
        UI.color(c)
        love.graphics.rectangle("fill", chip.x + u, chip.y + chip.h, chip.w - 2 * u, u)
        if player.flag then
            Style.flag(player.flag, chip.x + chip.w + 3, chip.y + 3, 13)
        end
        if mx >= chip.x and mx < chip.x + chip.w and my >= chip.y and my < chip.y + chip.h then
            if player.id == mp.id then
                hint = "Click to change your color"
            elseif host then
                hint = "Click to kick " .. player.name
            end
        end
    end
    if hint then
        UI.text(hint, nations.x, nations.y - 34, 12, UI.colors.troops)
    else
        drawStatus(menu, nations.x, nations.y - 34)
    end

    local nationCount = map and #(map.manifest.nations or {}) or 0
    UI.text("NATIONS", nations.x, nations.y - 22, 11, UI.colors.muted)
    local nhot = UI.ease("mpnations:hot", host and menu.focus == "nations")
    UI.color(UI.colors.raised, 0.4 + 0.4 * nhot)
    UI.block(nations.x, nations.y, nations.w, nations.h)
    local tw = UI.toggle("mpnations", nations.x + u * 3, nations.y + math.floor((nations.h - u * 7) / 2), s.nations, host and menu.focus == "nations")
    UI.text(s.nations and string.format("%d historical nations", nationCount) or "Disabled", nations.x + tw + u * 7, nations.y + 9, 13, s.nations and UI.colors.text or UI.colors.muted)

    local difficulty = find(elements, "difficulty")
    UI.text("DIFFICULTY", difficulty.x, difficulty.y - 22, 11, UI.colors.muted)
    local dcolors = { UI.colors.good, UI.colors.hover, UI.colors.bad }
    local index = difficultyIndex(s.difficulty)
    UI.segments("mpdifficulty", difficulty.x, difficulty.y, difficulty.w, difficulty.h, DIFFICULTY_LABELS, index, { hot = host and menu.focus == "difficulty", color = dcolors[index] })

    local bots = find(elements, "bots")
    UI.text("WILD TRIBES", bots.x, bots.y - 26, 11, UI.colors.muted)
    local botsText = tostring(s.bots or 0)
    local font = Style.font(13)
    UI.text(botsText, bots.x + bots.w - font:getWidth(botsText), bots.y - 30, 13, UI.colors.troops)
    UI.meter("mpbots", bots.x, bots.y, bots.w, bots.h, (s.bots or 0) / MAX_BOTS, UI.colors.troops, { knob = host, hot = host and (menu.focus == "bots" or menu.dragging == "bots") })

    local leave = find(elements, "leave")
    UI.button("leave", leave.x, leave.y, leave.w, leave.h, "LEAVE", { hot = menu.focus == "leave", icon = "Exit.png", size = 16, color = UI.colors.bad })
    local start = find(elements, "start")
    if host then
        local all, ready, count = mp:AllReady()
        UI.button("start", start.x, start.y, start.w, start.h, all and "START GAME" or string.format("WAITING  %d/%d READY", ready, count), {
            hot = menu.focus == "start", primary = all, disabled = not all, size = 20, icon = "Play.png", hint = all and "ENTER" or nil
        })
    else
        local me = mp:Me()
        local ready = me and me.ready
        UI.button("start", start.x, start.y, start.w, start.h, ready and "READY  -  WAITING FOR HOST" or "I'M READY", {
            hot = menu.focus == "start", primary = not ready, size = 18, icon = ready and "Unlocked.png" or "Locked.png", hint = "ENTER", color = ready and UI.colors.good or nil
        })
    end
end

function Multiplayer.draw(menu, elements, p)
    local l = Play.layout()
    local current = phase()
    local mp = net()

    UI.alpha = menu:stagger(p, 1)
    local back = find(elements, "back")
    UI.button("back", back.x, back.y, back.w, back.h, current == "lobby" and "LEAVE" or "BACK", { hot = menu.focus == "back", icon = "Enter2.png", align = "left", size = 14, hint = "ESC" })
    local titles = {
        connect = { "MULTIPLAYER", "Connect to a server to find other commanders." },
        browse = { "SERVER ROOMS", "Join an open room or create your own." },
        lobby = { string.upper(mp.room and mp.room.name or "LOBBY"), mp:LanEndpoint() and ("Open on your network at " .. mp:LanEndpoint() .. ": friends find it in Multiplayer.")
            or mp:IsHost() and "You are the host: pick the map and start when everyone is in." or "Waiting for the host to start the game." }
    }
    UI.shadowText(titles[current][1], back.x + back.w + 36, 36, 26, UI.colors.text)
    UI.text(titles[current][2], back.x + back.w + 38, 76, 12, UI.colors.muted)

    local e = menu:stagger(p, 2)
    UI.alpha = e
    local dx = math.floor((1 - e) * -40)
    love.graphics.push()
    love.graphics.translate(dx, 0)
    UI.panel(l.list.x, l.list.y, l.list.w, l.list.h, {})
    if current == "lobby" and mp:IsHost() then
        local search = find(elements, "search")
        UI.field("search", search.x, search.y, search.w, search.h, menu.search, {
            editing = menu.editing == "search", hot = menu.focus == "search",
            placeholder = string.format("Search %d maps...", #menu.maps), icon = "MagnifyingGlass.png", size = 13
        })
        Play.drawList(menu, l, e)
    elseif current == "lobby" then
        UI.text("PLAYERS", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
        local rows = {}
        for _, player in ipairs(mp.room.players or {}) do
            local isHost = player.id == mp.room.host
            local ping = mp.pings[player.id]
            local detail = ping and string.format("%d ms", ping) or nil
            if player.id == mp.id then
                detail = detail and ("you  " .. detail) or "you"
            end
            rows[#rows + 1] = { label = player.name, icon = isHost and "Trophy.png" or "Team.png", color = isHost and UI.colors.gold or nil, detail = detail }
        end
        drawRows(menu, l, e, rows, nil)
    elseif current == "browse" then
        UI.text("OPEN ROOMS", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
        local rows = {}
        for _, room in ipairs(mp.rooms) do
            rows[#rows + 1] = { label = room.name, icon = room.locked and "Locked.png" or "Home.png", detail = string.format("%d/%d", room.players, room.max) }
        end
        drawRows(menu, l, e, rows, menu.roomIndex)
        if #rows == 0 then
            UI.text("No open room.", l.rows.x + UI.unit * 4, l.rows.y + 6, 13, UI.colors.muted)
        end
    else
        UI.text("LAN GAMES", l.list.x + 16, l.list.y + 24, 13, UI.colors.muted)
        local rows = {}
        for _, game in ipairs(mp:LanGames()) do
            rows[#rows + 1] = {
                label = game.name,
                icon = game.locked and "Locked.png" or "Home.png",
                detail = string.format("%d/%d", game.players, game.max)
            }
        end
        drawRows(menu, l, e, rows, nil)
        if #rows == 0 then
            local dots = string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
            UI.text("Searching your network" .. dots, l.rows.x + UI.unit * 4, l.rows.y + 6, 13, UI.colors.muted)
        end
    end
    love.graphics.pop()

    e = menu:stagger(p, 3)
    UI.alpha = e
    love.graphics.push()
    love.graphics.translate(0, math.floor((1 - e) * 30))
    UI.panel(l.panel.x, l.panel.y, l.panel.w, l.panel.h, { accent = UI.colors.gold, cornerAlpha = 0.5 })
    if current == "connect" then
        drawConnect(menu, elements, l)
    elseif current == "browse" then
        drawBrowse(menu, elements, l, e)
    else
        drawLobby(menu, elements, l, e)
    end
    love.graphics.pop()
    UI.alpha = 1
end

function Multiplayer.capture(menu, key)
    if key == "escape" and menu.editing == "chat" then
        menu.editing = nil
        return true
    end
    return false
end

function Multiplayer.keyPressed(menu, key)
    local current = phase()
    if key == "return" or key == "kpenter" then
        if menu.editing == "chat" and current == "lobby" then
            sendChat(menu)
            return true
        end
        if menu.focus == "back" then return false end
        if current == "connect" then
            connect(menu)
        elseif current == "browse" then
            joinSelected(menu)
        elseif net():IsHost() then
            net():StartGame()
        else
            toggleReady()
        end
        return true
    end
    if key == "up" or key == "down" then
        local delta = key == "up" and -1 or 1
        if current == "browse" and (menu.focus == nil or menu.focus == "rooms") then
            moveRoom(menu, delta)
            return true
        elseif current == "lobby" and net():IsHost() and (menu.focus == nil or menu.focus == "list" or menu.focus == "search") then
            menu:moveSelection(delta)
            return true
        end
    end
    return false
end

function Multiplayer.wheel(menu, y)
    if phase() == "lobby" and net():IsHost() then
        Play.wheel(menu, y)
    end
end

function Multiplayer.back(menu)
    if phase() == "lobby" then
        net():LeaveRoom()
        return
    end
    menu:switch("root", -1)
end

return Multiplayer
