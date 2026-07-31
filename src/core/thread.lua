local threads = {}

local function Wait(ms)
    local resumeAt = love.timer.getTime() + ms / 1000
    local co = coroutine.running()
    love.timer.sleep(0)
    coroutine.yield(resumeAt)
end

local function CreateThread(fn)
    local co = coroutine.create(fn)
    table.insert(threads, { co = co, resumeAt = 0 })
    return co
end

local function updateScheduler()
    local now = love.timer.getTime()
    for i = #threads, 1, -1 do
        local t = threads[i]
        if t.co and coroutine.status(t.co) == "suspended" then
            if now >= t.resumeAt then
                local ok, nextResumeAt = coroutine.resume(t.co)
                if not ok then
                    print("Thread error:", nextResumeAt)
                    table.remove(threads, i)
                else
                    if type(nextResumeAt) == "number" then
                        t.resumeAt = nextResumeAt
                    else
                        t.resumeAt = 0
                    end
                end
            end
        else
            table.remove(threads, i)
        end
    end
end

return {
    CreateThread = CreateThread,
    Wait = Wait,
    updateScheduler = updateScheduler,
}