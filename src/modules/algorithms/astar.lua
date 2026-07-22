local Heap = require("src.modules.algorithms.heap")

local function astar(start, goal, isWalkable, map)
    local result = {}
    local function key(pos)
        return pos.x .. "," .. pos.y
    end

    local function heuristic(a, b)
        local dx = a.x - b.x
        local dy = a.y - b.y
        return math.sqrt(dx * dx + dy * dy) + a.data.magnitude + b.data.magnitude
    end
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

    local function getNode(x, y)
        local k = x .. "," .. y
        local node = nodes[k]
        if not node then
            node = map.grid[x][y]
            nodes[k] = node
        end
        return node
    end

    local startNode = getNode(start.x, start.y)
    local goalNode = getNode(goal.x, goal.y)

    startNode.gScore = 0
    startNode.hScore = heuristic(startNode, goalNode)
    startNode.fScore = startNode.hScore

    local open, closed = Heap(), {}

    open.Compare = function(a, b)
        return a.fScore < b.fScore
    end

    open:Push(startNode)

    while not open:Empty() do
        local current = open:Pop()
        local currentKey = key(current)

        if not closed[currentKey] then
            if current == goal then
                local path = {}
                while current do
                    table.insert(path, 1, map.grid[current.x][current.y])
                    current = current.previous
                end
                result = path
                return result
            end

            closed[currentKey] = true

            for i = 1, #adjacentOffsets do
                local offset = adjacentOffsets[i]
                local ax, ay = current.x, current.y
                if current.x > 1 then
                    ax = current.x + offset.x
                end
                if current.y > 1 then
                    ay = current.y + offset.y 
                end
                local adjKey = ax .. "," .. ay

                if not closed[adjKey] and (not isWalkable or isWalkable(getNode(ax, ay))) then
                    local adjacent = getNode(ax, ay)
                    local tentativeGScore = current.gScore + adjacent.data.magnitude

                    if not adjacent.gScore or tentativeGScore < adjacent.gScore then
                        adjacent.gScore = tentativeGScore
                        if not adjacent.hScore then
                            adjacent.hScore = heuristic(adjacent, goalNode)
                        end
                        adjacent.fScore = adjacent.gScore + adjacent.hScore
                        adjacent.previous = current

                        open:Push(adjacent)
                    end
                end
            end
        end
    end

    return nil
end

return astar