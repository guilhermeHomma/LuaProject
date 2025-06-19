Tile = {}
Tile.__index = Tile
TileSet = require("scripts.objects.tileset")
local Ball = require("scripts/particles/ballParticle")
local BoxParticle = require("scripts/particles/boxParticle")


function Tile:setTilemap(tilemap)
    Tile.tilemap = tilemap
end

function Tile:new(x, y, quadIndex, collider)
    if quadIndex == 14 and math.random() > 0.4 then
        quadIndex = 18
    end

    if collider == nil then collider = true end

    local tile = setmetatable({}, Tile)
    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize

    tile.quad = tileSet[quadIndex]
    tile.quad2 = tileSet[quadIndex]
    tile.quadIndex = quadIndex
    if tile.quadIndex == 1 or tile.quadIndex == 2 or tile.quadIndex == 3 then
        tile.quad2 = tileSet[quadIndex + 3]
    end

    
    tile.x = x
    tile.y = y
    tile.size = tileSize
    tile.alpha = 1
    tile.collider = collider
    tile.xWorld, tile.yWorld = Tile.tilemap:mapToWorld(x,y)
    tile.distance = 0
    tile.isAlive = true
    return tile
end

function Tile:update(dt)
    if self.isAlive then
        addToDrawQueue(self.yWorld, self)
    end
end

function Tile:onshoot()
    if not self.isAlive then return end
    if self.quadIndex == 14 or self.quadIndex == 18 then --box
        self.collider = false
        Tile.tilemap.getTilemap()[self.x][self.y] = 0
        self.isAlive = false

        for i = 1, 3 do
            local angle = math.random() * 2 * math.pi

            local dx = math.cos(angle)
            local dy = math.sin(angle)
            
            local lifetime = math.random(40, 50) / 100
            local size = math.random(8, 10) / 10
            local particle = Ball:new(self.xWorld, self.yWorld, 1,dx, dy, lifetime, size )
            table.insert(Game.particles, particle)
            local particle = Ball:new(self.xWorld, self.yWorld, 1,-dx, -dy, lifetime, size )
            table.insert(Game.particles, particle)
        end

        local bp = BoxParticle:new(self.xWorld, self.yWorld)
        table.insert(Game.particles, bp)

        local playerDistance = distance(Player, self)
        
        local bulletSound = love.audio.newSource("assets/sfx/particles/break-box.mp3", "static")

        local volume = getDistanceVolume(playerDistance, 0.3, 200)
        bulletSound:setVolume(volume)
        bulletSound:setPitch((0.9 + math.random() * 0.1) * GAME_PITCH)
        bulletSound:play()


        local coinSound = love.audio.newSource("assets/sfx/drops/coin-drop.mp3", "static")
        local playerDistance = distance(Player, self)
        local volume = getDistanceVolume(playerDistance, 0.4, 200)

        coinSound:setVolume(volume)
        coinSound:setPitch((1 + math.random() * 0.1) * GAME_PITCH)
        coinSound:play()

        local coinDrop = require("scripts/drops/coin")
        local drop = coinDrop:new(self.xWorld, self.yWorld)
        table.insert(Game.objects, drop)

    end
end

function Tile:draw()
    if not self.isAlive then
        return
    end

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage

    if self.quadIndex == 14 or self.quadIndex == 18 then --box
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize*2)

    elseif self.quadIndex == 1 or self.quadIndex == 2 or self.quadIndex == 3  then
        love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld - 16, 0, 1, 1, tileSize/2, tileSize)
        love.graphics.draw(tilesetImage, self.quad2, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    else
       love.graphics.draw(tilesetImage, self.quad, self.xWorld, self.yWorld, 0, 1, 1, tileSize/2, tileSize)
    end

    self:drawDebug()
end

function Tile:drawDebug()
    if self.collider and DEBUG then
        playerX, playerY = Tile.tilemap:worldToMap(Player.x, Player.y)
        if playerX == self.x and playerY == self.y then
            love.graphics.setColor(1, 0.5, 0.5, 1)
        end
        love.graphics.rectangle("line", self.xWorld-8, self.yWorld-16, 16, 16)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Tile:drawShadow()
    if self.quadIndex == 5 or self.quadIndex == 15 then 
        return
    end

    local tileSet = TileSet:getTileSet()
    local tileSize = TileSet.tileSize
    local tilesetImage = TileSet.tilesetImage
    local sheetWidth = TileSet.sheetWidth
    local sheetHeight = TileSet.sheetHeight
    local shadowSize = 20
    local quadShadow = love.graphics.newQuad(110, 14, shadowSize, shadowSize, sheetWidth, sheetHeight)

    love.graphics.draw(tilesetImage, quadShadow, self.xWorld, self.yWorld, 0, 1, 1, shadowSize/2, shadowSize-4)
end


return Tile