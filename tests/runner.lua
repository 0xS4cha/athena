require("src.core.logger")
local ArgParser = require("src.core.args")

local SUITES = {
    "tests.codec_test",
    "tests.hash_test",
    "tests.intents_test",
    "tests.determinism_test",
    "tests.network_test",
    "tests.lobby_test",
    "tests.balance_test"
}

local function run(filter)
    Logger.LogLevel = 0
    local passed, failed = 0, {}
    local started = love.timer.getTime()
    for _, path in ipairs(SUITES) do
        local suite = require(path)
        for _, case in ipairs(suite) do
            local name = path:gsub("^tests%.", "") .. " > " .. case.name
            if not filter or name:find(filter, 1, true) then
                local caseStarted = love.timer.getTime()
                local ok, err = xpcall(case.run, debug.traceback)
                local elapsed = love.timer.getTime() - caseStarted
                if ok then
                    passed = passed + 1
                    print(string.format("  PASS  %s (%.2fs)", name, elapsed))
                else
                    failed[#failed + 1] = { name = name, err = err }
                    print(string.format("  FAIL  %s (%.2fs)\n%s", name, elapsed, err))
                end
            end
        end
    end
    print(string.format("\n%d passed, %d failed in %.1fs", passed, #failed, love.timer.getTime() - started))
    for _, failure in ipairs(failed) do
        print("  failed: " .. failure.name)
    end
    return #failed == 0
end

function love.load(args)
    local parser = ArgParser.new()
    parser:add_argument("filter", { default = nil, type = "value" })
    local flags = parser:parse(args)
    local ok, success = xpcall(run, debug.traceback, flags.filter)
    if not ok then
        print(success)
        success = false
    end
    love.event.quit(success and 0 or 1)
end
