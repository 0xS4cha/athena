local Attack = require("src.modules.game.systems.attack")
local Units = require("src.modules.game.systems.units")
local Ships = require("src.modules.game.systems.ships")
local Nukes = require("src.modules.game.systems.nukes")
local Loans = require("src.modules.game.systems.loans")
local Config = require("src.config.game")
local Format = require("src.core.format")
local Personality = require("src.modules.ai.personality")

local Interaction = {}

function Interaction.click(game, tile)
    local human = game.human
    local map = game.map
    if game.phase == "spawn" then
        game:submit({ type = "spawn", player = human.id, tile = tile }, { tile = tile })
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
    if target and human:hasPact(target) then
        game:addEvent("You have a non-aggression pact with " .. target.name .. ".")
        return
    end
    if Attack.sharesBorder(game, human, targetId) then
        game:submit({ type = "attack", player = human.id, target = targetId, ratio = human.attackRatio }, { tile = tile })
        return
    end
    local ok, reason = Ships.canSendBoat(game, human, tile)
    if ok then
        game:submit({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio }, { tile = tile })
        return
    end
    game:addEvent("Cannot reach " .. (target and target.name or "this land") .. ": " .. reason .. ".")
end

function Interaction.unitItem(game, kind, tile)
    local human = game.human
    local def = Config.units[kind]
    local ok, reason = Units.check(game, human, kind, tile)
    local crowded = ok and human.crowded and (kind == "city" or kind == "farm")
    local sublabel = ok and Format.number(Units.cost(game, human, kind)) or reason
    return {
        label = def.label,
        icon = def.icon,
        sprite = kind,
        sublabel = crowded and (sublabel .. "  No housing") or sublabel,
        sublabelColor = not ok and { 0.95, 0.35, 0.3, 1 } or crowded and { 1, 0.82, 0.25, 1 } or nil,
        disabled = not ok,
        action = function()
            game:submit({ type = "build", player = human.id, unit = kind, tile = tile }, { tile = tile })
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
    if target and not human:canAttack(target) then return end
    local name = target and target.name or "Wilderness"
    if Attack.sharesBorder(game, human, map.owner[tile]) then
        items[#items + 1] = {
            label = "Attack " .. name,
            icon = "Skull.png",
            sublabel = Format.number(human.troops * human.attackRatio),
            sublabelColor = { 0.95, 0.35, 0.3, 1 },
            action = function()
                game:submit({ type = "attack", player = human.id, target = map.owner[tile], ratio = human.attackRatio }, { tile = tile })
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
            game:submit({ type = "boat", player = human.id, tile = tile, ratio = human.attackRatio }, { tile = tile })
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
                    preview = { nuke = kind, tile = tile },
                    action = function()
                        Interaction.startAim(game, kind)
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
    if target:isNation() then
        local traits = Personality.of(target)
        items[#items + 1] = {
            label = traits.label,
            icon = traits.icon,
            info = true,
            color = { 0.55, 0.75, 1, 1 },
            sublabel = traits.tag,
            sublabelColor = { 0.55, 0.6, 0.7, 1 }
        }
    end
    if human:isAlliedWith(target) then
        items[#items + 1] = {
            label = "Donate Troops",
            icon = "Team.png",
            sublabel = Format.number(human.troops * human.attackRatio),
            sublabelColor = { 0.45, 0.75, 1, 1 },
            action = function() game:submit({ type = "donate", player = human.id, target = target.id, kind = "troops" }) end
        }
        items[#items + 1] = {
            label = "Donate Gold",
            icon = "Coin.png",
            sublabel = Format.number(human.gold * human.attackRatio),
            action = function() game:submit({ type = "donate", player = human.id, target = target.id, kind = "gold" }) end
        }
        items[#items + 1] = {
            label = "Break Alliance",
            icon = "Unlocked.png",
            color = BAD,
            action = function() game:submit({ type = "allianceBreak", player = human.id, target = target.id }) end
        }
    elseif not target:isBot() then
        Interaction.pactItem(game, target, items)
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
                    game:submit({ type = "allianceReply", player = human.id, from = target.id, accept = true })
                else
                    game:submit({ type = "allianceRequest", player = human.id, target = target.id })
                end
            end
        }
    end
    if not target:isBot() then
        Interaction.loanItems(game, target, items)
    end
    local embargoed = human.embargo[target.id] ~= nil
    items[#items + 1] = {
        label = embargoed and "Lift Embargo" or "Embargo",
        icon = "Locked.png",
        action = function() game:submit({ type = "embargo", player = human.id, target = target.id, enabled = not embargoed }) end
    }
    local targeted = human.target == target.id
    items[#items + 1] = {
        label = targeted and "Clear Target" or "Mark As Target",
        icon = "MagnifyingGlass.png",
        action = function() game:submit({ type = "setTarget", player = human.id, target = not targeted and target.id or nil }) end
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
                    action = function() game:submit({ type = "emoji", player = human.id, target = target.id, icon = icon }) end
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
            game:submit({ type = "warship", player = human.id, tile = tile })
        end
    }
end

function Interaction.pactItem(game, target, items)
    local human = game.human
    local pact = human.pacts[target.id]
    if pact then
        local ending = pact.endsTick ~= nil
        local left = (pact.endsTick or pact.expires) - game.tick
        items[#items + 1] = {
            label = ending and "Pact Ending" or "End Pact",
            icon = "Key.png",
            color = { 1, 0.75, 0.3, 1 },
            disabled = ending,
            sublabel = Format.time(math.max(0, left), Config.tickRate),
            sublabelColor = { 0.55, 0.6, 0.7, 1 },
            action = function() game:submit({ type = "pactEnd", player = human.id, target = target.id }) end
        }
        return
    end
    local pending = target.pactRequests[human.id] ~= nil
    local incoming = human.pactRequests[target.id] ~= nil
    items[#items + 1] = {
        label = incoming and "Accept Pact" or "Propose Pact",
        icon = "Key.png",
        color = { 0.55, 0.75, 1, 1 },
        disabled = pending,
        sublabel = pending and "Pending" or "Non-aggression",
        sublabelColor = { 0.55, 0.6, 0.7, 1 },
        action = function()
            if incoming then
                game:submit({ type = "pactReply", player = human.id, from = target.id, accept = true })
            else
                game:submit({ type = "pactRequest", player = human.id, target = target.id })
            end
        end
    }
end

function Interaction.loanItems(game, target, items)
    local human = game.human
    local owed = Loans.between(game, target, human)
    if owed then
        local left = Loans.remaining(owed)
        items[#items + 1] = {
            label = "Repay Loan",
            icon = "Cash2.png",
            color = { 1, 0.82, 0.25, 1 },
            disabled = human.gold < 1,
            sublabel = Format.number(math.min(left, human.gold)) .. " / " .. Format.number(left),
            action = function() game:submit({ type = "loanRepay", player = human.id, target = target.id }) end
        }
        return
    end
    local lent = Loans.between(game, human, target)
    if lent then
        items[#items + 1] = {
            label = "Owes You",
            icon = "Cash2.png",
            disabled = true,
            sublabel = Format.number(Loans.remaining(lent)) .. "  " .. Format.time(math.max(0, lent.deadline - game.tick), Config.tickRate)
        }
    end
    items[#items + 1] = {
        label = "Request Loan",
        icon = "Cash.png",
        submenu = function()
            local list = {}
            for _, amount in ipairs(Config.loanAmounts) do
                local ok, reason = Loans.canRequest(game, human, target, amount)
                list[#list + 1] = {
                    label = Format.number(amount) .. " gold",
                    icon = "Coin.png",
                    disabled = not ok,
                    sublabel = ok and ("repay in " .. Format.time(Config.loanTicks, Config.tickRate)) or reason,
                    sublabelColor = not ok and { 0.95, 0.35, 0.3, 1 } or { 0.55, 0.6, 0.7, 1 },
                    action = function() game:submit({ type = "loanRequest", player = human.id, target = target.id, amount = amount }) end
                }
            end
            return "LOAN FROM " .. string.upper(target.name), list
        end
    }
end

function Interaction.hotkey(game, action)
    local human = game.human
    if game.phase ~= "playing" or not human.alive then return end
    if action.group == "nuke" then
        game.buildAim = nil
        if human:unitCount("silo") == 0 then
            game:addEvent("Cannot launch " .. action.label .. ": Needs silo.", { color = { 0.95, 0.35, 0.3, 1 } })
        elseif game.nukeAim and game.nukeAim.kind == action.kind then
            Interaction.cancelAim(game)
        else
            Interaction.startAim(game, action.kind)
        end
        return
    end
    game.nukeAim = nil
    if game.buildAim and game.buildAim.kind == action.kind then
        game.buildAim = nil
    else
        game.buildAim = { kind = action.kind }
    end
end

function Interaction.buildPreview(game, tile)
    local aim = game.buildAim
    if not aim or not tile or game.phase ~= "playing" or not game.human.alive then return nil end
    local human = game.human
    local ok, reason, target = Units.check(game, human, aim.kind, tile)
    return {
        kind = aim.kind,
        def = Config.units[aim.kind],
        ok = ok,
        reason = reason,
        tile = target or tile,
        mouse = tile,
        cost = Units.cost(game, human, aim.kind)
    }
end

function Interaction.placeBuild(game, tile)
    local aim = game.buildAim
    if not aim then return false end
    local human = game.human
    local def = Config.units[aim.kind]
    local ok, reason = Units.check(game, human, aim.kind, tile)
    if not ok then
        game:addEvent("Cannot build " .. def.label .. ": " .. reason .. ".", { color = { 0.95, 0.35, 0.3, 1 } })
        return true
    end
    game:submit({ type = "build", player = human.id, unit = aim.kind, tile = tile }, { tile = tile })
    if not love.keyboard.isDown("lshift", "rshift") then
        game.buildAim = nil
    end
    return true
end

function Interaction.startAim(game, kind)
    game.nukeAim = { kind = kind }
end

function Interaction.cancelAim(game)
    game.nukeAim = nil
end

function Interaction.fireAim(game, tile)
    local aim = game.nukeAim
    if not aim then return false end
    local human = game.human
    local ok, reason = Nukes.check(game, human, aim.kind, tile)
    if not ok then
        game:addEvent("Cannot launch: " .. reason .. ".", { color = { 0.95, 0.35, 0.3, 1 } })
        return true
    end
    game:submit({ type = "nuke", player = human.id, kind = aim.kind, tile = tile }, { tile = tile })
    game.nukeAim = nil
    return true
end

function Interaction.previewTarget(game, mouseTile)
    if game.phase ~= "playing" or not game.human.alive then return nil end
    local hover = game.nukeHover
    if hover then
        return hover.nuke, hover.tile
    end
    if game.nukeAim and mouseTile then
        return game.nukeAim.kind, mouseTile
    end
    return nil
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
