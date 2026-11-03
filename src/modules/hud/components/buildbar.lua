local Keybinds = require("src.modules.input.keybinds")
local Units = require("src.modules.game.systems.units")
local Config = require("src.config.game")
local Structures = require("src.modules.game.structures")
local Style = require("src.modules.hud.style")
local Pixel = require("src.modules.hud.pixel")

local BuildBar = {}

local ICON = 16
local CELL = 22
local GAP = 2
local KEY_FONT = 10
local LEFT = 15
local BOTTOM = 44
local DIM = 0.4

function BuildBar.entries(game)
    local list = {}
    local human = game.human
    local aim = game.buildAim
    for _, action in ipairs(Keybinds.actions) do
        local key = action.group == "build" and Keybinds.get(action.id)
        if key and Units.allowed(game, action.kind) then
            list[#list + 1] = {
                kind = action.kind,
                icon = action.icon,
                key = Keybinds.label(key),
                affordable = human.gold >= Units.cost(game, human, action.kind),
                active = aim ~= nil and aim.kind == action.kind
            }
        end
    end
    return list
end

function BuildBar.visible(hud)
    local game = hud:game()
    return game.phase == "playing" and game.human.alive and not game.options.spectator and not hud.spectating
end

function BuildBar.draw(hud)
    local game = hud:game()
    local font = Style.font(KEY_FONT)
    local h = ICON + font:getHeight() + 6
    local _, H = love.graphics.getDimensions()
    local x, y = LEFT, H - h - BOTTOM
    for _, entry in ipairs(BuildBar.entries(game)) do
        local w = math.max(CELL, font:getWidth(entry.key) + 6)
        local alpha = (entry.affordable or entry.active) and 1 or DIM
        Pixel.color(entry.active and Style.colors.gold or Pixel.colors.ink, entry.active and 0.9 or 0.7)
        Pixel.block(x, y, w, h, Pixel.unit)
        local ix = x + math.floor((w - ICON) / 2)
        if not Structures.icon(entry.kind, ix, y + 2, ICON, game.human.color, alpha) then
            Pixel.icon(entry.icon, ix, y + 2, ICON, alpha)
        end
        local keyColor = entry.active and Pixel.colors.ink or Style.colors.gold
        Pixel.text(entry.key, x + math.floor((w - font:getWidth(entry.key)) / 2), y + ICON + 3, KEY_FONT, keyColor, alpha)
        x = x + w + GAP
    end
end

return BuildBar
