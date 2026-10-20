local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")

local Info = { id = "info" }

local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Overlay = require("src.modules.game.overlay")

function Info.draw(hud)
    local game = hud:game()
    local tile = GM.Session:HoveredTile()
    if not tile then return end

    local map = game.map
    local x, y = map:coords(tile)
    local biome = map:terrainType(tile)
    local parts = { string.format("X:%d Y:%d", x, y), Config.biomes[biome].label }
    if biome ~= "water" and game.human.spawned then
        parts[#parts + 1] = string.format("Cost x%.1f", Attack.biomeMultiplier(game.human, biome))
    end
    local camera = hud:camera()
    local structure = Overlay.structureAlpha(camera) > 0 and Overlay.structureAt(game, tile)
    if structure then
        parts[#parts + 1] = Config.units[structure.kind].label .. (structure.buildLeft > 0 and " (building)" or "")
    end
    if map.fallout[tile] > 0 then
        parts[#parts + 1] = "Fallout"
    end
    local owner = game:playerAt(tile)
    if owner then
        parts[#parts + 1] = owner.name
        parts[#parts + 1] = Format.number(owner.troops) .. " troops"
        parts[#parts + 1] = Format.percent(owner.tiles / map.landCount)
        local human = game.human
        if owner == human then
            parts[#parts + 1] = "You"
        elseif owner:isAlliedWith(human) then
            parts[#parts + 1] = "Ally"
        end
        if owner.traitorUntil > game.tick then
            parts[#parts + 1] = "Traitor"
        end
        if human.embargo[owner.id] then
            parts[#parts + 1] = "Embargo"
        end
    end
    local text = table.concat(parts, "  |  ")

    local font = Style.font(12)
    love.graphics.setFont(font)
    local _, H = love.graphics.getDimensions()
    local hasFlag = owner and owner.flag
    local w = font:getWidth(text) + 24 + (hasFlag and 26 or 0)
    local by = H - 35
    Style.box(15, by, w, 24)
    if owner then
        Style.setColor(owner.color)
    else
        Style.setColor(Style.colors.text)
    end
    love.graphics.print(text, 25, by + 5)
    if hasFlag then
        Style.flag(owner.flag, 15 + w - 26, by + 4, 16)
    end
end

return Info
