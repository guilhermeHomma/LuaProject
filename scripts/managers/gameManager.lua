local Game = {}

Player = require "scripts/player/player"
Camera = require("scripts/camera")
Dialog = require("scripts/dialog/dialog")

local Ground = require("scripts/ground")
local WaveManager = require("scripts/managers/waves")
local Tutorial = require("scripts/managers/tutorial")
local Clouds = require("scripts/clouds")
local Tilemap = require("scripts/tilemap")
local EnemyDirector = require("scripts/enemies/enemyDirector")
local PointsManager = require("scripts/managers/pointsManager")
local DoorsManager = require("scripts/managers/doorsManager")
local FloorManager = require("scripts/managers/floorManager")
local LightConfig = require("scripts/config/lightConfig")
local GameHud = require("scripts/ui/gameHud")
local HeartSound = require("scripts/player/heartSound")
local CreatorManager = require "scripts.managers.CreatorManager"
local Trail = require("scripts.objects.trails")
local Scarecrow = require("scripts/enemies/scarecrow")
local CardChoice = require("scripts/managers/cardChoice")
local FloorIntroManager = require("scripts/managers/floorIntroManager")
local RoomScreenTransition = require("scripts/managers/roomScreenTransition")
local AmbienceSound = require("scripts/managers/ambienceSound")
local PlayerVisualEffects = require("scripts/managers/playerVisualEffects")
local WorldRenderer = require("scripts/render/worldRenderer")
local RoomEncounterManager = require("scripts/managers/roomEncounterManager")
local RoomFlowManager = require("scripts/managers/roomFlowManager")

RoomEncounterManager.attach(Game)
RoomFlowManager.attach(Game)

camera = nil
local ENEMY_SPATIAL_CELL_SIZE = 48
local MAX_PLAYER_PROJECTILE_LIGHTS = 30
local MAX_ENEMY_PROJECTILE_LIGHTS = 30
local SPOTLIGHT_FOCUS_DURATION = 0.85
local SPOTLIGHT_TOTAL_DURATION = 2.05
local SPOTLIGHT_START_SPEED = 360
local SPOTLIGHT_EXIT_SPEED = 2000
local SPOTLIGHT_EXIT_ACCELERATION = 2000
local SPOTLIGHT_FEATHER_SPEED = 22

local function isStartRoom(room)
    local level = FloorManager.level
    local startRoomId = level and level.floorConfig and level.floorConfig.startRoomId or "0:0"
    return room and room.id == startRoomId
end

local function setBattleMusicActive(active)
    if Music and Music.setBattleActive then
        Music:setBattleActive(active == true)
    end
end

local function getLightCalculationDistance(config)
    if config.calculationDistance then
        return config.calculationDistance
    end

    local spriteBrightness = config.spriteBrightness or {}
    local groundLight = config.groundLight or {}
    return math.max(spriteBrightness.maxDistance or 0, groundLight.outerRadius or 0)
end

local function isLightNearPlayer(config, x, y)
    if not (Player and Player.x and Player.y) then
        return true
    end

    local maxDistance = getLightCalculationDistance(config)
    if maxDistance <= 0 then
        return true
    end

    local dx = x - Player.x
    local dy = y - Player.y
    return dx * dx + dy * dy <= maxDistance * maxDistance
end

local function isGroundLightNearCamera(config, x, y)
    local groundLight = config and config.groundLight
    if not (camera and groundLight and groundLight.enabled ~= false) then
        return false
    end

    local radius = groundLight.outerRadius or 0
    local screenX = (x * WORLD_SCALE_X - camera.x) * camera.zoomX
    local screenY = (y * YSCALE - camera.y) * camera.zoomY

    return screenX >= -radius
        and screenX <= baseWidth + radius
        and screenY >= -radius
        and screenY <= baseHeight + radius
end

function Game:load(options)
    options = options or {}
    ACTIVE_LIGHT_MANAGER = self
    setBattleMusicActive(false)
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    CardChoice:load()

    FloorManager:load(CURRENT_LEVEL)
    Tilemap:load()

    local spawnX, spawnY = RoomFlowManager.getStartRoomPlayerSpawn()
    Player:load(camera, spawnX, spawnY)
    camera = Camera:new(Player.x - 5, Player.y - 30, Player)
    camera:snapToCurrentMode()

    self.fogShader = love.graphics.newShader("scripts/shaders/fog.glsl")
    self.fogTime = 0
    self.spot = {
        radius = 1,
        feather = 3,
        target = 60,
        speed = SPOTLIGHT_START_SPEED,
        speedIncrease = SPOTLIGHT_EXIT_SPEED,
        enabled = true,
    }

    Tutorial:load()
    if not (CURRENT_LEVEL and CURRENT_LEVEL.enableTrails == false) then
        Trail:load()
    end
    Ground:load()
    WaveManager:load()
    Clouds:load(Player)
    DoorsManager:load()
    PointsManager:load()
    HeartSound:load()
    Dialog:load()

    local cursorImage = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(cursorImage, 8, 8)
    love.mouse.setCursor(cursor)

    self:resetRuntimeState()
    self:setupCurrentRoom()
    self:restoreCurrentRoomDrops()
    if options.startFloorIntro ~= false then
        self:startFloorIntro(CURRENT_LEVEL and CURRENT_LEVEL.currentFloorIndex or 1, options.onFloorIntroComplete)
    end
