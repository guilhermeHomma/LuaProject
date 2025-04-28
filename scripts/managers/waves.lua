local WaveManager = {}
local Enemy = require("scripts/enemies/zombie")
local Tilemap = require("scripts/tilemap")

require("scripts/utils")

function WaveManager:load()
    
    self.wave = 1
    self.enemiesPerWave = 3
    self.spawnInterval = 1
    self.spawnTimer = 0
    self.enemiesSpawned = 0

    self.font = love.graphics.newFont("assets/fonts/PixelGame.otf", 30)
    love.graphics.setFont(self.font)

end

function WaveManager:update(dt)
    if self.enemiesSpawned < self.enemiesPerWave then
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= self.spawnInterval then
            self.spawnTimer = 0
            self:instanceEnemy()
        end
    end

    if #enemies == 0 and self.enemiesSpawned >= self.enemiesPerWave then
        self:startNextWave()
    end
end

function WaveManager:instanceEnemy()

    local enemyX, enemyY = self:enemyPosition()
    table.insert(enemies, Enemy:new(enemyX, enemyY) )
    self.enemiesSpawned = self.enemiesSpawned + 1
end

function WaveManager:enemyPosition()
    local tilemap = Tilemap:getTilemap()

    local posibleTiles = {}

    for y = 1, #tilemap do
        for x = 1, #tilemap[y] do
            if tilemap[y][x] == 0 then

                local tilex, tiley = Tilemap:mapToWorld(x,y)
                if distance({x=tilex, y=tiley}, Player) > 300 then
                    table.insert(posibleTiles, {x=tilex, y=tiley})
                end
            end
        end
    end

    local randomIndex = math.random(1, #posibleTiles)
    local chosenTile = posibleTiles[randomIndex]

    return chosenTile.x, chosenTile.y
end

function WaveManager:startNextWave()
    self.wave = self.wave + 1
    self.enemiesPerWave = self.enemiesPerWave + 2
    self.enemiesSpawned = 0
end


function WaveManager:draw()

    if not Player.isAlive then
        return
    end

    local text = "WAVE: " .. self.wave
    local textWidth = self.font:getWidth(text)

    local x = love.graphics.getWidth() - textWidth - 15
    --love.graphics.setColor(0.70, 0.63, 0.52)
    love.graphics.setColor(0.274, 0.4, 0.45, alpha)

    love.graphics.print(text, x+ 2, 10 + 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x, 10)


end


return WaveManager