local AliceAnimation = {}

local ROOT = "assets/sprites/player/alice/"
local FRAME_SIZE = 40

local ANIMATIONS = {
    idle = { file = "idle", frameCount = 5, frameTime = 0.2 },
    walk = { file = "run", frameCount = 6, frameTime = 0.1 },
}

local DIRECTIONS = { "side", "front", "back" }

local function createStripQuads(image, frameCount)
    local quads = {}
    local width, height = image:getDimensions()
    for frame = 0, frameCount - 1 do
        quads[frame + 1] = love.graphics.newQuad(
            frame * FRAME_SIZE,
            0,
            FRAME_SIZE,
            FRAME_SIZE,
            width,
            height
        )
    end
    return quads
end

function AliceAnimation.load(player)
    player.aliceAnimations = {}

    for animationName, config in pairs(ANIMATIONS) do
        local animation = {
            frameCount = config.frameCount,
            frameTime = config.frameTime,
            directions = {},
        }

        for _, direction in ipairs(DIRECTIONS) do
            local path = ROOT .. direction .. "/" .. config.file
            local bodyImage = love.graphics.newImage(path .. ".png")
            local handImage = love.graphics.newImage(path .. "-hand.png")
            bodyImage:setFilter("nearest", "nearest")
            handImage:setFilter("nearest", "nearest")

            animation.directions[direction] = {
                bodyImage = bodyImage,
                handImage = handImage,
                bodyQuads = createStripQuads(bodyImage, config.frameCount),
                handQuads = createStripQuads(handImage, config.frameCount),
            }
        end

        player.aliceAnimations[animationName] = animation
    end

    AliceAnimation.reset(player, "idle")
end

function AliceAnimation.reset(player, animationName)
    player.currentAnimation = animationName or "idle"
    player.currentFrame = 1
    player.animationTimer = 0
end

function AliceAnimation.getDirection(player)
    if (player.moveX or 0) == 0 then
        if (player.moveY or 0) > 0 then
            return "front"
        elseif (player.moveY or 0) < 0 then
            return "back"
        end
    end
    return "side"
end

function AliceAnimation.update(player, dt, moving)
    local animationName = moving and "walk" or "idle"
    local changedAnimation = player.currentAnimation ~= animationName
    local runSteps = changedAnimation and moving and 1 or 0

    if changedAnimation then
        AliceAnimation.reset(player, animationName)
    end

    local animation = player.aliceAnimations[animationName]
    player.animationTimer = (player.animationTimer or 0) + dt

    local advancedFrames = 0
    while player.animationTimer >= animation.frameTime and advancedFrames < 4 do
        player.animationTimer = player.animationTimer - animation.frameTime
        player.currentFrame = player.currentFrame % animation.frameCount + 1
        advancedFrames = advancedFrames + 1
        if moving and (player.currentFrame == 1 or player.currentFrame == 4) then
            runSteps = runSteps + 1
        end
    end

    return changedAnimation, advancedFrames, runSteps
end

function AliceAnimation.getCurrentFrame(player)
    local animation = player.aliceAnimations[player.currentAnimation]
    local direction = animation.directions[AliceAnimation.getDirection(player)]
    local frame = math.min(player.currentFrame or 1, animation.frameCount)

    return {
        bodyImage = direction.bodyImage,
        bodyQuad = direction.bodyQuads[frame],
        handImage = direction.handImage,
        handQuad = direction.handQuads[frame],
        frame = frame,
        frameTime = animation.frameTime,
        frameCount = animation.frameCount,
    }
end

return AliceAnimation