end

function Game:resetRuntimeState()
    self.sPSoundPlayed = false
    self.sPSoundPlayedOutro = false
    self.enemies = {}
    self.drawQueue = {}
    self.groundDecalQueue = {}
    self.lightSources = {}
    self.lightSourcesCache = {}
    self.playerLightSource = {}
    self.lightSourcesCacheDirty = true
    self.weaponShockwaves = {}
    self.footsteps = {}
    self.particles = {}
    self.objects = {}
    self.purchasedWeapons = {}
    self.nearbyEnemies = {}
    self.enemySpatialGrid = {}
    self.drawtext = "init text\ninit text\nyou shouldnt see this"
    self.textAlpha = 0
    self.textAlphaTarget = 0
    self.bottomMessageText = nil
    self.bottomMessageTimer = 0
    self.timer = 0
    self.roomTransitionCooldown = 0
    self.playerRoomEntryMove = nil
    self.playerRoomExitTransition = nil
    self.pendingRoomRevealId = nil
    self.minimapRoomOverrideId = nil
    self.minimapForcePlayerIconRefresh = false
    self.currentEntryDoorAvoidPoint = nil
    self.playerCombatRoomsEntered = 0
    self.roomFadeAlpha = 0
    self.floorChanging = false
    self.hitStopTimer = 0
    self.hitStopDuration = 0
    self.hitStopRecoveryTimer = 0
    self.hitStopRecoveryDuration = 0
    self.damageAudioPitchTimer = 0
    self.damageAudioPitchDuration = 1
    self.damageAudioPitch = 0.58
    self.damageAudioVolumeDuckTimer = 0
    self.damageAudioVolumeDuckDuration = 1
    self.damageAudioVolumeDuckDelayTimer = 0
    self.damageAudioVolumeDuckMultiplier = 1
    self.currentDamageAudioVolumeMultiplier = 1
    love.audio.setVolume(SOUND_VOLUME or 1)
    PlayerVisualEffects.reset()
    Dialog.breakMovements = false
end

local function getSpatialCell(value)
    return math.floor(value / ENEMY_SPATIAL_CELL_SIZE)
end

