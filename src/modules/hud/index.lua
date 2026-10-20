local GM = require("src.core.index")
local HudClass = require("src.modules.hud.hud")

GM.Hud = {}

GM.Modules:Register("Hud", 80)

function GM.Hud:Initialize()
    self.Instance = HudClass()
end

function GM.Hud:Draw()
    self.Instance:Draw()
end

function GM.Hud:Think(dt)
    self.Instance:Think(dt)
end

function GM.Hud:MousePressed(x, y, button, istouch, presses)
    self.Instance:MousePressed(x, y, button, istouch, presses)
end

function GM.Hud:MouseReleased(x, y, button, istouch, presses)
    self.Instance:MouseReleased(x, y, button, istouch, presses)
end

function GM.Hud:KeyPressed(key, scancode, isrepeat)
    self.Instance:KeyPressed(key, scancode, isrepeat)
end

function GM.Hud:Captures(mx, my)
    return self.Instance ~= nil and self.Instance:game() ~= nil and self.Instance:Captures(mx, my)
end
