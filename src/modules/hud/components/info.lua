local GM = require("src.core.index")
local Style = require("src.modules.hud.style")
local Format = require("src.core.format")
local Pixel = require("src.modules.hud.pixel")

local Info = { id = "info" }

local Config = require("src.config.game")
local Attack = require("src.modules.game.systems.attack")
local Overlay = require("src.modules.game.overlay")
local Supply = require("src.modules.game.systems.supply")

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
        if game.phase == "playing" then
            local supply = Supply.multiplier(game, game.human, tile)
            parts[#parts + 1] = supply > 1 and string.format("Supply x%.1f", supply) or "Supplied"
        end
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
        elseif owner:hasPact(human) then
            parts[#parts + 1] = "Pact"
        end
        if owner.traitorUntil > game.tick then
            parts[#parts + 1] = "Traitor"
        end
        if human.embargo[owner.id] then
            parts[#parts + 1] = "Embargo"
        end
    end
    local text = table.concat(parts, "  -  ")

    local font = Style.font(12)
    local u = Pixel.unit
    local _, H = love.graphics.getDimensions()
    local hasFlag = owner and owner.flag
    local target = font:getWidth(text) + 30 + (hasFlag and 26 or 0)
    local w = math.floor(Pixel.ease("info:width", target, 18))
    local by = H - 38
    Style.box(15, by, w, 27)
    local accent = owner and owner.color or Style.colors.muted
    Pixel.color(accent)
    love.graphics.rectangle("fill", 15 + u, by + u * 2, u * 2, 27 - u * 4)
    love.graphics.setScissor(15, by, w - u * 2, 27)
    Pixel.text(text, 15 + u * 5, by + 6, 12, owner and owner.color or Style.colors.text)
    love.graphics.setScissor()
    if hasFlag and w >= target - 4 then
        Style.flag(owner.flag, 15 + w - 28, by + 5, 16)
    end
end

return Info
