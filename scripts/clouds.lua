local Clouds = {}
local FloorManager = require("scripts/managers/floorManager")

local function currentThemeAllowsClouds()
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    return not theme or theme.clouds ~= false
end


function Clouds:load(target)
    self.image = love.graphics.newImage("assets/sprites/cloud.png")
    self.image:setFilter("nearest", "nearest")
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.movement = 0
    self.target = target
    self.layers = {
        {
            alpha = 0.1,
            height = 70,
            parallax = 1.10,
            scale = 1,
            movementScale = 0.5,
        },
        {
            alpha = 0.05,
            height = 108,
            parallax = 1.20,
            scale = 2.2,
            movementScale = 0.75,
        },
    }
end

function Clouds:update(dt)
    if not currentThemeAllowsClouds() then
        return
    end

    local speed = (math.sin(love.timer.getTime() * 0.2) + 3 ) / 4
    self.movement = self.movement + 10 * dt * speed
end

function Clouds:drawShadow()
    if not currentThemeAllowsClouds() then
        return
    end

    --self:drawCloud(true)
end


function Clouds:drawCloudLayer(layer, shadow)
    local scale = layer.scale or 1
    local width = self.width * scale
    local height = self.height * scale
    local cloudHeight = layer.height or 70
    local alpha = layer.alpha or 0.08

    love.graphics.setColor(1, 1, 1, alpha)
    if shadow == true then
        love.graphics.setColor(0, 0, 0, 0.04)
        cloudHeight = 0
    end

    local parallax = layer.parallax or 1
    local movement = self.movement * (layer.movementScale or 1)
    local cameraX = camera and camera.x and camera.x / WORLD_SCALE_X or 0
    local cameraY = camera and camera.y and camera.y / YSCALE or 0
    local parallaxOffsetX = -cameraX * (parallax - 1) - movement
    local parallaxOffsetY = -cameraY * (parallax - 1)
    local startX = math.floor((cameraX - parallaxOffsetX) / width) * width + parallaxOffsetX
    local startY = math.floor((cameraY - parallaxOffsetY) / height) * height + parallaxOffsetY

    local tilesX = math.ceil((baseWidth / math.max(WORLD_SCALE_X, 0.001)) / width) + 4
    local tilesY = math.ceil((baseHeight / math.max(YSCALE, 0.001)) / height) + 4

    for i = -1, tilesX do
        for j = -1, tilesY do
            love.graphics.draw(self.image, startX + i * width, startY - cloudHeight + j * height, 0, scale, scale)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function Clouds:drawCloud(shadow)
    for _, layer in ipairs(self.layers or {}) do
        self:drawCloudLayer(layer, shadow)
    end
end

function Clouds:draw()
    if not currentThemeAllowsClouds() then
        return
    end

    self:drawCloud(false)
end

return Clouds
