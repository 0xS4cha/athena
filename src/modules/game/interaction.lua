local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Ships = require("src.modules.game.systems.ships")
local Nukes = require("src.modules.game.systems.nukes")
local Config = require("src.config.game")
local Format = require("src.core.format")

local Interaction = {}

function Interaction.click(game, tile)
    local human = game.human
    local map = game.map
    if game.phase == "spawn" then
        game:pushIntent({ type = "spawn", player = human.id, tile = tile })
        return
    end
    if game.phase ~= "playing" or not human.alive or map:isWater(tile) then
        return
    end
    local targetId = map.owner[tile]
    if targetId == human.id then
        return
    end
    local target = targetId ~= 0 and game.players[targetId] or nil
    if target and human:isAlliedWith(target) then
        game:addEvent("You cannot attack your ally " .. target.name .. ".")
        return
    end
    if Attack.sharesBorder(game, human, targetId) then
        game:pushIntent({ type = "attack", player = human.id, target = targetId, ratio = human.attackRatio })
        return
    end
    local ok, reason = Ships.canSendBoat(game, human, tile)
    if ok then
        game:pushIntent({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio })
        return
    end
    game:addEvent("Cannot reach " .. (target and target.name or "this land") .. ": " .. reason .. ".")
end

function Interaction.unitItem(game, kind, tile)
    local human = game.human
    local def = Config.units[kind]
    local ok, reason = Units.check(game, human, kind, tile)
    return {
        label = def.label,
        icon = def.icon,
        sprite = kind,
        sublabel = ok and Format.number(Units.cost(game, human, kind)) or reason,
        sublabelColor = not ok and { 0.95, 0.35, 0.3, 1 } or nil,
        disabled = not ok,
        action = function()
            game:pushIntent({ type = "build", player = human.id, unit = kind, tile = tile })
        end
    }
end

