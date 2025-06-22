local Game = {}

Player = require "scripts/player/player"
Camera = require("scripts/camera")

local Ground = require("scripts/ground")
local WaveManager = require("scripts/managers/waves")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local PointsManager = require("scripts/managers/pointsManager")
local DoorsManager = require("scripts/managers/doorsManager")
local HeartSound = require("scripts/player/heartSound")


local font = love.graphics.newFont("assets/fonts/ThaleahFat.ttf", 32)
camera = nil

function Game:load()
    
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    Player:load(camera)
    camera = Camera:new(Player.x-5, Player.y-30, Player)
    

    Ground:load()
    WaveManager:load()
    Clouds:load(Player)
    Tilemap:load()
    DoorsManager:load()
    PointsManager:load()
    HeartSound:load()

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8) 
    love.mouse.setCursor(cursor)

    self.enemies = {}
    self.drawQueue = {}
    self.particles = {}
    self.objects = {}

    self.crowTimer = math.random(20, 50)
    self.cricketTimer = math.random(30, 40)

    self.drawtext = "init text\ninit text\nyou shouldnt see this"
    self.textAlpha = 0
    self.textAlphaTarget = 0
    --self:openNorth()
    --self:openSouth()
end

function Game:openSouth()
    DoorsManager:openSouth()
end

function Game:openNorth()
    DoorsManager:openNorth()
end

function Game:close()
    HeartSound:stop()
    self = {}
end

function Game:getPlayerPoints()
    return PointsManager:getPoints()
end

function Game:increasePlayerPoints(qty)
    PointsManager:increasePoints(qty)
end

function Game:decreasePlayerPoints(qty)
    return PointsManager:decreasePoints(qty)
end


function Game:update(dt)
    self.drawQueue = {}
    --love.audio.setPosition(Player.x, Player.y, 0)
    local targetPitch = 1

    self.crowTimer = self.crowTimer - dt
    if self.crowTimer <= 0 then 
        self:crowNoise()
    end

    self.cricketTimer = self.cricketTimer - dt
    if self.cricketTimer <= 0 then
        
        self:cricketNoise()
    end

    if Player.life == 1
    then
        targetPitch = 0.9
    end
    GAME_PITCH = transitionValue(GAME_PITCH, targetPitch, 1.3, dt)


    self.textAlpha = transitionValue(self.textAlpha, self.textAlphaTarget, 5, dt)
    self.textAlphaTarget = 0


    for _, enemy in ipairs(self.enemies) do
        if enemy.isAlive then
            enemy:update(dt) 
        else
            table.remove(self.enemies, _)
        end
    end

    for _, obj in ipairs(self.objects) do
        if obj.isAlive then
            obj:update(dt) 
        else
            table.remove(self.objects, _)
        end
    end

    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle:update(dt)
        if not particle.isAlive then
            table.remove(self.particles, i)
        end
    end

    WaveManager:update(dt)
    Clouds:update(dt)
    Player:update(dt)
    DoorsManager:update(dt)
    HeartSound:update(dt)
    Tilemap:update(dt)
    PointsManager:update(dt)

    camera:update(dt)
end


function Game:crowNoise()
    if not (Player.isAlive and Player.life > 1) then 
        return
    end
    self.crowTimer = math.random(20, 50)
    AmbienceSound:playCrowSound()
end

function Game:cricketNoise()
    if not (Player.isAlive and Player.life > 1) then 
        return
    end
    self.cricketTimer = math.random(20, 30)
    AmbienceSound:playCricketSound()
end

function Game:draw()
    camera:attach()

    love.graphics.scale(3, YSCALE) 

    
    Ground:draw(Player)
    
    table.sort(self.drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(self.drawQueue) do
        if type(item.object.drawShadow) == "function" then
            item.object:drawShadow()
        end
    end

    Player:drawSight()

    for _, item in ipairs(self.drawQueue) do
        local d = distance(camera:objectPosition(), item.object)

        local minDist = 20
        local maxDist = 200

        local minDist = 110
        local maxDist = 260

        local t = math.min(math.max((d - minDist) / (maxDist - minDist), 0), 1)
        local brightness = 1 - t * 0.8
        local r, g, b, a = 1,1,1,1
        --love.graphics.setColor(r * brightness, g * brightness, b * brightness, a)
        item.object:draw()
        love.graphics.setColor(r, g, b, a)
    end
    Clouds:draw()
    
    love.graphics.scale(1, 1)
    camera:detach()  

    love.graphics.setFont(font)
    font:setLineHeight(0.65)
    love.graphics.setColor(1, 1, 1, self.textAlpha)
    love.graphics.printf(
        self.drawtext,
        0,        
        getScreenHeight() - 80,           
        getScreenWidth(),                
        "center"
    )

    love.graphics.setColor(1, 1, 1, 1)

    PointsManager:draw()
    Player:drawLife()
    if Player and Player.isAlive then
        Player.gun:drawUI()
    end
    WaveManager:draw()
  
    if DEBUG then
        love.graphics.print("enemies qty: " .. #self.enemies, 10, 110)
    end

    --love.graphics.setColor(0.3, 0.45, 0.45, Player.damageAlha)
    love.graphics.setColor(0, 0, 0.1, Player.damageAlha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1)

end

function Game:keypressed(key)
    if key == "f6" then
        DEBUG = not DEBUG
    elseif key == "x" then
        Tilemap:keypressed(key)
    elseif key == "o" then
        DoorsManager:openSouth()
    elseif key == "n" then
        DoorsManager:openNorth()
    elseif tonumber(key) then
        --self:changeShaders(tonumber(key))
    end
end

return Game