function Game:rebuildEnemySpatialIndex()
    local grid = self.enemySpatialGrid or {}
    for _, row in pairs(grid) do
        for _, bucket in pairs(row) do
            for i = #bucket, 1, -1 do
                bucket[i] = nil
            end
        end
    end

    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.isAlive ~= false and enemy.x and enemy.y then
            local cellX = getSpatialCell(enemy.x)
            local cellY = getSpatialCell(enemy.y)
            local row = grid[cellY]
            if not row then
                row = {}
                grid[cellY] = row
            end
            local bucket = row[cellX]
            if not bucket then
                bucket = {}
                row[cellX] = bucket
            end
            bucket[#bucket + 1] = enemy
        end
    end

    self.enemySpatialGrid = grid
end

function Game:getEnemiesNearPoint(x, y, radius)
    local result = self.enemyQueryResult
    if result then
        for i = #result, 1, -1 do
            result[i] = nil
        end
    else
        result = {}
        self.enemyQueryResult = result
    end

    local grid = self.enemySpatialGrid
    if not grid then
        return self.enemies or result
    end

    radius = radius or ENEMY_SPATIAL_CELL_SIZE
    local minCellX = getSpatialCell(x - radius)
    local maxCellX = getSpatialCell(x + radius)
    local minCellY = getSpatialCell(y - radius)
    local maxCellY = getSpatialCell(y + radius)
    local radiusSq = radius * radius

    for cellY = minCellY, maxCellY do
        local row = grid[cellY]
        if row then
        for cellX = minCellX, maxCellX do
            local bucket = row[cellX]
            if bucket then
                for i = 1, #bucket do
                    local enemy = bucket[i]
                    local dx = enemy.x - x
                    local dy = enemy.y - y
                    if dx * dx + dy * dy <= radiusSq then
                        result[#result + 1] = enemy
                    end
                end
            end
        end
        end
    end

    return result
end

function Game:findEnemyCollidingWithShot(shot, radius)
    if not (shot and shot.x and shot.y and shot.checkCollisionWithEnemy) then
        return nil
    end

    local ignoredEnemies = shot.ignoredEnemies

    local grid = self.enemySpatialGrid
    if not grid then
        for i = 1, #(self.enemies or {}) do
            local enemy = self.enemies[i]
            if enemy
                and enemy.isAlive
                and (not ignoredEnemies or not ignoredEnemies[enemy])
                and shot:checkCollisionWithEnemy(enemy) then
                return enemy
            end
        end
        return nil
    end

    radius = radius or ENEMY_SPATIAL_CELL_SIZE
    local x = shot.x
    local y = shot.y
    local minCellX = getSpatialCell(x - radius)
    local maxCellX = getSpatialCell(x + radius)
    local minCellY = getSpatialCell(y - radius)
    local maxCellY = getSpatialCell(y + radius)
    local radiusSq = radius * radius

    for cellY = minCellY, maxCellY do
        local row = grid[cellY]
        if row then
            for cellX = minCellX, maxCellX do
                local bucket = row[cellX]
                if bucket then
                    for i = 1, #bucket do
                        local enemy = bucket[i]
                        local dx = enemy.x - x
                        local dy = enemy.y - y
                        if dx * dx + dy * dy <= radiusSq
                            and enemy.isAlive
                            and (not ignoredEnemies or not ignoredEnemies[enemy])
                            and shot:checkCollisionWithEnemy(enemy) then
                            return enemy
                        end
                    end
                end
            end
        end
    end

    return nil
end

function Game:getEnemiesNearBox(box, padding)
    local result = self.enemyBoxQueryResult
    if result then
        for i = #result, 1, -1 do
            result[i] = nil
        end
    else
        result = {}
        self.enemyBoxQueryResult = result
    end

    local grid = self.enemySpatialGrid
    if not (grid and box) then
        return self.enemies or result
    end

    padding = padding or 0
    local minX = box.x - padding
    local maxX = box.x + box.width + padding
    local minY = box.y - padding
    local maxY = box.y + box.height + padding
    local minCellX = getSpatialCell(minX)
    local maxCellX = getSpatialCell(maxX)
    local minCellY = getSpatialCell(minY)
    local maxCellY = getSpatialCell(maxY)

    for cellY = minCellY, maxCellY do
        local row = grid[cellY]
        if row then
        for cellX = minCellX, maxCellX do
            local bucket = row[cellX]
            if bucket then
                for i = 1, #bucket do
                    local enemy = bucket[i]
                    if enemy.x >= minX and enemy.x <= maxX and enemy.y >= minY and enemy.y <= maxY then
                        result[#result + 1] = enemy
                    end
                end
            end
        end
        end
    end

    return result
end

function Game:restoreCurrentRoomDrops()
    local state = FloorManager:getCurrentRoomState()
    if not (state and state.drops) then
        return
    end

    local Coin = require("scripts/drops/coin")
    local Life = require("scripts/drops/life")
    local Bullets = require("scripts/drops/bullets")

    for key, entry in pairs(state.drops) do
        if not entry.collected then
            local drop
            if entry.kind == "life" then
                drop = Life:new(entry.x, entry.y)
            elseif entry.kind == "bullets" then
                drop = Bullets:new(entry.x, entry.y)
            else
                drop = Coin:new(entry.x, entry.y)
            end
            table.insert(self.objects, configurePersistedRoomDrop(drop, key, entry))
        end
    end
end

function Game:markWeaponPurchased(weaponName)
    if not weaponName then
        return
    end

    self.purchasedWeapons = self.purchasedWeapons or {}
    self.purchasedWeapons[weaponName] = true
end

function Game:hasPurchasedWeapon(weaponName)
    return self.purchasedWeapons and self.purchasedWeapons[weaponName] == true
end

function Game:canOpenCurrentRoomDoors(showMessage)
    return true
end

function Game:canLeaveCurrentRoom()
    return self:canOpenCurrentRoomDoors(true)
end

function Game:startFloorIntro(floorIndex, onComplete)
    Dialog.breakMovements = true
    setBattleMusicActive(false)
    if Music and Music.closeForFloorIntro then
        Music:closeForFloorIntro()
    elseif Music and Music.closeGame then
        Music:closeGame()
    end
    FloorIntroManager:startFloor(floorIndex, function()
        Dialog.breakMovements = self.playerRoomEntryMove ~= nil
        RoomFlowManager.queuePlayerTransitionFrame({ x = 0, y = 0 }, false)
        if onComplete then
            onComplete()
        end
    end)
end

function Game:updateFloorIntro(dt)
    return FloorIntroManager:updateFloor(dt)
end

function Game:updateFloorIntroState(dt)
    FloorIntroManager:update(dt)
end

function Game:loadFloor(floorIndex, onIntroComplete)
    if not (CURRENT_LEVEL and CURRENT_LEVEL.applyFloorLevel and CURRENT_LEVEL:applyFloorLevel(floorIndex)) then
        return false
    end

    FloorManager:load(CURRENT_LEVEL)
    Tilemap:load()

    self.enemies = {}
    self.nearbyEnemies = {}
    self.objects = {}
    self.particles = {}
    self.drawQueue = {}
    self.groundDecalQueue = {}
    self.lightSources = {}
    self.lightSourcesCache = {}
    self.playerLightSource = {}
    self.lightSourcesCacheDirty = true
    self.weaponShockwaves = {}
    self.footsteps = {}
    self.roomTransitionCooldown = 0.28
    self.playerRoomEntryMove = nil
    self.playerRoomExitTransition = nil
    self.currentEntryDoorAvoidPoint = nil
    self.playerCombatRoomsEntered = 0
    self.roomFadeAlpha = 0
    self.floorChanging = false
    self.sPSoundPlayed = false
    self.sPSoundPlayedOutro = false
    self.timer = 0
    self.spot = self.spot or {}
    self.spot.radius = 1
    self.spot.feather = 3
    self.spot.target = 60
    self.spot.speed = SPOTLIGHT_START_SPEED
    self.spot.speedIncrease = SPOTLIGHT_EXIT_SPEED
    self.spot.enabled = true

    local spawnX, spawnY = RoomFlowManager.getStartRoomPlayerSpawn()
    Player.x = spawnX
    Player.y = spawnY
    Player.velocityX = 0
    Player.velocityY = 0
    Player.moveX = 0
    Player.moveY = 0

    if camera then
        camera.x = Player.x - 5
        camera.y = Player.y - 30
        camera:snapToCurrentMode()
    end

    self:setupCurrentRoom()
    self:restoreCurrentRoomDrops()
    self:startFloorIntro(floorIndex, onIntroComplete)
    return true
end

function Game:startThanksScreen()
    self.floorChanging = false
    Dialog.breakMovements = true
    setBattleMusicActive(false)
    if Music and Music.closeGame then
        Music:closeGame()
    end
    if STATES and STATES.floorIntro then
        state = STATES.floorIntro
    end
    FloorIntroManager:startThanks(function()
        Dialog.breakMovements = false
        if quitToMenuImmediate then
            quitToMenuImmediate()
        elseif quitToMenu then
            quitToMenu()
        end
    end)
end

function Game:updateThanksScreen(dt)
    return FloorIntroManager:updateThanks(dt)
end

function Game:showBottomMessage(text, duration)
    self.bottomMessageText = text
    self.bottomMessageTimer = duration or 3
    self.drawtext = text
    self.textAlphaTarget = 1
end

function Game:enterElevator()
    if self.floorChanging or FloorIntroManager:hasThanksScreen() then
        return
    end

    self.floorChanging = true
    local floorIndex = CURRENT_LEVEL and CURRENT_LEVEL.currentFloorIndex or 1
    local nextFloorIndex = floorIndex + 1
    if CURRENT_LEVEL and CURRENT_LEVEL.floorLevels and CURRENT_LEVEL.floorLevels[nextFloorIndex] then
        if Music and Music.closeGame then
            Music:closeGame()
        end
        if STATES and STATES.floorIntro then
            state = STATES.floorIntro
        end
        self:loadFloor(nextFloorIndex, function()
            if STATES and STATES.game then
                state = STATES.game
            end
            if Music and Music.startGame then
                Music:startGame()
            end
        end)
    else
        self:startThanksScreen()
    end
end

function Game:enterFloorHollow()
    return self:enterElevator()
end

function Game:openSouth()
    DoorsManager:openSouth()
end

function Game:openNorth()
    DoorsManager:openNorth()
end

function Game:close()
    HeartSound:stop()
    CardChoice:load()
    love.audio.setVolume(SOUND_VOLUME or 1)
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

function Game:playSLSound()
    if self.sPSoundPlayed then return end
    local sound = love.audio.newSource("assets/sfx/spotlight/spotlight1.mp3", "static")
    self.sPSoundPlayed = true
    sound:setVolume(0.2)
    sound:setPitch(1.3)
    sound:play()
end

function Game:playSLSoundOutro()
    if self.sPSoundPlayedOutro then return end
    local sound = love.audio.newSource("assets/sfx/spotlight/spotlight2.mp3", "static")
    sound:setVolume(0.1)
    sound:setPitch(1.1)
    self.sPSoundPlayedOutro = true
    sound:play()
end

function Game:updateSpotlight(dt)
    if not self.spot.enabled then
        return
    end

    self:playSLSound()
    if self.timer > SPOTLIGHT_FOCUS_DURATION then
        self:playSLSoundOutro()
        self.spot.target = 10000
        self.spot.speed = self.spot.speedIncrease
        self.spot.feather = self.spot.feather + SPOTLIGHT_FEATHER_SPEED * dt
        self.spot.speedIncrease = self.spot.speedIncrease + SPOTLIGHT_EXIT_ACCELERATION * dt
    end

    if self.spot.radius < self.spot.target then
        self.spot.radius = self.spot.radius + self.spot.speed * dt
    end

    if self.timer > SPOTLIGHT_TOTAL_DURATION then
        self.spot.enabled = false
    end
end

function Game:updateAmbientTimers(dt)
    self.timer = self.timer + dt
    AmbienceSound:updateRandomEvents(dt)
end

function Game:updatePitch(dt)
    local targetPitch = 1
    if Player.life <= 1 then
        targetPitch = 0.9
    end

    if (self.damageAudioPitchTimer or 0) > 0 then
        self.damageAudioPitchTimer = math.max(0, self.damageAudioPitchTimer - dt)
        local duration = math.max(self.damageAudioPitchDuration or 1, 0.001)
        local progress = 1 - (self.damageAudioPitchTimer / duration)
        local eased = progress * progress * (3 - 2 * progress)
        local damagePitch = self.damageAudioPitch or 0.58
        GAME_PITCH = damagePitch + (targetPitch - damagePitch) * eased
        return
    end

    GAME_PITCH = transitionValue(GAME_PITCH, targetPitch, 4.5, dt)
end

function Game:startDamageAudioDistortion(duration, pitch, volumeDuckDelay, volumeDuckDuration)
    self.damageAudioPitchDuration = duration or 1
    self.damageAudioPitchTimer = self.damageAudioPitchDuration
    self.damageAudioPitch = pitch or 0.58
    GAME_PITCH = self.damageAudioPitch
    self.damageAudioVolumeDuckDuration = volumeDuckDuration or self.damageAudioPitchDuration
    self.damageAudioVolumeDuckTimer = self.damageAudioVolumeDuckDuration
    self.damageAudioVolumeDuckDelayTimer = volumeDuckDelay or 0.28
    self.damageAudioVolumeDuckMultiplier = 0.1
    self.currentDamageAudioVolumeMultiplier = 1
    love.audio.setVolume(SOUND_VOLUME or 1)

    if Music and Music.startDamageDistortion then
        Music:startDamageDistortion(self.damageAudioPitchDuration, self.damageAudioPitch)
    end

    if AmbienceSound and AmbienceSound.startWindBoost then
        AmbienceSound:startWindBoost(self.damageAudioPitchDuration, 2)
    end
end

function Game:updateDamageAudioVolumeDuck(dt)
    if state ~= STATES.game then
        self.damageAudioVolumeDuckTimer = 0
        self.damageAudioVolumeDuckDelayTimer = 0
        self.currentDamageAudioVolumeMultiplier = 1
        love.audio.setVolume(SOUND_VOLUME or 1)
        return
    end

    if (self.damageAudioVolumeDuckDelayTimer or 0) > 0 then
        self.damageAudioVolumeDuckDelayTimer = math.max(0, self.damageAudioVolumeDuckDelayTimer - dt)
        self.currentDamageAudioVolumeMultiplier = 1
        love.audio.setVolume(SOUND_VOLUME or 1)
        return
    end

    if (self.damageAudioVolumeDuckTimer or 0) <= 0 then
        self.currentDamageAudioVolumeMultiplier = 1
        love.audio.setVolume(SOUND_VOLUME or 1)
        return
    end

    self.damageAudioVolumeDuckTimer = math.max(0, self.damageAudioVolumeDuckTimer - dt)
    local duration = math.max(self.damageAudioVolumeDuckDuration or 1, 0.001)
    local progress = 1 - (self.damageAudioVolumeDuckTimer / duration)
    local eased = progress * progress * (3 - 2 * progress)
    local minMultiplier = self.damageAudioVolumeDuckMultiplier or 0.1
    local multiplier = minMultiplier + (1 - minMultiplier) * eased
    self.currentDamageAudioVolumeMultiplier = multiplier
    love.audio.setVolume((SOUND_VOLUME or 1) * multiplier)
end

function Game:getDamageAudioVolumeMultiplier()
    return self.currentDamageAudioVolumeMultiplier or 1
end

function Game:showPlayerDamageFlash(dx, dy, hitX, hitY)
    PlayerVisualEffects.showDamageFlash(Player, dx, dy, hitX, hitY)
end

function Game:drawPlayerDamageFlash(viewportScale)
    PlayerVisualEffects.draw(camera, viewportScale)
end

function Game:updateEntityList(list, dt)
    for i = #list, 1, -1 do
        local item = list[i]
        if item.isAlive then
            item:update(dt)
        else
            table.remove(list, i)
        end
    end
end

function Game:updateParticleList(dt)
    local list = self.particles or {}
    local i = #list
    while i >= 1 do
        local item = list[i]
        if item and item.isAlive then
            if item.queueDraw then
                item:queueDraw()
            end

            if item.updateInterval then
                item.updateAccumulator = (item.updateAccumulator or 0) + dt
                if item.updateAccumulator >= item.updateInterval then
                    local updateDt = math.min(item.updateAccumulator, item.maxUpdateDt or item.updateAccumulator)
                    item.updateAccumulator = 0
                    item:update(updateDt)
                end
            else
                item:update(dt)
            end
        end

        if not (item and item.isAlive) then
            local lastIndex = #list
            list[i] = list[lastIndex]
            list[lastIndex] = nil
            if i <= #list then
                i = i + 1
            end
        end

        i = i - 1
    end
end

function Game:refreshNearbyEnemies()
    self.nearbyEnemies = self.nearbyEnemies or {}
    for i = #self.nearbyEnemies, 1, -1 do
        self.nearbyEnemies[i] = nil
    end
    local cameraPosition = camera:objectPosition()
    local distanceLimitSq = NEARBY_ENEMY_DISTANCE * NEARBY_ENEMY_DISTANCE

    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        local dx = enemy.x - cameraPosition.x
        local dy = enemy.y - cameraPosition.y
        if dx * dx + dy * dy <= distanceLimitSq then
            self.nearbyEnemies[#self.nearbyEnemies + 1] = enemy
        end
    end
end

function Game:markGrassNearEnemies(dt)
    if not (Tilemap and Tilemap.markGrassNearPoint) then
        return
    end

    self.enemyGrassMarkTimer = (self.enemyGrassMarkTimer or 0) + (dt or 0)
    if self.enemyGrassMarkTimer < 0.06 then
        return
    end
    self.enemyGrassMarkTimer = 0

    for _, enemy in ipairs(self.nearbyEnemies or {}) do
        if enemy.isAlive ~= false then
            Tilemap:markGrassNearPoint(enemy.x, enemy.y, 12, enemy.x)
        end
    end
end

function Game:updateFootsteps(dt)
    for i = #self.footsteps, 1, -1 do
        local footstep = self.footsteps[i]
        footstep:update(dt)
        if not footstep.isAlive or distance(Player, footstep) > FOOTSTEP_CLEANUP_DISTANCE then
            table.remove(self.footsteps, i)
        end
    end
end

function Game:addWeaponShockwave(x, y, config)
    if not (x and y) then
        return
    end

    config = config or {}
    self.weaponShockwaves = self.weaponShockwaves or {}
    self.weaponShockwaves[#self.weaponShockwaves + 1] = {
        x = x,
        y = y,
        timer = 0,
        duration = config.duration or 0.28,
        radius = config.radius or 34,
        width = config.width or 7,
        intensity = config.intensity or 2.2,
    }
end

function Game:updateWeaponShockwaves(dt)
    for i = #(self.weaponShockwaves or {}), 1, -1 do
        local wave = self.weaponShockwaves[i]
        wave.timer = wave.timer + dt
        if wave.timer >= wave.duration then
            table.remove(self.weaponShockwaves, i)
        end
    end
end

function Game:getWeaponShockwaves()
    return self.weaponShockwaves or {}
end

function Game:startHitStop(duration, recoveryDuration)
    self.hitStopTimer = math.max(self.hitStopTimer or 0, duration or 0.1)
    self.hitStopDuration = self.hitStopTimer
    self.hitStopRecoveryTimer = recoveryDuration or 0.08
    self.hitStopRecoveryDuration = self.hitStopRecoveryTimer
end

function Game:getHitStopTimeScale(dt)
    if (self.hitStopTimer or 0) > 0 then
        self.hitStopTimer = math.max(0, self.hitStopTimer - dt)
        self.hitStopActive = true
        return 0
    end

    self.hitStopActive = false
    if (self.hitStopRecoveryTimer or 0) <= 0 then
        return 1
    end

    self.hitStopRecoveryTimer = math.max(0, self.hitStopRecoveryTimer - dt)
    local duration = math.max(self.hitStopRecoveryDuration or 0.001, 0.001)
    local progress = 1 - (self.hitStopRecoveryTimer / duration)
    local eased = progress * progress * (3 - 2 * progress)
    return math.max(0, math.min(1, eased))
end

function Game:updateManagers(dt)
    Tutorial:update(dt)
    WaveManager:update(dt)
    Clouds:update(dt)
    if CardChoice:isActive() then
        Dialog.breakMovements = true
    end
    if FloorIntroManager:isActive() then
        Dialog.breakMovements = true
        if FloorIntroManager:hasFloorIntro() and Player and Player.isAlive then
            Player.velocityX = 0
            Player.velocityY = 0
            Player:updateAnimation(dt, false)
            Player.gun:update(dt, Player.x, Player.y)
            addToDrawQueue(Player.y + 6, Player)
        end
    elseif self:updateRoomExitTransition(dt) then
        -- Player is controlled by the room-exit sequence.
    elseif not self:updateEntryMove(dt) then
        Player:update(dt)
    end
    DoorsManager:update(dt)
    HeartSound:update(dt)
    Tilemap:update(dt)
    self:checkRoomTransition(dt)
    PointsManager:update(dt)
    CardChoice:update(dt)
    camera:update(dt)
end

function Game:update(dt)
    ACTIVE_LIGHT_MANAGER = self
    self.drawQueue = self.drawQueue or {}
    for i = #self.drawQueue, 1, -1 do
        self.drawQueue[i] = nil
    end
    self.groundDecalQueue = self.groundDecalQueue or {}
    for i = #self.groundDecalQueue, 1, -1 do
        self.groundDecalQueue[i] = nil
    end
    self.lightSources = self.lightSources or {}
    for i = #self.lightSources, 1, -1 do
        self.lightSources[i] = nil
    end
    self.projectileLightCount = 0
    self.enemyProjectileLightCount = 0
    self.bulletColorParticleCount = 0
    self.bulletSpriteParticleCount = 0
    self.projectileDrawCount = 0
    self.lightSourcesCacheDirty = true
    self.fogTime = self.fogTime + dt

    self:updateSpotlight(dt)
    self:updateAmbientTimers(dt)
    self:updatePitch(dt)
    PlayerVisualEffects.update(dt)
    if Player and Player.updateDamageVignette then
        Player:updateDamageVignette(dt)
    end
    local showingThanks = FloorIntroManager:hasThanksScreen()

    self.textAlpha = transitionValue(self.textAlpha, self.textAlphaTarget, 5, dt)
    self.textAlphaTarget = 0
    if (self.bottomMessageTimer or 0) > 0 then
        self.bottomMessageTimer = math.max(0, self.bottomMessageTimer - dt)
        self.drawtext = self.bottomMessageText or self.drawtext
        self.textAlphaTarget = 1
    end

    local worldDt = dt * self:getHitStopTimeScale(dt)

    local currentRoom = FloorManager:getCurrentRoom()
    if not (CURRENT_LEVEL and CURRENT_LEVEL.skipStartRoomSafetyLogic)
        and currentRoom
        and (currentRoom.templateId == "start_32x32" or isStartRoom(currentRoom)) then
        for index = #(self.enemies or {}), 1, -1 do
            if getmetatable(self.enemies[index]) ~= Scarecrow then
                table.remove(self.enemies, index)
            end
        end
    end

    if not showingThanks then
        if CURRENT_LEVEL and CURRENT_LEVEL.update then
            CURRENT_LEVEL:update(self, worldDt)
        end

        if EnemyDirector and EnemyDirector.beginFrame then
            EnemyDirector:beginFrame(#(self.enemies or {}))
        end
        self:updateEntityList(self.enemies, worldDt)
        self:rebuildEnemySpatialIndex()
        self:checkCurrentRoomClear()
        self:updateBattleMusicForCurrentRoom()
        self:refreshNearbyEnemies()
        self:markGrassNearEnemies(worldDt)
        PlayerCloseStore = false
        self:updateEntityList(self.objects, worldDt)
        self:updateParticleList(worldDt)
        self:updateFootsteps(worldDt)
        self:updateWeaponShockwaves(worldDt)
        self:updateManagers(worldDt)
    end
end

function Game:addLightSource(lightType, x, y, options)
    local config = LightConfig:getWorldLightConfig(lightType)
    if not (config and config.enabled ~= false and x and y) then
        return
    end

    if not isLightNearPlayer(config, x, y) and not isGroundLightNearCamera(config, x, y) then
        return
    end

    if lightType == "projectile" then
        self.projectileLightCount = (self.projectileLightCount or 0) + 1
        if self.projectileLightCount > MAX_PLAYER_PROJECTILE_LIGHTS then
            return
        end
    elseif lightType == "enemyProjectile" then
        self.enemyProjectileLightCount = (self.enemyProjectileLightCount or 0) + 1
        if self.enemyProjectileLightCount > MAX_ENEMY_PROJECTILE_LIGHTS then
            return
        end
    end

    options = options or {}
    local spriteBrightness = config.spriteBrightness
    local spriteMaxDistance = spriteBrightness and (spriteBrightness.maxDistance or 230) or nil
    self.lightSources = self.lightSources or {}
    self.lightSources[#self.lightSources + 1] = {
        type = lightType,
        x = x,
        y = y,
        config = config,
        visual = config.visual,
        spriteBrightness = spriteBrightness,
        spriteMinDistance = spriteBrightness and (spriteBrightness.minDistance or 35) or nil,
        spriteMaxDistance = spriteMaxDistance,
        spriteMaxDistanceSq = spriteMaxDistance and spriteMaxDistance * spriteMaxDistance or nil,
        spriteMaxBrightness = spriteBrightness and (spriteBrightness.maxBrightness or 1) or nil,
        flicker = options.flicker or 1,
    }
    self.lightSourcesCacheDirty = true
end

function Game:getLightSources()
    if not self.lightSourcesCacheDirty and self.lightSourcesCache then
        local ps = self.playerLightSource
        if ps and Player and Player.isAlive then
            ps.x = Player.x
            ps.y = Player.y
        end
        return self.lightSourcesCache
    end

    local sources = self.lightSourcesCache or {}
    for i = #sources, 1, -1 do
        sources[i] = nil
    end

    local playerConfig = LightConfig:getWorldLightConfig("player")

    if Player and Player.isAlive and playerConfig and playerConfig.enabled ~= false then
        local playerSource = self.playerLightSource or {}
        playerSource.type = "player"
        playerSource.x = Player.x
        playerSource.y = Player.y
        playerSource.config = playerConfig
        playerSource.visual = playerConfig.visual
        playerSource.spriteBrightness = playerConfig.spriteBrightness
        playerSource.spriteMinDistance = playerConfig.spriteBrightness and (playerConfig.spriteBrightness.minDistance or 35) or nil
        playerSource.spriteMaxDistance = playerConfig.spriteBrightness and (playerConfig.spriteBrightness.maxDistance or 230) or nil
        playerSource.spriteMaxDistanceSq = playerSource.spriteMaxDistance and playerSource.spriteMaxDistance * playerSource.spriteMaxDistance or nil
        playerSource.spriteMaxBrightness = playerConfig.spriteBrightness and (playerConfig.spriteBrightness.maxBrightness or 1) or nil
        playerSource.flicker = 1
        self.playerLightSource = playerSource
        sources[#sources + 1] = playerSource
    end

    for _, source in ipairs(self.lightSources or {}) do
        sources[#sources + 1] = source
    end

    self.lightSourcesCache = sources
    self.lightSourcesCacheDirty = false
    self.lightSourcesVersion = (self.lightSourcesVersion or 0) + 1
    return sources
end

function Game:crowNoise()
    AmbienceSound:playCrowSound()
end

function Game:cricketNoise()
    AmbienceSound:playCricketSound()
end

function Game:drawRoomFade()
    local alpha = self.roomFadeAlpha or 0
    if alpha <= 0 then
        return
    end

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, baseWidth, baseHeight)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:drawFloorIntro()
    FloorIntroManager:drawFloor()
end

function Game:drawThanksScreen()
    FloorIntroManager:drawThanks()
end

function Game:draw()
    WorldRenderer.draw(self)
end

function Game:markHUDDirty()
    GameHud.markDirty()
end

function Game:drawHUD()
    GameHud.draw(self)
end

function DisableMouseTutorial()
    if Tutorial.drawmouse == false then return end
    Tutorial:playSound()
    Tutorial.drawmouse = false
    Tutorial.tutorialTimer = 0
end

function DisableInteractTutorial()
    if Tutorial.drawInteract == false then return end
    Tutorial:playSound()
    Tutorial.drawInteract = false
    Tutorial.drawmouse = true
    Tutorial.tutorialTimer = 0
end

function DisableWalkTutorial()
    local state = FloorManager:getCurrentRoomState()
    if state and state.startRoomScarecrowEncounter then
        if Tutorial.drawWalk then
            Tutorial:playSound()
        end
        Tutorial.drawWalk = false
        Tutorial.drawInteract = false
        Tutorial.drawmouse = false
        Tutorial.tutorialTimer = 0
        state.playerMovedForScarecrowTutorial = true
        return
    end

    if Tutorial.drawWalk == false then return end
    Tutorial:playSound()
    Tutorial.drawWalk = false
    Tutorial.drawInteract = true
    Tutorial.tutorialTimer = 0
end

function Game:keypressed(key)
    if CardChoice:isActive() and CardChoice:keypressed(key) then
        return
    end

    local playerActionLocked = Player and Player.isActionLocked and Player:isActionLocked()

    if key == "space" then
        if Player and Player.tryDash then
            Player:tryDash()
        end
    elseif key == "1" then
        if not playerActionLocked and Player and Player.gun then
            Player.gun:selectSlot(1)
        end
    elseif key == "2" then
        if not playerActionLocked and Player and Player.gun then
            Player.gun:selectSlot(2)
        end
    elseif key == "e" then
        if not playerActionLocked and Player and Player.gun then
            Player.gun:toggleWeaponSlot()
        end
    elseif key == "q" then
        if not playerActionLocked and Player and Player.gun then
            Player.gun:reloadSelectedWeapon()
        end
    elseif key == "f" then
        if playerActionLocked then
            return
        end
        if not Dialog.visible then
            Tilemap:keypressed(key)
            for i = #self.objects, 1, -1 do
                local object = self.objects[i]
                if object.isAlive and type(object.keypressed) == "function" then
                    object:keypressed(key)
                end
            end
        else
            CreatorManager:keypressed(key)
        end
    elseif key == "o" then
        --DoorsManager:openSouth()
    elseif key == "n" then
        --DoorsManager:openNorth()
    elseif tonumber(key) then
        --self:changeShaders(tonumber(key))
    end
end

function Game:mousepressed(x, y, button)
    if CardChoice:isActive() then
        return CardChoice:mousepressed(x, y, button)
    end
    return false
end

function Game:startCardChoice(x, y, options)
    CardChoice:start(x, y, options)
end

return Game
