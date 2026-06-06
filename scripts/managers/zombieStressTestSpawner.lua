local ZombieStressTestSpawner = {}
ZombieStressTestSpawner.__index = ZombieStressTestSpawner

local Zombie = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")

local defaultConfig = {
    spawnPerSecond = 1,
    maxZombies = 80,
    minPlayerDistance = 170,
    avoidEnemyRadius = 14,
}

local function copyConfig(config)
    local result = {}
    for key, value in pairs(defaultConfig) do
        result[key] = value
    end
    for key, value in pairs(config or {}) do
        result[key] = value
    end
    return result
end

local function isCommonZombie(enemy)
    return enemy and enemy.isAlive ~= false and (enemy.enemyTypeId or "zombie") == "zombie"
end

function ZombieStressTestSpawner:new(config)
    local spawner = setmetatable({}, ZombieStressTestSpawner)
    spawner.config = copyConfig(config)
    spawner.spawnAccumulator = 0
    return spawner
end

function ZombieStressTestSpawner:reset()
    self.spawnAccumulator = 0
end

function ZombieStressTestSpawner:countZombies(game)
    local count = 0
    for _, enemy in ipairs((game and game.enemies) or {}) do
        if isCommonZombie(enemy) then
            count = count + 1
        end
    end
    return count
end

function ZombieStressTestSpawner:getAvoidPoints(game)
    local avoidPoints = {}
    for _, enemy in ipairs((game and game.enemies) or {}) do
        if enemy and enemy.isAlive ~= false and enemy.x and enemy.y then
            avoidPoints[#avoidPoints + 1] = {
                x = enemy.x,
                y = enemy.y,
                radius = self.config.avoidEnemyRadius,
            }
        end
    end
    return avoidPoints
end

function ZombieStressTestSpawner:spawnZombie(game)
    if not (game and game.enemies and Player) then
        return false
    end

    local x, y = Tilemap:getRandomReachableSpawnPosition(
        Player,
        self.config.minPlayerDistance,
        self:getAvoidPoints(game)
    )
    if not x or not y then
        x, y = Tilemap:getRandomSpawnPosition(Player, self.config.minPlayerDistance, self:getAvoidPoints(game))
    end
    if not x or not y then
        return false
    end

    game.enemies[#game.enemies + 1] = Zombie:new(x, y)
    return true
end

function ZombieStressTestSpawner:update(game, dt)
    if not (game and dt and dt > 0) then
        return
    end

    local currentCount = self:countZombies(game)
    local maxZombies = self.config.maxZombies or defaultConfig.maxZombies
    if currentCount >= maxZombies then
        self.spawnAccumulator = 0
        return
    end

    self.spawnAccumulator = self.spawnAccumulator + dt * (self.config.spawnPerSecond or defaultConfig.spawnPerSecond)
    while self.spawnAccumulator >= 1 and currentCount < maxZombies do
        self.spawnAccumulator = self.spawnAccumulator - 1
        if self:spawnZombie(game) then
            currentCount = currentCount + 1
        else
            break
        end
    end
end

return ZombieStressTestSpawner
