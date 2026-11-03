local Common = require("src.modules.menu.screens.multiplayer.common")
local Style = require("src.modules.hud.style")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local Play = require("src.modules.menu.screens.play")
local Palette = require("src.modules.player.palette")
local ChatLog = require("src.modules.hud.chatlog")
local Teams = require("src.modules.game.systems.teams")
local Rules = require("src.modules.game.rules")

local net, find, mapByPath = Common.net, Common.find, Common.mapByPath
local ROW = Common.ROW
local MAX_BOTS = 400
local SYNC_DELAY = 0.25
local CHAT_W = 380
local CHAT_INPUT_H = 38
local DIFFICULTIES = { "easy", "medium", "hard" }
local DIFFICULTY_LABELS = { "Easy", "Medium", "Hard" }

local Lobby = {}

local function difficultyIndex(difficulty)
    for k, d in ipairs(DIFFICULTIES) do
        if difficulty == d then return k end
    end
    return 2
end

local function settingsKey(s)
    return string.format("%s|%d|%s|%s|%d|%s", tostring(s.map), s.bots or 0, tostring(s.nations), tostring(s.difficulty), s.teams or 0, Rules.encode(Rules.sanitize(s.rules)))
end

local function roomSettings(menu)
    local mp = net()
    if mp:IsHost() then
        return Common.hostSettings(menu)
    end
    return mp.room and mp.room.settings or {}
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

