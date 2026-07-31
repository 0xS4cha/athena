--- @param start table|table[]
--- @param goal table?
--- @param isWalkable function?
--- @param map table
--- @param walk function?
--- @return table[]?
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

    local function isCell(t)
        return type(t) == "table"
        and type(t.x) == "number"
        and type(t.y) == "number"
    end

    local function isListOfCells(t)
        return type(t) == "table"
        and #t > 0
        and isCell(t[1])
    end

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

    local queue
    if isListOfCells(start) then
        queue = {}
        for i = 1, #start do
            local startNode = getNode(start[i].x, start[i].y)
            if not startNode then goto continue end
            queue[#queue+1] = startNode
            visited[startNode] = true
            ::continue::
        end
    else
        local startNode = getNode(start.x, start.y)
        if not startNode then return nil end
        queue = {startNode}
        visited[startNode] = true
    end

    local head, tail = 1, #queue

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