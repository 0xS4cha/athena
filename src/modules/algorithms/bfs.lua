local function bfs(start, goal, isWalkable, map, walk)
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
    local visited = {}
    local cameFrom = {}

    local function getNode(x, y)
        local row = nodes[x]
        if not row then
            row = {}
            nodes[x] = row
        end
        local node = row[y]
        if node == nil then
            if not map:isValidCell(x, y) then
                row[y] = false
                return false
            end
            node = map.grid[x][y]
            row[y] = node
        end
        return node
    end

    local startNode = getNode(start.x, start.y)
    if not startNode then return nil end

    local queue = { startNode }
    local head, tail = 1, 1
    visited[startNode] = true

    local function reconstructPath(node)
        local path = {}
        while node do
            table.insert(path, 1, node)
            node = cameFrom[node]
        end
        return path
    end

    while head <= tail do
        local current = queue[head]
        head = head + 1

        if walk then walk(current) end

        if goal and current == goal then
            return reconstructPath(current)
        end

        for i = 1, #adjacentOffsets do
            local offset = adjacentOffsets[i]
            local ax = current.x + offset.x
            local ay = current.y + offset.y
            local neighbor = getNode(ax, ay)

            if neighbor and not visited[neighbor]
               and (not isWalkable or isWalkable(neighbor)) then
                visited[neighbor] = true
                cameFrom[neighbor] = current
                tail = tail + 1
                queue[tail] = neighbor
            end
        end
    end

    return nil
end

return bfs