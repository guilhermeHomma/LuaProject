local Elevator = require("scripts/objects/elevator")
local ElevatorSmoke = require("scripts/particles/elevatorSmoke")
local Arrival = setmetatable({}, {__index = Elevator})
Arrival.__index = Arrival

local images = {}
for part, file in pairs({back = "elevator-struct-top", ground = "elevator-ground-top", groundBack = "elevator-ground-back"}) do
    images[part] = love.graphics.newImage("assets/sprites/objects/elevator/top/" .. file .. ".png")
    images[part]:setFilter("nearest", "nearest")
end
local sound = love.audio.newSource("assets/sfx/elevator/elevator-loop.mp3", "static")
local endSound = love.audio.newSource("assets/sfx/elevator/end-elevator.mp3", "static")
local platformImage = love.graphics.newImage("assets/sprites/objects/elevator/top/platform-top.png")
platformImage:setFilter("nearest", "nearest")
local platformQuads = {love.graphics.newQuad(0, 0, 96, 88, platformImage:getDimensions())}

function Arrival:new(x, y)
    local arrival = setmetatable(Elevator:new(x, y, {collisionPattern = {}}), self)
    arrival.blocksPlayer = false
    arrival.isArrivalElevator = true
    arrival.platformImage = platformImage
    arrival.platformQuads = platformQuads
    return arrival
end

function Arrival:start(onComplete)
    self.timer = 0
    self.hasDocked = false
    ElevatorSmoke.emit(self, 12)
    self.platformOffset = -16
    self.onComplete = onComplete
    self.arrivalSound = sound:clone()
    self.arrivalSound:setVolume(SOUND_VOLUME or 1)
    self.arrivalSound:setPitch(0.97 + math.random() * 0.06)
    self.arrivalSound:play()
    Player.x, Player.y = self.x, self.y - 40
    Player.velocityX, Player.velocityY = 0, 0
    Player.moveX, Player.moveY, Player.flipH = 0, 1, false
    Player.gun.showGun = false
    Game.elevatorSequence = self
    Game.elevatorFadeAlpha = 1
end

function Arrival:updateSequence(dt)
    self.timer = self.timer + dt
    local progress = math.min(1, self.timer / 1.2)
    self.platformOffset = -16 * (1 - progress) ^ 2
    self.platformTimer = self.platformTimer + dt
    if progress >= 1 and not self.hasDocked then
        self.hasDocked = true
        self.arrivalSound:stop()
        self.endSound = endSound:clone()
        self.endSound:setVolume(SOUND_VOLUME or 1)
        self.endSound:play()
        ElevatorSmoke.emit(self, 8)
    end
    Game.elevatorFadeAlpha = math.max(0, 1 - self.timer / 0.3)
    Player:updateAnimation(dt, false)
    self:update(dt)
    addToDrawQueue(Player.y + 6, Player)
    return progress >= 1
end

function Arrival:update(dt)
    addToDrawQueue(self.y - 80, self.groundBackPart, false)
    addToDrawQueue(self.y - 80, self.backPart, false)
    addToDrawQueue(self.y - 72, self.platformPart, false)
    addToDrawQueue(self.y - 16, self.groundPart, false)
end

function Arrival:keypressed(key)
    -- This is only the arrival landing; it cannot activate another floor change.
end

function Arrival:drawPart(part)
    if part == "platform" then return Elevator.drawPart(self, part) end
    self:drawStructureImage(images[part])
end

return Arrival