local function sideLabels(count)
    local labels = { "Auto" }
    for team = 1, count do
        labels[#labels + 1] = Teams.names[team]
    end
    return labels
end

local function pickSide(delta, mx, x, w, count)
    local me = net():Me()
    local current = me and me.team or 0
    local side
    if mx then
        side = Fx.clamp(math.floor((mx - x) / (w / (count + 1))), 0, count)
    elseif delta then
        side = Fx.clamp(current + delta, 0, count)
    else
        side = (current + 1) % (count + 1)
    end
    net():SendProfile(side)
end

local function editable(menu, fn)
    return function(...)
        if net():IsHost() then fn(...) end
    end
end

function Lobby.update(menu)
    local mp = net()
    if not mp:IsHost() or mp.room.state ~= "lobby" then return end
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
        menu.settings.teams = s.teams or 0
        menu.rules = Rules.sanitize(s.rules)
        menu.settings.rules = Rules.encode(menu.rules)
        menu.syncedKey = settingsKey(s)
    end
    local settings = Common.hostSettings(menu)
    local key = settingsKey(settings)
    local now = love.timer.getTime()
    if key ~= menu.syncedKey and now - (menu.syncTime or 0) > SYNC_DELAY then
        menu.syncedKey = key
        menu.syncTime = now
        mp:Configure(settings)
    end
end

function Lobby.build(menu, l, add)
    local p = l.panel
    local cx, cw = p.x + 24, p.w - 48
    local cy = p.y + p.h - Common.CONTROLS_H + 12
    local half = math.floor((cw - 24) / 2)
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
    local column = math.floor((cw - 48) / 3)
    add({
        id = "nations", x = cx, y = cy + 90, w = column, h = 40,
        press = editable(menu, function() s.nations = not s.nations end),
        left = editable(menu, function() s.nations = false end),
        right = editable(menu, function() s.nations = true end)
    })
    add({
        id = "teams", x = cx + (column + 24) * 2, y = cy + 90, w = cw - (column + 24) * 2, h = 40,
        press = editable(menu, function(_, mx)
            local count = #Teams.modes
            local tx, tw = cx + (column + 24) * 2, cw - (column + 24) * 2
            local index = mx and Fx.clamp(math.floor((mx - tx) / (tw / count)) + 1, 1, count)
                or Teams.modeIndex(s.teams) % count + 1
            s.teams = Teams.modes[index]
        end),
        left = editable(menu, function() s.teams = Teams.modes[math.max(1, Teams.modeIndex(s.teams) - 1)] end),
        right = editable(menu, function() s.teams = Teams.modes[math.min(#Teams.modes, Teams.modeIndex(s.teams) + 1)] end)
    })
    add({
        id = "difficulty", x = cx + column + 24, y = cy + 90, w = column, h = 40,
        press = editable(menu, function(_, mx)
            local dx, dw = cx + column + 24, column
            if not mx then
                s.difficulty = DIFFICULTIES[difficultyIndex(s.difficulty) % #DIFFICULTIES + 1]
                return
            end
            s.difficulty = DIFFICULTIES[Fx.clamp(math.floor((mx - dx) / (dw / #DIFFICULTIES)) + 1, 1, #DIFFICULTIES)]
        end),
        left = editable(menu, function() s.difficulty = DIFFICULTIES[math.max(1, difficultyIndex(s.difficulty) - 1)] end),
        right = editable(menu, function() s.difficulty = DIFFICULTIES[math.min(#DIFFICULTIES, difficultyIndex(s.difficulty) + 1)] end)
    })
    local sides = roomSettings(menu).teams or 0
    local botsW = sides > 0 and half or cw
    if sides > 0 then
        local sx, sw = cx + half + 24, cw - half - 24
        add({
            id = "side", x = sx, y = cy + 158, w = sw, h = 36,
            press = function(_, mx) pickSide(nil, mx, sx, sw, sides) end,
            left = function() pickSide(-1, nil, sx, sw, sides) end,
            right = function() pickSide(1, nil, sx, sw, sides) end
        })
    end
    add({
        id = "bots", x = cx, y = cy + 166, w = botsW, h = 24,
        drag = host and function(_, mx)
            s.bots = math.floor(Fx.clamp((mx - cx) / botsW, 0, 1) * MAX_BOTS / 5 + 0.5) * 5
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
    local third = math.floor((cw - 48) / 3)
    add({ id = "leave", x = cx, y = cy + 222, w = third, h = 58, press = function() net():LeaveRoom() end })
    add({ id = "rules", x = cx + third + 24, y = cy + 222, w = third, h = 58, press = function() menu:openRules("multiplayer") end })
    add({ id = "start", x = cx + (third + 24) * 2, y = cy + 222, w = cw - (third + 24) * 2, h = 58, press = function()
        if net():IsHost() then net():StartGame() else toggleReady() end
    end })
end

function Lobby.drawList(menu, l, e, elements)
    local mp = net()
    if mp:IsHost() then
        local search = find(elements, "search")
        UI.field("search", search.x, search.y, search.w, search.h, menu.search, {
            editing = menu.editing == "search", hot = menu.focus == "search",
            placeholder = string.format("Search %d maps...", #menu.maps), icon = "MagnifyingGlass.png", size = 13
        })
        Play.drawList(menu, l, e)
    else
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
        Common.drawRows(menu, l, e, rows, nil)
    end
end

function Lobby.draw(menu, elements, l, e)
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
        local c = player.team and Teams.color(player.team) or colorFor(player, chip.slot)
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
        Common.drawStatus(menu, nations.x, nations.y - 34)
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

    local teams = find(elements, "teams")
    UI.text("TEAMS", teams.x, teams.y - 22, 11, UI.colors.muted)
    UI.segments("mpteams", teams.x, teams.y, teams.w, teams.h, Teams.modeLabels, Teams.modeIndex(s.teams or 0), { hot = host and menu.focus == "teams" })

    local side = find(elements, "side")
    if side then
        local me = mp:Me()
        local team = me and me.team or nil
        UI.text("YOUR SIDE", side.x, side.y - 20, 11, UI.colors.muted)
        UI.segments("mpside", side.x, side.y, side.w, side.h, sideLabels(s.teams), (team or 0) + 1, { hot = menu.focus == "side", color = team and Teams.color(team) or nil })
    end

    local bots = find(elements, "bots")
    UI.text("WILD TRIBES", bots.x, bots.y - 26, 11, UI.colors.muted)
    local botsText = tostring(s.bots or 0)
    local font = Style.font(13)
    UI.text(botsText, bots.x + bots.w - font:getWidth(botsText), bots.y - 30, 13, UI.colors.troops)
    UI.meter("mpbots", bots.x, bots.y, bots.w, bots.h, (s.bots or 0) / MAX_BOTS, UI.colors.troops, { knob = host, hot = host and (menu.focus == "bots" or menu.dragging == "bots") })

    local leave = find(elements, "leave")
    UI.button("leave", leave.x, leave.y, leave.w, leave.h, "LEAVE", { hot = menu.focus == "leave", icon = "Exit.png", size = 16, color = UI.colors.bad })
    local rules = find(elements, "rules")
    UI.button("rules", rules.x, rules.y, rules.w, rules.h, "RULES", { hot = menu.focus == "rules", icon = "Book.png", size = 16, align = "left", sublabel = Rules.label(s.rules) })
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

function Lobby.capture(menu, key)
    if key == "escape" and menu.editing == "chat" then
        menu.editing = nil
        return true
    end
    return false
end

function Lobby.confirm(menu)
    if menu.editing == "chat" then
        sendChat(menu)
    elseif net():IsHost() then
        net():StartGame()
    else
        toggleReady()
    end
end

function Lobby.navigate(menu, delta)
    if net():IsHost() and (menu.focus == nil or menu.focus == "list" or menu.focus == "search") then
        menu:moveSelection(delta)
        return true
    end
    return false
end

function Lobby.wheel(menu, y)
    if net():IsHost() then
        Play.wheel(menu, y)
    end
end

return Lobby
