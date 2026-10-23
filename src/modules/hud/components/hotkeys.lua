local GM = require("src.core.index")
local Interaction = require("src.modules.game.interaction")
local Keybinds = require("src.modules.input.keybinds")

local Hotkeys = {}

function Hotkeys.visible()
    return false
end

function Hotkeys.draw() end

function Hotkeys.keyPressed(hud, key)
    if hud.settingsOpen or hud.helpOpen then return false end
    local action = Keybinds.find(key)
    if not action then return false end
    hud.contextMenu:close()
    Interaction.hotkey(hud:game(), action, GM.Session:HoveredTile())
    return true
end

return Hotkeys
