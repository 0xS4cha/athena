local GM = require("src.core.index")
local HudClass = require("src.modules.hud.hud")

GM.Hud = {}

GM.Modules:Register("Hud", 80)

--- @return void
function GM.Hud:Initialize()
    self.Instance = HudClass()
end

--- @return void
function GM.Hud:Draw()
    if self.Instance then
        self.Instance:Draw()
    end
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function GM.Hud:MousePressed(x, y, button, istouch, presses)
    if self.Instance then
        self.Instance:MousePressed(x, y, button, istouch, presses)
    end
end

--- @param x number
--- @param y number
--- @param button number
--- @param istouch boolean
--- @param presses number
--- @return void
function GM.Hud:MouseReleased(x, y, button, istouch, presses)
    if self.Instance then
        self.Instance:MouseReleased(x, y, button, istouch, presses)
    end
end

--- @param key string
--- @param scancode string
--- @param isrepeat boolean
--- @return void
function GM.Hud:KeyPressed(key, scancode, isrepeat)
    if self.Instance then
        self.Instance:KeyPressed(key, scancode, isrepeat)
    end
end