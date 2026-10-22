local Multiplayer = { id = "Multiplayer" }

-- function Multiplayer.build(menu)
--     local l = Play.layout()
--     local p = l.panel
--     local cx, cw = p.x + 24, p.w - 48
--     local cy = p.y + p.h - CONTROLS_H + 12
--     local half = math.floor((cw - 24) / 2)
--     local function moveSelection(delta)
--         return function() menu:moveSelection(delta) end
--     end
--     return {
--         { id = "back", x = l.M, y = 36, w = 150, h = 46, nav = false, press = function() menu:switch("root", -1) end },
--         {
--             id = "search", x = l.list.x + 12, y = l.list.y + 14, w = l.list.w - 24, h = 40,
--             press = function() menu.editing = "search" end,
--             text = textHandler(menu, "search"), up = moveSelection(-1), down = moveSelection(1)
--         },
--         {
--             id = "list", x = l.rows.x, y = l.rows.y, w = l.rows.w, h = l.rows.h, nav = false,
--             press = function(_, _, my) Play.clickRow(menu, my) end,
--             up = moveSelection(-1), down = moveSelection(1)
--         },
--         {
--             id = "name", x = cx, y = cy + 22, w = half, h = 42,
--             press = function() menu.editing = "name" end,
--             text = textHandler(menu, "name")
--         },
--         {
--             id = "nations", x = cx + half + 24, y = cy + 22, w = cw - half - 24, h = 42,
--             press = function() menu.settings.nations = not menu.settings.nations end,
--             left = function() menu.settings.nations = false end,
--             right = function() menu.settings.nations = true end
--         },
--         {
--             id = "bots", x = cx, y = cy + 108, w = cw, h = 24,
--             drag = function(_, mx)
--                 local pct = Fx.clamp((mx - cx) / cw, 0, 1)
--                 menu.settings.bots = math.floor(pct * MAX_BOTS / 5 + 0.5) * 5
--             end,
--             left = function() menu.settings.bots = math.max(0, menu.settings.bots - 10) end,
--             right = function() menu.settings.bots = math.min(MAX_BOTS, menu.settings.bots + 10) end
--         },
--         {
--             id = "difficulty", x = cx, y = cy + 166, w = cw, h = 40,
--             press = function(_, mx)
--                 if not mx then
--                     menu.settings.difficulty = DIFFICULTIES[difficultyIndex(menu) % #DIFFICULTIES + 1]
--                     return
--                 end
--                 local k = Fx.clamp(math.floor((mx - cx) / (cw / #DIFFICULTIES)) + 1, 1, #DIFFICULTIES)
--                 menu.settings.difficulty = DIFFICULTIES[k]
--             end,
--             left = function() menu.settings.difficulty = DIFFICULTIES[math.max(1, difficultyIndex(menu) - 1)] end,
--             right = function() menu.settings.difficulty = DIFFICULTIES[math.min(#DIFFICULTIES, difficultyIndex(menu) + 1)] end
--         },
--         { id = "start", x = cx, y = cy + 222, w = cw, h = 58, press = function() menu:start() end }
--     }
-- end

function Multiplayer.back(menu)
    menu:switch("root", -1)
end

return Multiplayer