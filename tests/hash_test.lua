local Hash = require("src.core.hash")
local T = require("tests.helpers")

return {
    {
        name = "toggle is its own inverse",
        run = function()
            local h = 0
            for i = 1, 1000 do h = Hash.toggle(h, i * 7919, i % 13 + 1) end
            for i = 1000, 1, -1 do h = Hash.toggle(h, i * 7919, i % 13 + 1) end
            T.equal(h, 0, "hash after undoing every toggle")
        end
    },
    {
        name = "toggle does not depend on the order of ownership changes",
        run = function()
            local a, b = 0, 0
            for i = 1, 200 do a = Hash.toggle(a, i, 3) end
            for i = 200, 1, -1 do b = Hash.toggle(b, i, 3) end
            T.equal(a, b, "order independent hash")
        end
    },
    {
        name = "combine is stable and stays within 32 bits",
        run = function()
            local h = Hash.combine(Hash.combine(0, 12345), -42)
            T.equal(h, Hash.combine(Hash.combine(0, 12345), -42), "deterministic combine")
            T.expect(h >= 0 and h < 2 ^ 32, "unsigned 32-bit value")
            T.expect(Hash.combine(0, 1) ~= Hash.combine(0, 2), "different inputs collide")
        end
    }
}
