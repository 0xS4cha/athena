local CONFIG = require("src.config.window")

--- @param t table
function love.conf(t)
    t.window.title      = CONFIG.title
    t.window.width      = CONFIG.width
    t.window.height     = CONFIG.height
    t.window.resizable  = CONFIG.resizable
    t.window.vsync      = CONFIG.vsync
    t.window.icon       = CONFIG.icon
    t.console           = true
end