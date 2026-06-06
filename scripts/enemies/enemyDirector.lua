local EnemyDirector = {}

local Tilemap = require("scripts/tilemap")

local tileSize = 16
local pathfindingDistanceTiles = 20
local minPathRequestsPerFrame = 2
local maxPathRequestsPerFrame = 5

function EnemyDirector:isPlayerAlive()
    return Player and Player.isAlive
end

function EnemyDirector:getPathfindingDistance()
    return pathfindingDistanceTiles * tileSize
end

function EnemyDirector:beginFrame(enemyCount)
    enemyCount = enemyCount or #(Game and Game.enemies or {})
    self.pathRequestsThisFrame = 0
    self.pathRequestBudget = math.max(
        minPathRequestsPerFrame,
        math.min(maxPathRequestsPerFrame, math.floor(enemyCount / 8) + 1)
    )
end

function EnemyDirector:canRequestPath()
    self.pathRequestsThisFrame = self.pathRequestsThisFrame or 0
    self.pathRequestBudget = self.pathRequestBudget or maxPathRequestsPerFrame
    return self.pathRequestsThisFrame < self.pathRequestBudget
end

function EnemyDirector:requestPath(startX, startY, targetX, targetY)
    local path, cacheHit = Tilemap:getPathBetweenWorldPoints(startX, startY, targetX, targetY, { cacheOnly = true })
    if cacheHit then
        return path, true
    end

    if not self:canRequestPath() then
        return nil, false
    end

    self.pathRequestsThisFrame = (self.pathRequestsThisFrame or 0) + 1
    path = Tilemap:getPathBetweenWorldPoints(startX, startY, targetX, targetY)
    return path, true
end

function EnemyDirector:shouldUsePathfinding(enemy)
    if not (enemy and self:isPlayerAlive()) then
        return false
    end

    local dx = (enemy.x or 0) - Player.x
    local dy = (enemy.y or 0) - Player.y
    local maxDistance = self:getPathfindingDistance()
    return dx * dx + dy * dy <= maxDistance * maxDistance
end

function EnemyDirector:getRandomRoamTarget(enemy, options)
    if not enemy then
        return nil, nil
    end

    options = options or {}
    local minRadius = options.minRadius or enemy.roamRadiusMin or tileSize * 2
    local maxRadius = options.maxRadius or enemy.roamRadiusMax or tileSize * 6
    local attempts = options.attempts or 5

    for _ = 1, attempts do
        local angle = math.random() * math.pi * 2
        local radius = minRadius + math.random() * (maxRadius - minRadius)
        local targetX = enemy.x + math.cos(angle) * radius
        local targetY = enemy.y + math.sin(angle) * radius

        if Tilemap.getNearestWalkableWorldPosition then
            local walkX, walkY = Tilemap:getNearestWalkableWorldPosition(targetX, targetY, 3)
            if walkX and walkY then
                return walkX, walkY
            end
        else
            return targetX, targetY
        end
    end

    return enemy.x, enemy.y
end

function EnemyDirector:configureRandomRoam(enemy, duration)
    local targetX, targetY = self:getRandomRoamTarget(enemy)
    if targetX and targetY and enemy.setRoamTarget then
        enemy:setRoamTarget(targetX, targetY, duration or (1.4 + math.random() * 1.8))
    end
    return targetX, targetY
end

return EnemyDirector
