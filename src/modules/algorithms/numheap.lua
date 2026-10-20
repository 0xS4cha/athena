local NumHeap = {}
NumHeap.__index = NumHeap

function NumHeap.new()
    return setmetatable({ size = 0 }, NumHeap)
end

function NumHeap:empty()
    return self.size == 0
end

function NumHeap:push(value)
    local size = self.size + 1
    self.size = size
    local k = size
    while k > 1 do
        local p = (k - k % 2) / 2
        local pv = self[p]
        if pv <= value then break end
        self[k] = pv
        k = p
    end
    self[k] = value
end

function NumHeap:pop()
    local size = self.size
    if size == 0 then return nil end
    local top = self[1]
    local last = self[size]
    self[size] = nil
    size = size - 1
    self.size = size
    if size == 0 then return top end
    local k = 1
    while true do
        local c = k * 2
        if c > size then break end
        local cv = self[c]
        if c < size and self[c + 1] < cv then
            c = c + 1
            cv = self[c]
        end
        if cv >= last then break end
        self[k] = cv
        k = c
    end
    self[k] = last
    return top
end

return NumHeap
