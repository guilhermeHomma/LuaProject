local EnemyRepulsion = {}

local DEFAULT_RADIUS = 18
local DEFAULT_FORCE = 10
local DEFAULT_SAMPLE_INTERVAL = 0.055
local DEFAULT_STEER_RADIUS = 20
local DEFAULT_STEER_FORCE = 1.35

local function isRushingBigZombie(enemy)
    return enemy
        and enemy.enemyTypeId == "bigZombie"
        and (enemy.rushState == "rushing" or enemy.rushState == "rushEnding")
end

function EnemyRepulsion.getVector(enemy)
    if not enemy or enemy.isAlive == false or isRushingBigZombie(enemy) then
        return 0, 0
    end

    local now = love.timer.getTime()
    if enemy.nextRepulsionSampleTime and now < enemy.nextRepulsionSampleTime then
        return enemy.cachedRepulseX or 0, enemy.cachedRepulseY or 0
    end

    local radius = enemy.enemyRepulsionRadius or DEFAULT_RADIUS
    local enemies = Game and Game.getEnemiesNearPoint and Game:getEnemiesNearPoint(enemy.x, enemy.y, radius)
        or (Game and Game.enemies)
        or {}
    local repulseX, repulseY = 0, 0

    for _, other in ipairs(enemies) do
        if other ~= enemy and other.isAlive ~= false and other.x and other.y then
            local dx = enemy.x - other.x
            local dy = enemy.y - other.y
            local distSq = dx * dx + dy * dy
            local minDist = math.max(radius, (enemy.size or 7) + (other.size or 7) + 5)

            if distSq > 0.001 and distSq < minDist * minDist then
                local dist = math.sqrt(distSq)
                local strength = (minDist - dist) / minDist
                local otherWeight = other.enemyRepulsionWeight or 1

                repulseX = repulseX + (dx / dist) * strength * otherWeight
                repulseY = repulseY + (dy / dist) * strength * otherWeight
            elseif distSq <= 0.001 then
                local angle = ((enemy.drawPriority or 0.5) + (other.drawPriority or 0.5)) * math.pi * 2
                repulseX = repulseX + math.cos(angle) * 0.35
                repulseY = repulseY + math.sin(angle) * 0.35
            end
        end
    end

    enemy.cachedRepulseX = repulseX
    enemy.cachedRepulseY = repulseY
    enemy.nextRepulsionSampleTime = now
        + (enemy.repulsionSampleInterval or DEFAULT_SAMPLE_INTERVAL)
        + (enemy.drawPriority or 0) * 0.02
    return repulseX, repulseY
end

function EnemyRepulsion.applyToVelocity(enemy, velocityX, velocityY, force)
    local repulseX, repulseY = EnemyRepulsion.getVector(enemy)
    return velocityX + repulseX * (force or enemy.enemyRepulsionForce or DEFAULT_FORCE),
        velocityY + repulseY * (force or enemy.enemyRepulsionForce or DEFAULT_FORCE)
end

function EnemyRepulsion.steerVelocity(enemy, velocityX, velocityY, steerForce)
    if not enemy or enemy.isAlive == false or isRushingBigZombie(enemy) then
        return velocityX, velocityY
    end

    local velocityLength = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if velocityLength <= 0.001 then
        return velocityX, velocityY
    end

    local dirX = velocityX / velocityLength
    local dirY = velocityY / velocityLength
    local radius = enemy.enemyAvoidanceRadius or enemy.enemyRepulsionRadius or DEFAULT_STEER_RADIUS
    local enemies = Game and Game.getEnemiesNearPoint and Game:getEnemiesNearPoint(enemy.x, enemy.y, radius)
        or (Game and Game.enemies)
        or {}
    local steerX, steerY = 0, 0

    for _, other in ipairs(enemies) do
        if other ~= enemy and other.isAlive ~= false and other.x and other.y then
            local toOtherX = other.x - enemy.x
            local toOtherY = other.y - enemy.y
            local distSq = toOtherX * toOtherX + toOtherY * toOtherY
            local avoidDistance = math.max(
                radius,
                (enemy.size or 7) * 0.5 + (other.size or 7) * 0.5 + 9
            )

            if distSq > 0.001 and distSq < avoidDistance * avoidDistance then
                local dist = math.sqrt(distSq)
                local otherDirX = toOtherX / dist
                local otherDirY = toOtherY / dist
                local towardAmount = dirX * otherDirX + dirY * otherDirY

                if towardAmount > 0.18 then
                    local strength = ((avoidDistance - dist) / avoidDistance) * towardAmount
                    local sideSeed = ((enemy.drawPriority or 0.5) > (other.drawPriority or 0.5)) and 1 or -1
                    local tangentX = -otherDirY * sideSeed
                    local tangentY = otherDirX * sideSeed

                    steerX = steerX - otherDirX * strength * 0.75 + tangentX * strength
                    steerY = steerY - otherDirY * strength * 0.75 + tangentY * strength
                end
            end
        end
    end

    if steerX == 0 and steerY == 0 then
        return velocityX, velocityY
    end

    local force = steerForce or enemy.enemyAvoidanceForce or DEFAULT_STEER_FORCE
    return velocityX + steerX * velocityLength * force,
        velocityY + steerY * velocityLength * force
end

return EnemyRepulsion
