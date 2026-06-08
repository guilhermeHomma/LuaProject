local PlayerDamageFlash = require("scripts/effects/playerDamageFlash")

local PlayerVisualEffects = {}
local damageFlash = PlayerDamageFlash:new()

local function getDamageFlashPoint(player, dx, dy, hitX, hitY)
    if hitX and hitY then
        return hitX, hitY
    end

    if not player then
        return 0, 0
    end

    local centerX = player.x or 0
    local centerY = (player.y or 0) - (player.damageFlashCenterYOffset or 18)
    dx = dx or 0
    dy = dy or -1

    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.001 then
        return centerX, centerY
    end

    local radiusX = player.damageFlashRadiusX or 8
    local radiusY = player.damageFlashRadiusY or 13
    return centerX - (dx / length) * radiusX, centerY - (dy / length) * radiusY
end

function PlayerVisualEffects.reset()
    damageFlash.instances = {}
end

function PlayerVisualEffects.showDamageFlash(player, dx, dy, hitX, hitY)
    local x, y = getDamageFlashPoint(player, dx, dy, hitX, hitY)
    damageFlash:spawn(x, y, dx, dy)
end

function PlayerVisualEffects.update(dt)
    damageFlash:update(dt)
end

function PlayerVisualEffects.draw(camera, viewportScale)
    damageFlash:draw(camera, viewportScale)
end

return PlayerVisualEffects
