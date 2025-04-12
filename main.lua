Player = require "scripts/player/player"
local stretchFactor = 0.65

local Camera = require("scripts/camera")

camera = Camera:new()

local Ground = require("scripts/ground")
local WaveManager = require("scripts/waves")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")

drawQueue = {}
enemies = {}
particles = {}

DEBUG = false
FPS = false

local music 

function love.load()
    math.randomseed(os.time())
    WaveManager:load()
    Player:load(camera)
    Ground:load()
    Clouds:load()
    Tilemap:load()

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8) 
    love.mouse.setCursor(cursor)
    music = love.audio.newSource("assets/sfx/music.wav", "stream")
    music:setLooping(true) 
    music:setVolume(0.8)
    --music:play()

end


local function restartGame()
    enemies = {}
    particles = {}
    drawQueue = {}

    camera = Camera:new()
    WaveManager:load()
    Player:load(camera)
    Ground:load()
    Clouds:load()
    Tilemap:load()

    
end

function love.keypressed(key)
    if key == "r" then
        restartGame()
    end

    if key == "f5" then
        FPS = not FPS
    end

    if key == "f6" then
        DEBUG = not DEBUG
    end

end

function love.update(dt)

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            enemy:update(dt) 
            addToDrawQueue(enemy.y -1 + enemy.drawPriority, enemy)
        else
            table.remove(enemies, _)

        end
    end

    for i = #particles, 1, -1 do
        local particle = particles[i]
        particle:update(dt)
        if not particle.isAlive then
            table.remove(particles, i)
        end
    end

    WaveManager:update(dt)
    Clouds:update(dt)
    Player:update(dt)
    Tilemap:update()

    camera:update(Player.x *3 - love.graphics.getWidth() / 2, Player.y*2 - love.graphics.getHeight() / 2)
end


function addToDrawQueue(priority, object)
    table.insert(drawQueue, {priority = priority, object = object})
end

function love.draw()

    love.graphics.clear(0.780, 0.75, 0.57)

    camera:attach()

    love.graphics.scale(3, 2) 
    Ground:draw(Player)
    
    table.sort(drawQueue, function(a, b) return a.priority < b.priority end)
    Clouds:drawShadow()

    for _, item in ipairs(drawQueue) do
        if type(item.object.drawShadow) == "function" then

            if distance(Player, item.object) < 350 then 
                item.object:drawShadow()
            end
        end
    end

    Player:drawS()
    Player:drawSight()

    for _, item in ipairs(drawQueue) do
        if distance(Player, item.object) < 350 then 
            item.object:draw()
        end
    end
    Clouds:draw()
    love.graphics.scale(1, 1)
    
    drawQueue = {}
    camera:detach()
    Player:drawLife()
    WaveManager:draw()

    if FPS or DEBUG then 
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 60)
    end
    if DEBUG then
        love.graphics.print("enemies qty: " .. #enemies, 10, 80)
    end
end

