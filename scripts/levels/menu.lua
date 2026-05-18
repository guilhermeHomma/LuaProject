local MenuLevel = {}

MenuLevel.id = "menu"
MenuLevel.name = "Menu"
MenuLevel.baseWidth = 1280
MenuLevel.baseHeight = 720
MenuLevel.worldScaleX = 3
MenuLevel.yScale = 2.4
MenuLevel.renderDistances = {
    soft = 280,
    hard = 350,
    nearbyEnemy = 360,
    footstepCleanup = 250,
}
MenuLevel.spawnMinDistance = 240
MenuLevel.window = {
    width = 1280,
    height = 720,
}

function MenuLevel:getCameraBounds()
    return {}
end

function MenuLevel:resetRuntimeState()
end

function MenuLevel:getTilemapSystem()
    return require("scripts/tilemaps/defaultSystem")
end

function MenuLevel:getPlayerSpawn()
    return 30, 340
end

return MenuLevel
