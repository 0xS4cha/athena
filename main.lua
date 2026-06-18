local env = require("src.core.env")
local modules = require("src.modules.index")
local json = require("src.core.json")
local GM = require("src.core.index")

function love.load()
    env.load(".env")
    modules:Load("src/modules")
    GM:InitializeModules()
end

function love.update(dt)

end



function love.draw()
    
end