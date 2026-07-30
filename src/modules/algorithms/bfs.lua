local Heap = require("src.modules.algorithms.heap")

local function bfs(start, goal, isWalkable, map, walk)
    local visited, queue = Heap(), Heap()
    local adjacentOffsets = {
        { x = 0,  y = -1 },
        { x = -1, y = 0 },
        { x = 0,  y = 1 },
        { x = 1,  y = 0 },
        { x = -1, y = -1 },
        { x = 1,  y = -1 },
        { x = -1, y = 1 },
        { x = 1,  y = 1 },
    }
    local nodes = {}
    local cameFrom = {}
    local seq = 0
    local order = {}

    local function getNode(x, y)
        local k = x .. "," .. y
        local node = nodes[k]
        if node == nil then
            if not map:isValidCell(x, y) then
                nodes[k] = false
                return false
            end
            node = map.grid[x][y]
            nodes[k] = node
        end
        return node
    end

    visited.Compare = function(a, b)
        return order[a] < order[b]
    end

    queue.Compare = function(a, b)
        return order[a] < order[b]
    end

    local function push(node)
        seq = seq + 1
        order[node] = seq
        visited:Push(node)
        queue:Push(node)
    end

    local startNode = getNode(start.x, start.y)
    if not startNode then return nil end

    push(startNode)

    local function reconstructPath(node)
        local path = {}
        while node do
            table.insert(path, 1, node)
            node = cameFrom[node]
        end
        return path
    end

    while not queue:Empty() do
        local current = queue:Pop()

        if walk then walk(current) end

        if goal and current == goal then
            return reconstructPath(current)
        end

        for i = 1, #adjacentOffsets do
            local offset = adjacentOffsets[i]
            local ax = current.x + offset.x
            local ay = current.y + offset.y
            local neighbor = getNode(ax, ay)

            if neighbor and not visited:IsIn(neighbor)
               and (not isWalkable or isWalkable(neighbor)) then
                cameFrom[neighbor] = current
                push(neighbor)
            end
        end
    end

    return nil
end

return bfs