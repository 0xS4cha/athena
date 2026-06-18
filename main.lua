local env = require("src.core.env")
local modules = require("src.modules.index")
local GM = require("src.core.index")

function love.load()
    env.load(".env")
    modules:Load("src/modules")
    GM:InitializeModules()
end

function love.update(dt)
    GM:Think()
end


function love.draw()
end