function Interaction.buildItems(game, tile)
    local items = {}
    for _, kind in ipairs(Config.buildMenu) do
        items[#items + 1] = Interaction.unitItem(game, kind, tile)
    end
    return items
end

Interaction.sections = {}

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    if game.map.owner[tile] ~= human.id and not game.map:isWater(tile) then return end
    local nearCoast = Units.findPortTile(game, human, tile)
    if game.map.owner[tile] ~= human.id and not nearCoast then return end
    items[#items + 1] = {
        label = "Build",
        icon = "Hammer.png",
        submenu = function()
            return "BUILD", Interaction.buildItems(game, tile)
        end
    }
end

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    local map = game.map
    if map:isWater(tile) or map.owner[tile] == human.id then return end
    local target = game:playerAt(tile)
    if target and human:isAlliedWith(target) then return end
    local name = target and target.name or "Wilderness"
    if Attack.sharesBorder(game, human, map.owner[tile]) then
        items[#items + 1] = {
            label = "Attack " .. name,
            icon = "Skull.png",
            sublabel = Format.number(human.troops * human.attackRatio),
            sublabelColor = { 0.95, 0.35, 0.3, 1 },
            action = function()
                game:pushIntent({ type = "attack", player = human.id, target = map.owner[tile], ratio = human.attackRatio })
            end
        }
    end
    local ok, reason = Ships.canSendBoat(game, human, tile)
    items[#items + 1] = {
        label = "Send Boat",
        icon = "Luggage.png",
        sublabel = ok and Format.number(human.troops * human.attackRatio) or reason,
        sublabelColor = ok and { 0.45, 0.75, 1, 1 } or { 0.95, 0.35, 0.3, 1 },
        disabled = not ok,
        action = function()
            game:pushIntent({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio })
        end
    }
end

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    if human:unitCount("silo") == 0 or game.map.owner[tile] == human.id then return end
    items[#items + 1] = {
        label = "Launch Nuke",
        icon = "PotionRed.png",
        color = { 1, 0.55, 0.4, 1 },
        submenu = function()
            local list = {}
            for _, kind in ipairs(Config.nukeTypes) do
                local def = Config.nukes[kind]
                local ok, reason = Nukes.check(game, human, kind, tile)
                list[#list + 1] = {
                    label = def.label,
                    icon = def.icon,
                    sublabel = ok and Format.number(def.cost) or reason,
                    sublabelColor = not ok and { 0.95, 0.35, 0.3, 1 } or nil,
                    disabled = not ok,
                    action = function()
                        game:pushIntent({ type = "nuke", player = human.id, kind = kind, tile = tile })
                    end
                }
            end
            return "NUKES", list
        end
    }
end

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    local target = game:playerAt(tile)
    if not target or target == human or not target.alive then return end
    local GOOD, BAD = { 0.3, 0.85, 0.45, 1 }, { 0.95, 0.35, 0.3, 1 }
    if human:isAlliedWith(target) then
        items[#items + 1] = {
            label = "Donate Troops",
            icon = "Team.png",
            sublabel = Format.number(human.troops * human.attackRatio),
            sublabelColor = { 0.45, 0.75, 1, 1 },
            action = function() game:pushIntent({ type = "donate", player = human.id, target = target.id, kind = "troops" }) end
        }
        items[#items + 1] = {
            label = "Donate Gold",
            icon = "Coin.png",
            sublabel = Format.number(human.gold * human.attackRatio),
            action = function() game:pushIntent({ type = "donate", player = human.id, target = target.id, kind = "gold" }) end
        }
        items[#items + 1] = {
            label = "Break Alliance",
            icon = "Unlocked.png",
            color = BAD,
            action = function() game:pushIntent({ type = "allianceBreak", player = human.id, target = target.id }) end
        }
    elseif not target:isBot() then
        local pending = target.allianceRequests[human.id] ~= nil
        local incoming = human.allianceRequests[target.id] ~= nil
        items[#items + 1] = {
            label = incoming and "Accept Alliance" or "Request Alliance",
            icon = "Team.png",
            color = GOOD,
            disabled = pending,
            sublabel = pending and "Pending" or nil,
            action = function()
                if incoming then
                    game:pushIntent({ type = "allianceReply", player = human.id, from = target.id, accept = true })
                else
                    game:pushIntent({ type = "allianceRequest", player = human.id, target = target.id })
                end
            end
        }
    end
    local embargoed = human.embargo[target.id] ~= nil
    items[#items + 1] = {
        label = embargoed and "Lift Embargo" or "Embargo",
        icon = "Locked.png",
        action = function() game:pushIntent({ type = "embargo", player = human.id, target = target.id, enabled = not embargoed }) end
    }
    local targeted = human.target == target.id
    items[#items + 1] = {
        label = targeted and "Clear Target" or "Mark As Target",
        icon = "MagnifyingGlass.png",
        action = function() game:pushIntent({ type = "setTarget", player = human.id, target = not targeted and target.id or nil }) end
    }
    items[#items + 1] = {
        label = "Send Emoji",
        icon = "Sun.png",
        submenu = function()
            local list = {}
            for _, icon in ipairs(Config.emojis) do
                list[#list + 1] = {
                    label = icon:gsub("%.png$", ""),
                    icon = icon,
                    action = function() game:pushIntent({ type = "emoji", player = human.id, target = target.id, icon = icon }) end
                }
            end
            return "EMOJI", list
        end
    }
end

Interaction.sections[#Interaction.sections + 1] = function(game, tile, items)
    local human = game.human
    if human:unitCount("warship") == 0 then return end
    local map = game.map
    local x, y = map:coords(tile)
    local nearWater = map:findNear(x, y, Config.blockadeRange, function(i) return map:isWater(i) end)
    if not nearWater then return end
    items[#items + 1] = {
        label = "Send Warship Here",
        icon = "Wrench3.png",
        sublabel = human:unitCount("warship") .. " ships",
        sublabelColor = { 0.45, 0.75, 1, 1 },
        action = function()
            game:pushIntent({ type = "warship", player = human.id, tile = tile })
        end
    }
end

function Interaction.menu(game, tile)
    local map = game.map
    local x, y = map:coords(tile)
    local items = {}
    if game.phase == "playing" and game.human.alive then
        for _, section in ipairs(Interaction.sections) do
            section(game, tile, items)
        end
    end
    items[#items + 1] = { label = "Close Menu", icon = "Exit.png" }
    local owner = game:playerAt(tile)
    local title = owner and owner.name or string.format("TILE [%d, %d]", x, y)
    return title, items
end

return Interaction
