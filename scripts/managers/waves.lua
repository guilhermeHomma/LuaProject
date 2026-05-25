WaveManager = {}
local Zombie= require("scripts/enemies/zombie")
local BigZombie = require("scripts/enemies/bigZombie")
local BabyZombie = require("scripts/enemies/babyZombie")
local NoHead = require("scripts/enemies/noHead")
local Tilemap = require("scripts/tilemap")

require("scripts/utils")

local maxEnemiesAlive = 60

local function currentThemeAllowsAmbience(soundId)
    local FloorManager = package.loaded["scripts/managers/floorManager"]
    local theme = FloorManager
        and FloorManager.getCurrentRoomTheme
        and FloorManager:getCurrentRoomTheme()
    local ambience = theme and theme.ambience
    return not ambience or ambience[soundId] ~= false
end

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
    if CURRENT_LEVEL and CURRENT_LEVEL.enableWaves == false then
        return
    end

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
        
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY, math.random(40, 45)))

    elseif self.wave < 4 then 
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY, math.random(50, 60)))

    --and self.wave > 8
    elseif math.random(1, 9) > 8  and self.wave  >= 6 then
        table.insert(Game.enemies, BigZombie:new(enemyX, enemyY) )
    elseif self.wave >= 10 and math.random(1, 7) > 6 then
        if math.random(1, 2) == 1 then
            table.insert(Game.enemies, BabyZombie:new(enemyX, enemyY))
        else
            table.insert(Game.enemies, NoHead:new(enemyX, enemyY))
        end
    else
        table.insert(Game.enemies, Zombie:new(enemyX, enemyY))
        
    end
    self.enemiesSpawned = self.enemiesSpawned + 1
end

function WaveManager:enemyPosition()
    return Tilemap:getRandomSpawnPosition(Player)
end

function WaveManager:startNextWave()

    if self.wave >= 4 and currentThemeAllowsAmbience("owl") then
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
    if CURRENT_LEVEL and CURRENT_LEVEL.enableWaves == false then
        return
    end

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

    local x = baseWidth - textWidth - 15
    --love.graphics.setColor(0.70, 0.63, 0.52)
    --love.graphics.setColor(0.274, 0.4, 0.45, alpha)
    love.graphics.setColor(0.05, 0, 0.05)
    
    love.graphics.setFont(self.font)
    love.graphics.print(text, x+ 3, 10 + 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, x, 10)


end


return WaveManager
