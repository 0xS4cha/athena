local GM = require("src.core.index")
local HudClass = require("src.modules.hud.hud")

GM.Hud = {}

GM.Modules:Register("Hud", 80)

function GM.Hud:Initialize()
    self.Instance = HudClass()
end

function GM.Hud:Draw()
    if self.Instance then
        self.Instance:Draw()
    end
end

function GM.Hud:MousePressed(x, y, button, istouch, presses)
    if self.Instance then
        self.Instance:MousePressed(x, y, button, istouch, presses)
    end
end

function GM.Hud:KeyPressed(key, scancode, isrepeat)
    if self.Instance then
        self.Instance:KeyPressed(key, scancode, isrepeat)
    end
end