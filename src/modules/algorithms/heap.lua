
local Heap = {}
Heap.__index = Heap

local function findLowest(a, b)
    return a < b
end

local function newHeap(template, compare)
    return setmetatable({
        data = {},
        Compare = compare or findLowest,
        size = 0
    }, template)
end

local function sortUp(heap, index)
    if index <= 1 then return end
    local pIndex = index % 2 == 0 and index / 2 or (index - 1) / 2

    if not heap.Compare(heap.data[pIndex], heap.data[index]) then
        heap.data[pIndex], heap.data[index] = heap.data[index], heap.data[pIndex]
        sortUp(heap, pIndex)
    end
end

local function sortDown(heap, index)
    local leftIndex, rightIndex, minIndex
    leftIndex = index * 2
    rightIndex = leftIndex + 1
    if rightIndex > heap.size then
        if leftIndex > heap.size then return
        else minIndex = leftIndex end
    else
        if heap.Compare(heap.data[leftIndex], heap.data[rightIndex]) then minIndex = leftIndex
        else minIndex = rightIndex end
    end

    if not heap.Compare(heap.data[index], heap.data[minIndex]) then
        heap.data[index], heap.data[minIndex] = heap.data[minIndex], heap.data[index]
        sortDown(heap, minIndex)
    end
end

function Heap:Empty()
    return self.size == 0
end

function Heap:Clear()
    self.data, self.size, self.Compare = {}, 0, self.Compare or findLowest
    return self
end

function Heap:Push(item)
    if item then
        self.size = self.size + 1
        self.data[self.size] = item
        sortUp(self, self.size)
    end
    return self
end

function Heap:IsIn(item)
    if self.size > 0 then
        for i = 1, self.size do
            if item == self.data[i] then
                return true
            end
        end
    end
    return false
end

function Heap:Pop()
    local root
    if self.size > 0 then
        root = self.data[1]
        self.data[1] = self.data[self.size]
        self.data[self.size] = nil
        self.size = self.size - 1
        if self.size > 1 then
            sortDown(self, 1)
        end
    end
    return root
end

return setmetatable(Heap, { __call = function(self, ...) return newHeap(self, ...) end })