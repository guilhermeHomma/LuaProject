WaveManager = {}
local Zombie= require("scripts/enemies/zombie")
local BigZombie = require("scripts/enemies/bigZombie")
local BabyZombie = require("scripts/enemies/babyZombie")
local Tilemap = require("scripts/tilemap")

require("scripts/utils")

local maxEnemiesAlive = 80

function WaveManager:load()
    self.wave = 0
    self.enemiesPerWave = 0
    self.spawnInterval = {0.1, 2}
    self.nextInterval = 0
    self.spawnTimer = 0
    self.enemiesSpawned = 0

    self.font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
    self.font:setFilter("nearest", "nearest")

    self.start = false

    self.openSouthWave = 12
    self.openNorthWave = 7

    self.changeWaveTimer = 0
end

function WaveManager:update(dt)

    if not self.start then 
        if Player.isAlive and Player.y < 268 then
            self.start = true
        end
        return 
    end
    self.changeWaveTimer = self.changeWaveTimer + dt
    if self.enemiesSpawned < self.enemiesPerWave and #Game.enemies < maxEnemiesAlive then
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= self.nextInterval then
            self.nextInterval = math.random(self.spawnInterval[1], self.spawnInterval[2])
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

    if self.wave == 1 then
        
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY, math.random(20, 25)))

    elseif self.wave < 4 then 
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY, math.random(30, 40)))

    --and self.wave > 8
    elseif math.random(1, 9) > 8  and self.wave  >= 6 then
        table.insert(Game.enemies, BigZombie:new(enemyX, enemyY) )
    elseif math.random(1, 7) > 6 and self.wave  >= 10  then
        table.insert(Game.enemies, BabyZombie:new(enemyX, enemyY))
    else
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY))
        
    end
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

    if self.wave >= 4 then 
        local sound = love.audio.newSource("assets/sfx/ambience/owl.mp3", "static")
        sound:setVolume(0.15)
        sound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)
        sound:play()
    end

    local sound = love.audio.newSource("assets/sfx/ambience/nextWave.mp3", "static")
    sound:setVolume(0.3)
    sound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)
    sound:play()

    self.changeWaveTimer = 0
    self.wave = self.wave + 1
    self.nextInterval = 4
    -- if self.wave == self.openSouthWave then
    --     Game:openSouth()
    -- end

    -- if self.wave == self.openNorthWave then
    --     Game:openNorth()
    -- end

    self.enemiesPerWave = self.enemiesPerWave + 2
    self.enemiesSpawned = 0
end




function WaveManager:draw()

    if not Player.isAlive or self.wave <= 0 then
        return
    end

    if self.changeWaveTimer < 1 then
        if math.floor(self.changeWaveTimer * 10) % 2 == 0 then
            return
        end
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