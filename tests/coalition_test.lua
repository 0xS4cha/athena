local Config = require("src.config.game")
local Coalitions = require("src.modules.game.systems.coalitions")
local Intents = require("src.net.intents")
local Snapshot = require("src.net.snapshot")
local T = require("tests.helpers")

local function threeEmpires()
    local game = T.game({ bots = 0, nations = false, humans = { { name = "A" }, { name = "B" }, { name = "C" } } })
    for _ = 1, 160 do game:step() end
    for id = 1, 3 do
        game:pushIntent({ type = "attack", player = id, target = 0, ratio = 1 })
    end
    for _ = 1, 200 do game:step() end
    local players = { game.players[1], game.players[2], game.players[3] }
    table.sort(players, function(a, b) return a.tiles > b.tiles end)
    return game, players[1], players[2], players[3]
end

local function run(game, ticks)
    for _ = 1, ticks or 10 do game:step() end
end

return {
    {
        name = "coalitions target the dominant nation and bind their members",
        run = function()
            local game, leader, founder, recruit = threeEmpires()
            T.expect(Coalitions.canFound(game, founder, "war", leader), "coalition against the leader")
            local _, reason = Coalitions.canFound(game, leader, "war", recruit)
            T.equal(reason, "Not dominant", "coalition against a small nation")

            game:pushIntent({ type = "coalitionFound", player = founder.id, kind = "war", target = leader.id })
            run(game, 1)
            local coalition = T.expect(Coalitions.of(game, founder), "coalition founded")
            T.equal(coalition.target, leader, "coalition target")
            T.equal(Coalitions.attackModifier(game, founder, leader), 1, "no bonus for a lonely founder")

            game:pushIntent({ type = "coalitionInvite", player = founder.id, target = recruit.id })
            run(game, 1)
            T.expect(recruit.coalitionInvites[coalition.id], "invitation received")
            game:pushIntent({ type = "coalitionReply", player = recruit.id, coalition = coalition.id, accept = true })
            run(game, 1)
            T.equal(recruit.coalition, coalition.id, "recruit joined")
            T.expect(founder:isAlliedWith(recruit), "members are allied")

            local bonus = (1 - Config.coalitionAttackBonus) * (1 + Config.coalitionTargetDefense)
            T.expect(math.abs(Coalitions.attackModifier(game, founder, leader) - bonus) < 1e-9, "member attack bonus")
            T.expect(math.abs(Coalitions.attackModifier(game, nil, leader) - (1 + Config.coalitionTargetDefense)) < 1e-9, "target defense bonus")

            founder.allies[recruit.id] = game.tick
            recruit.allies[founder.id] = game.tick
            run(game, 20)
            T.expect(founder:isAlliedWith(recruit), "coalition alliances do not expire")

            game:pushIntent({ type = "coalitionLeave", player = recruit.id })
            run(game, 1)
            T.equal(recruit.coalition, nil, "recruit left")
            T.expect(recruit.traitorUntil > game.tick, "deserting a war makes a traitor")
            T.expect(not founder:isAlliedWith(recruit), "deserter loses the alliance")
            T.expect(Coalitions.of(game, founder), "the war coalition survives")

            game:eliminate(leader)
            run(game, 20)
            T.equal(#game.coalitions, 0, "coalition dissolved once its target falls")
            T.equal(founder.coalition, nil, "founder released")
        end
    },
    {
        name = "coalition intents are validated by the server",
        run = function()
            local game, leader, founder, recruit = threeEmpires()
            local _, reason = Intents.sanitize(game, leader.id, { type = "coalitionFound", kind = "war", target = recruit.id })
            T.equal(reason, "Not dominant", "war on a small nation")
            _, reason = Intents.sanitize(game, founder.id, { type = "coalitionLeave" })
            T.equal(reason, "No coalition", "leave without coalition")
            _, reason = Intents.sanitize(game, founder.id, { type = "coalitionFound", kind = "empire", target = leader.id })
            T.equal(reason, "Invalid kind", "unknown coalition kind")
            _, reason = Intents.sanitize(game, founder.id, { type = "coalitionInvite", target = recruit.id })
            T.equal(reason, "No coalition", "invite without coalition")
        end
    },
    {
        name = "coalitions survive a snapshot",
        run = function()
            local game, leader, founder, recruit = threeEmpires()
            game:pushIntent({ type = "coalitionFound", player = recruit.id, kind = "defense", target = founder.id })
            run(game, 1)
            local coalition = T.expect(Coalitions.of(game, recruit), "defensive coalition founded")
            game:pushIntent({ type = "coalitionReply", player = founder.id, coalition = coalition.id, accept = true })
            run(game, 1)
            local client = T.game({ bots = 0, nations = false, humans = { { name = "A" }, { name = "B" }, { name = "C" } }, authority = false })
            T.applySnapshot(client, Snapshot.encode(game))
            local copy = T.expect(Coalitions.of(client, client.players[founder.id]), "coalition restored")
            T.equal(copy.name, coalition.name, "coalition name")
            T.equal(#copy.members, 2, "coalition members")
            T.equal(copy.leader, client.players[recruit.id], "coalition leader")
            T.equal(client:checksum(), game:checksum(), "checksum after snapshot")
        end
    }
}
