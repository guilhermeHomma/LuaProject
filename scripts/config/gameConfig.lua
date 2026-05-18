local GameConfig = {}

GameConfig.referenceResolution = {
    width = 1120,
    height = 630,
}

GameConfig.currentLevel = nil
GameConfig.screenScale = 1
GameConfig.viewportOffsetX = 0
GameConfig.viewportOffsetY = 0

local function diagonal(width, height)
    return math.sqrt(width * width + height * height)
end

function GameConfig:syncGlobals()
    baseWidth = self.baseWidth
    baseHeight = self.baseHeight
    YSCALE = self.yScale
    WORLD_SCALE_X = self.worldScaleX
    RENDER_DISTANCE = self.renderDistance
    HARD_RENDER_DISTANCE = self.hardRenderDistance
    NEARBY_ENEMY_DISTANCE = self.nearbyEnemyDistance
    FOOTSTEP_CLEANUP_DISTANCE = self.footstepCleanupDistance
    CURRENT_LEVEL = self.currentLevel
    scale = self.screenScale
    viewportOffsetX = self.viewportOffsetX
    viewportOffsetY = self.viewportOffsetY
end

function GameConfig:applyLevel(level)
    self.currentLevel = level
    self.levelId = level.id
    if level.resetRuntimeState then
        level:resetRuntimeState()
    end
    self.baseWidth = level.baseWidth
    self.baseHeight = level.baseHeight
    self.worldScaleX = level.worldScaleX or 3
    self.yScale = level.yScale or 2.4
    self.tilemapConfig = level.tilemapConfig or {
        mapImage = "assets/sprites/map4.png",
        tilemapOrigin = { x = -40 * 16, y = -40 * 16 },
    }
    self.mapImage = self.tilemapConfig.mapImage
    self.tilemapOrigin = self.tilemapConfig.tilemapOrigin or { x = -40 * 16, y = -40 * 16 }
    self.spawnMinDistance = level.spawnMinDistance or 240

    local referenceDiagonal = diagonal(self.referenceResolution.width, self.referenceResolution.height)
    local renderScale = diagonal(self.baseWidth, self.baseHeight) / referenceDiagonal
    local renderDistances = level.renderDistances or {}

    self.renderDistance = (renderDistances.soft or 280) * renderScale
    self.hardRenderDistance = (renderDistances.hard or 350) * renderScale
    self.nearbyEnemyDistance = (renderDistances.nearbyEnemy or 360) * renderScale
    self.footstepCleanupDistance = (renderDistances.footstepCleanup or 250) * renderScale

    self:syncGlobals()
    return self
end

function GameConfig:updateWindowScale(width, height)
    self.screenScale = math.min(width / self.baseWidth, height / self.baseHeight)
    self.viewportOffsetX = math.floor((width - self.baseWidth * self.screenScale) / 2)
    self.viewportOffsetY = math.floor((height - self.baseHeight * self.screenScale) / 2)
    self:syncGlobals()
    return self.screenScale
end

function GameConfig:getCameraBounds()
    if self.currentLevel and self.currentLevel.getCameraBounds then
        return self.currentLevel:getCameraBounds()
    end
    return {}
end

function GameConfig:getTilemapSystem()
    if self.currentLevel and self.currentLevel.getTilemapSystem then
        return self.currentLevel:getTilemapSystem()
    end
    return require("scripts/tilemaps/defaultSystem")
end

return GameConfig
