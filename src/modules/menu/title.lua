local Style = require("src.modules.hud.style")
local Fx = require("src.modules.hud.fx")
local UI = require("src.modules.hud.pixel")
local WordArt = require("src.modules.hud.wordart")

local Title = {}

local TEXT = "ATHENA"
local TAGLINE = "Conquer the world, one tile at a time."
local FONT_SIZE = 22

local HELMET = Fx.mirror({
    ".......kkk",
    ".....kkrRR",
    "....krrRRR",
    "...krrrRRr",
    "...krrrrrr",
    "...kkkkkkk",
    "....kddgGG",
    "...kdggGwG",
    "..kdgggGGG",
    "..kdgggggg",
    ".kdggggggg",
    ".kdgkkkkkg",
    ".kdgkkkkkg",
    ".kdggkkkkg",
    ".kddggkkkk",
    "..kdggk...",
    "..kdggk...",
    "..kddgk...",
    "...kddk...",
    "....kk...."
})

local HELMET_COLORS = {
    k = { 0.05, 0.04, 0.08 },
    r = { 0.72, 0.16, 0.14 },
    R = { 0.95, 0.35, 0.25 },
    d = { 0.62, 0.42, 0.12 },
    g = { 0.9, 0.68, 0.2 },
    G = { 1, 0.88, 0.45 },
    w = { 1, 1, 0.9 }
}

function Title.scale()
    local _, H = love.graphics.getDimensions()
    return math.max(3, math.min(6, math.floor(H / 190)))
end

function Title.size()
    local scale = Title.scale()
    local w, h = WordArt.size(TEXT, FONT_SIZE, scale)
    return (#HELMET[1] + 4) * scale + w, h
end

function Title.draw(x, y, p, time, alpha)
    local scale = Title.scale()
    local _, height = WordArt.size(TEXT, FONT_SIZE, scale)
    local helmetIn = Fx.clamp(p * 2.2, 0, 1)
    local helmetY = y + math.floor((height - #HELMET * scale) / 2)
    local float = math.floor(math.sin(time * 1.3) * 1.5 + 0.5) * scale
    local rise = math.floor((1 - Fx.outCubic(helmetIn)) * 8) * scale
    Fx.sprite(HELMET, HELMET_COLORS, x, helmetY + float + rise, scale, helmetIn * alpha)
    WordArt.draw(TEXT, x + (#HELMET[1] + 4) * scale, y, { size = FONT_SIZE, scale = scale, progress = p, time = time, alpha = alpha })
end

function Title.tagline(x, y, p, alpha)
    local count = math.floor(Fx.clamp(p, 0, 1) * #TAGLINE)
    local text = TAGLINE:sub(1, count)
    local w = UI.text(text, x, y, 15, UI.colors.muted, alpha)
    if count < #TAGLINE or love.timer.getTime() % 1 < 0.5 then
        UI.color(UI.colors.gold, alpha)
        love.graphics.rectangle("fill", x + w + 3, y + 5, UI.unit * 2, Style.font(15):getHeight() - 10)
    end
end

return Title
