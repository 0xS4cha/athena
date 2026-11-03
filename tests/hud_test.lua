local BuildBar = require("src.modules.hud.components.buildbar")
local Keybinds = require("src.modules.input.keybinds")
local Units = require("src.modules.game.systems.units")
local Tutorial = require("src.modules.hud.components.tutorial")
local T = require("tests.helpers")

local function tutorialHud(options)
    local base = { bots = 6, nations = false, tutorial = true, map = "assets/maps/iceland/", humans = { { name = "A" } }, localSlot = 1 }
    for k, v in pairs(options or {}) do base[k] = v end
    local game = T.game(base)
    return { game = function() return game end }, game
end

local function stepIndex(title)
    for k, step in ipairs(Tutorial.steps) do
        if step.title == title then return k end
    end
    error("no step " .. title)
end

local function find(list, kind)
    for _, entry in ipairs(list) do
        if entry.kind == kind then return entry end
    end
end

return {
    {
        name = "the build bar lists the bound buildings and what can be paid",
        run = function()
            local game = T.game({ bots = 0, nations = false })
            local human = game.players[1]
            game.human = human
            local city = "build:city"
            local list = BuildBar.entries(game)
            T.equal(find(list, "atom"), nil, "nukes are not buildings")
            T.equal(find(list, "city").key, Keybinds.label(Keybinds.get(city)), "shows the bound key")

            human.gold = Units.cost(game, human, "city") - 1
            T.expect(not find(BuildBar.entries(game), "city").affordable, "too expensive")
            human.gold = Units.cost(game, human, "city")
            T.expect(find(BuildBar.entries(game), "city").affordable, "affordable")

            T.expect(not find(BuildBar.entries(game), "city").active, "not armed")
            game.buildAim = { kind = "city" }
            T.expect(find(BuildBar.entries(game), "city").active, "armed")
            T.expect(not find(BuildBar.entries(game), "farm").active, "another building is not armed")
        end
    },
    {
        name = "a game without nukes hides the nuclear buildings from the build bar",
        run = function()
            local game = T.game({ bots = 0, nations = false, rules = { mode = "conventional" } })
            game.human = game.players[1]
            T.equal(find(BuildBar.entries(game), "silo"), nil, "no silo")
            T.expect(find(BuildBar.entries(game), "city"), "cities stay")
        end
    },
    {
        name = "every tutorial step can be completed or read, and ends on the final one",
        run = function()
            local chapters = {}
            for k, step in ipairs(Tutorial.steps) do
                T.expect(step.chapter and step.title and step.text, "step " .. k .. " is described")
                chapters[step.chapter] = true
                if k < #Tutorial.steps then
                    T.expect((step.done ~= nil) ~= (step.info == true), step.title .. " waits for an action or for a click")
                end
            end
            T.expect(chapters.BASICS and chapters.ECONOMY and chapters.WAR and chapters.WORLD, "all chapters")
            T.expect(Tutorial.steps[#Tutorial.steps].final, "last step")

            local hud = tutorialHud()
            for _ = 1, #Tutorial.steps - 1 do Tutorial.next(hud) end
            T.equal(hud.tutorial.step, #Tutorial.steps, "reached the end")
            Tutorial.update(hud)
            T.equal(hud.tutorial.closed, false, "still open on the last step")
            Tutorial.next(hud)
            T.expect(hud.tutorial.closed, "finish closes it")
            T.expect(not Tutorial.visible(hud), "hidden once closed")
        end
    },
    {
        name = "tutorial steps advance on their own, wait on info steps and stay put after going back",
        run = function()
            local seconds = Tutorial.advanceSeconds
            Tutorial.advanceSeconds = 0
            local hud, game = tutorialHud()
            local map = game.map
            game:pushIntent({ type = "spawn", player = 1, tile = map:findNear(map.width / 2, map.height / 2, 300, function(i) return map:isLand(i) and map.owner[i] == 0 end) })
            game:step()
            Tutorial.update(hud)
            Tutorial.update(hud)
            T.equal(hud.tutorial.step, 2, "spawning completes the first step")

            hud.tutorial.step = stepIndex("Govern your land")
            Tutorial.update(hud)
            Tutorial.update(hud)
            T.equal(hud.tutorial.step, stepIndex("Govern your land"), "an info step waits for a click")
            Tutorial.next(hud)
            T.equal(hud.tutorial.step, stepIndex("Attack a tribe"), "next")

            hud.tutorial.step = 2
            Tutorial.previous(hud)
            Tutorial.update(hud)
            Tutorial.update(hud)
            T.equal(hud.tutorial.step, 1, "a finished step does not skip itself after going back")
            Tutorial.previous(hud)
            T.equal(hud.tutorial.step, 1, "no step before the first")
            Tutorial.advanceSeconds = seconds
        end
    },
    {
        name = "tutorial markers point at wilderness, tribes, home and coast",
        run = function()
            local hud, game = tutorialHud()
            local map = game.map
            local land = map:findNear(map.width / 2, map.height / 2, 300, function(i) return map:isLand(i) and map.owner[i] == 0 end)
            T.equal(Tutorial.markerTile(hud), nil, "nothing before the spawn")
            game:pushIntent({ type = "spawn", player = 1, tile = land })
            for _ = 1, 10 do game:step() end
            game.spawnTicksLeft = 1
            game:step()

            local tutorial = hud.tutorial
            local function markerOf(title)
                local step = Tutorial.steps[stepIndex(title)]
                return step.marker(game)
            end
            T.expect(tutorial, "state")
            local wild = T.expect(markerOf("Expand"), "wilderness")
            T.expect(map:isLand(wild) and map.owner[wild] == 0, "free land")
            local tribe = T.expect(markerOf("Attack a tribe"), "tribe")
            T.expect(game.players[map.owner[tribe]]:isBot(), "a tribe owns it")
            T.equal(map.owner[T.expect(markerOf("Build a city"), "home")], game.human.id, "own land")
            local coast = markerOf("Reach the sea")
            T.expect(coast == nil or map:isCoast(coast), "a coast or nothing inland")
        end
    },
    {
        name = "the tutorial starts with enough gold for a city and a military port",
        run = function()
            local _, game = tutorialHud()
            local map = game.map
            local land = map:findNear(map.width / 2, map.height / 2, 300, function(i) return map:isLand(i) and map.owner[i] == 0 end)
            game:pushIntent({ type = "spawn", player = 1, tile = land })
            game:step()
            local human = game.players[1]
            T.expect(human.gold >= Units.cost(game, human, "city") + Units.cost(game, human, "militaryPort"), "enough gold")
        end
    }
}
