local CONFIG = require("config.window")

function love.conf(t)
    t.window.title      = CONFIG.title
    t.window.width      = CONFIG.width
    t.window.height     = CONFIG.height
    t.window.resizable  = CONFIG.resizable
    t.window.vsync      = CONFIG.vsync
    t.window.icon       = CONFIG.icon
end