local GM = require("src.core.index")
local bfs = require("src.modules.algorithms.bfs")
local uuid = require("src.core.uuid")

GM.Battalions = {}
GM.Battalions.List = {}
GM.Battalions.citizens = 50
GM.Battalions.soldiers = 20

GM.Modules:Register("Battalions", 70)

function GM.Battalions:Initialize()
    self.List = {}
    self.citizens = 50
    self.soldiers = 20
end

function GM.Battalions:Spawn(x, y, count)
    local bat = {
        id = uuid.getUUID(),
        x = x,
        y = y,
        soldiers = count,
        selected = false,
        moving = false,
        moveTimer = 0
    }
    table.insert(self.List, bat)
    return bat
end

function GM.Battalions:Split(bat)
    if bat.soldiers < 2 then return end
    local count1 = math.ceil(bat.soldiers / 2)
    local count2 = bat.soldiers - count1
    bat.soldiers = count1

    local map = GM.Game.Map
    local neighbors = {
        { x = bat.x - 1, y = bat.y },
        { x = bat.x + 1, y = bat.y },
        { x = bat.x,     y = bat.y - 1 },
        { x = bat.x,     y = bat.y + 1 }
    }
    local spawnX, spawnY = bat.x, bat.y
    for _, n in ipairs(neighbors) do
        if map:isValidCell(n.x, n.y) then
            local cell = map.grid[n.x][n.y]
            if cell.data.isLand and not cell.data.isImpassable then
                spawnX, spawnY = n.x, n.y
                break
            end
        end
    end
    self:Spawn(spawnX, spawnY, count2)
end

function GM.Battalions:Think(dt)
    dt = dt or love.timer.getDelta()

    local diplomacy = GM.Hud and GM.Hud.Instance and GM.Hud.Instance.powerAllocation.diplomacy or 33
    self.citizens = self.citizens + dt * (0.2 + 0.8 * (diplomacy / 100))

    local army = GM.Hud and GM.Hud.Instance and GM.Hud.Instance.powerAllocation.army or 33
    local recruitRate = dt * (0.1 + 0.9 * (army / 100))
    local recruited = math.min(self.citizens, recruitRate)
    self.citizens = self.citizens - recruited
    self.soldiers = self.soldiers + recruited

    local moveSpeedMultiplier = 0.2 + (army / 100) * 1.5
    for i = #self.List, 1, -1 do
        local bat = self.List[i]
        if bat.soldiers <= 0 then
            table.remove(self.List, i)
        elseif bat.moving and bat.path then
            bat.moveTimer = bat.moveTimer + dt * moveSpeedMultiplier
            if bat.moveTimer >= 1.0 then
                bat.moveTimer = 0
                bat.pathIndex = bat.pathIndex + 1
                if bat.pathIndex > #bat.path then
                    bat.moving = false
                    bat.path = nil
                    bat.x = bat.targetX
                    bat.y = bat.targetY
                else
                    bat.x = bat.path[bat.pathIndex].x
                    bat.y = bat.path[bat.pathIndex].y
                end
            end
        end
    end

    for i = #self.List, 1, -1 do
        local b1 = self.List[i]
        for j = i - 1, 1, -1 do
            local b2 = self.List[j]
            local dx = b1.x - b2.x
            local dy = b1.y - b2.y
            if dx * dx + dy * dy < 0.1 then
                b2.soldiers = b2.soldiers + b1.soldiers
                if b1.selected then b2.selected = true end
                table.remove(self.List, i)
                break
            end
        end
    end
end

