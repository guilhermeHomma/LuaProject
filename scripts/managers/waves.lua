local WaveManager = {}
local Enemy = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")

require("scripts/utils")

local maxEnemiesAlive = 50

function WaveManager:load()
    
    self.wave = 0
    self.enemiesPerWave = 0
    self.spawnInterval = 2
    self.spawnTimer = 0
    self.enemiesSpawned = 0

    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")

end

function WaveManager:update(dt)
    if self.enemiesSpawned < self.enemiesPerWave and #Game.enemies < maxEnemiesAlive then
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= self.spawnInterval then
            self.spawnTimer = 0
            self:instanceEnemy()
        end
    end

    if #Game.enemies == 0 and self.enemiesSpawned >= self.enemiesPerWave and self.wave >= 0 then
        self:startNextWave()
    end
end

function WaveManager:instanceEnemy()

    local enemyX, enemyY = self:enemyPosition()
    table.insert(Game.enemies, Enemy:new(enemyX, enemyY) )
    self.enemiesSpawned = self.enemiesSpawned + 1
end

function WaveManager:enemyPosition()
    local tilemap = Tilemap:getTilemap()

    local posibleTiles = {}

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == 0 then
                
                local tilex, tiley = Tilemap:mapToWorld(x,y)
                if distance({x=tilex, y=tiley}, Player) > 240 then
                    table.insert(posibleTiles, {x=tilex, y=tiley})
                end
            end
        end
    end

    local randomIndex = math.random(1, #posibleTiles)
    local chosenTile = posibleTiles[randomIndex]

    return chosenTile.x, chosenTile.y - 8
end

function WaveManager:startNextWave()
    self.wave = self.wave + 1
    self.enemiesPerWave = self.enemiesPerWave + 2
    self.enemiesSpawned = 0
end


function WaveManager:draw()

    if not Player.isAlive or self.wave <= 0 then
        return
    end

    local text = "WAVE: " .. self.wave
    local textWidth = self.font:getWidth(text)

    local x = love.graphics.getWidth() / scale - textWidth - 15
    --love.graphics.setColor(0.70, 0.63, 0.52)
    --love.graphics.setColor(0.274, 0.4, 0.45, alpha)
    love.graphics.setColor(0.05, 0, 0.05)
    
    love.graphics.setFont(self.font)
    love.graphics.print(text, x+ 3, 10 + 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x, 10)


end


return WaveManager