function GM.Battalions:Draw()
    if not GM.Game or not GM.Game.Map then return end
    local map = GM.Game.Map
    local cellSize = map.cellSize

    local wx, wy = GM.Building:GetWorldMouse()

    local function drawPixel(gx, gy, pr, pg, pb, pa)
        love.graphics.setColor(pr, pg, pb, pa or 1)
        love.graphics.rectangle("fill", (gx - 1) * cellSize, (gy - 1) * cellSize, cellSize, cellSize)
    end

    for _, bat in ipairs(self.List) do
        local px = (bat.x - 0.5) * cellSize
        local py = (bat.y - 0.5) * cellSize

        if bat.selected then
            drawPixel(bat.x - 3, bat.y - 3, 1, 1, 0)
            drawPixel(bat.x - 2, bat.y - 3, 1, 1, 0)
            drawPixel(bat.x - 3, bat.y - 2, 1, 1, 0)

            drawPixel(bat.x + 3, bat.y - 3, 1, 1, 0)
            drawPixel(bat.x + 2, bat.y - 3, 1, 1, 0)
            drawPixel(bat.x + 3, bat.y - 2, 1, 1, 0)

            drawPixel(bat.x - 3, bat.y + 3, 1, 1, 0)
            drawPixel(bat.x - 2, bat.y + 3, 1, 1, 0)
            drawPixel(bat.x - 3, bat.y + 2, 1, 1, 0)

            drawPixel(bat.x + 3, bat.y + 3, 1, 1, 0)
            drawPixel(bat.x + 2, bat.y + 3, 1, 1, 0)
            drawPixel(bat.x + 3, bat.y + 2, 1, 1, 0)

            if bat.pathPreview then
                love.graphics.setLineWidth(2)
                love.graphics.setColor(0.1, 0.8, 0.3, 0.7)
                for k = 1, #bat.pathPreview - 1 do
                    local c1 = bat.pathPreview[k]
                    local c2 = bat.pathPreview[k + 1]
                    love.graphics.line((c1.x - 0.5) * cellSize, (c1.y - 0.5) * cellSize, (c2.x - 0.5) * cellSize,
                        (c2.y - 0.5) * cellSize)
                end

                local tpx = bat.potentialTarget.x
                local tpy = bat.potentialTarget.y
                local dist = math.sqrt((wx - tpx) ^ 2 + (wy - tpy) ^ 2)
                local ar, ag, ab = 0.1, 0.7, 0.3
                if dist <= 1.2 then
                    ar, ag, ab = 0.1, 0.9, 0.4
                end

                drawPixel(tpx - 1, tpy - 3, ar, ag, ab)
                drawPixel(tpx, tpy - 3, ar, ag, ab)
                drawPixel(tpx + 1, tpy - 3, ar, ag, ab)
                drawPixel(tpx - 2, tpy - 2, ar, ag, ab)
                drawPixel(tpx + 2, tpy - 2, ar, ag, ab)
                drawPixel(tpx - 3, tpy - 1, ar, ag, ab)
                drawPixel(tpx + 3, tpy - 1, ar, ag, ab)
                drawPixel(tpx - 3, tpy, ar, ag, ab)
                drawPixel(tpx + 3, tpy, ar, ag, ab)
                drawPixel(tpx - 3, tpy + 1, ar, ag, ab)
                drawPixel(tpx + 3, tpy + 1, ar, ag, ab)
                drawPixel(tpx - 2, tpy + 2, ar, ag, ab)
                drawPixel(tpx + 2, tpy + 2, ar, ag, ab)
                drawPixel(tpx - 1, tpy + 3, ar, ag, ab)
                drawPixel(tpx, tpy + 3, ar, ag, ab)
                drawPixel(tpx + 1, tpy + 3, ar, ag, ab)

                drawPixel(tpx, tpy, 1, 1, 1)
                drawPixel(tpx, tpy + 1, 1, 1, 1)
                drawPixel(tpx, tpy - 1, 1, 1, 1)
                drawPixel(tpx, tpy, 1, 1, 1)
                drawPixel(tpx + 1, tpy, 1, 1, 1)
                drawPixel(tpx - 1, tpy, 1, 1, 1)
            end
        end

        local r, g, b = 0.2, 0.45, 0.8
        if GM.PlayerCountry then
            r = GM.PlayerCountry.color[1] / 255
            g = GM.PlayerCountry.color[2] / 255
            b = GM.PlayerCountry.color[3] / 255
        end

        drawPixel(bat.x - 1, bat.y - 1, 0, 0, 0)
        drawPixel(bat.x + 1, bat.y - 1, 0, 0, 0)
        drawPixel(bat.x - 1, bat.y + 1, 0, 0, 0)
        drawPixel(bat.x + 1, bat.y + 1, 0, 0, 0)
        drawPixel(bat.x - 2, bat.y, 0, 0, 0)
        drawPixel(bat.x + 2, bat.y, 0, 0, 0)
        drawPixel(bat.x, bat.y - 2, 0, 0, 0)
        drawPixel(bat.x, bat.y + 2, 0, 0, 0)

        drawPixel(bat.x, bat.y, r, g, b)
        drawPixel(bat.x - 1, bat.y, r, g, b)
        drawPixel(bat.x + 1, bat.y, r, g, b)
        drawPixel(bat.x, bat.y - 1, r, g, b)
        drawPixel(bat.x, bat.y + 1, r, g, b)
    end
end

function GM.Battalions:MousePressed(x, y, button, istouch, presses)
    if button ~= 1 then return end
    if GM.Hud and GM.Hud.Instance and GM.Hud.Instance:isMouseOver() then return end
    if not GM.Game or not GM.Game.Map then return end

    local map = GM.Game.Map
    local wx, wy = GM.Building:GetWorldMouse()
    local cx = math.floor(wx + 1)
    local cy = math.floor(wy + 1)

    local clickedBattalion = nil
    for _, bat in ipairs(self.List) do
        local dx = wx - bat.x
        local dy = wy - bat.y
        if dx * dx + dy * dy <= 1.44 then
            clickedBattalion = bat
            break
        end
    end

    if clickedBattalion then
        for _, bat in ipairs(self.List) do
            bat.selected = false
        end
        clickedBattalion.selected = true
        return
    end

    local selectedBat = nil
    for _, bat in ipairs(self.List) do
        if bat.selected then
            selectedBat = bat
            break
        end
    end

    if selectedBat then
        if selectedBat.potentialTarget then
            local dx = wx - selectedBat.potentialTarget.x
            local dy = wy - selectedBat.potentialTarget.y
            if dx * dx + dy * dy <= 1.44 then
                selectedBat.path = selectedBat.pathPreview
                selectedBat.pathIndex = 1
                selectedBat.moving = true
                selectedBat.targetX = selectedBat.potentialTarget.x
                selectedBat.targetY = selectedBat.potentialTarget.y
                selectedBat.potentialTarget = nil
                selectedBat.pathPreview = nil
                return
            end
        end

        if map:isValidCell(cx, cy) then
            local cell = map.grid[cx][cy]
            if cell.data.isLand and not cell.data.isImpassable then
                local function isWalkable(c)
                    return c.data and c.data.isLand and not c.data.isImpassable
                end
                local startCell = map.grid[math.floor(selectedBat.x)][math.floor(selectedBat.y)]
                local path = bfs(startCell, cell, isWalkable, map)
                if path then
                    selectedBat.potentialTarget = { x = cx, y = cy }
                    selectedBat.pathPreview = path
                else
                    selectedBat.potentialTarget = nil
                    selectedBat.pathPreview = nil
                end
            end
        end
    end
end
