local DropShine = {}

local shader = love.graphics.newShader("scripts/shaders/dropShine.glsl")

function DropShine.draw(image, quad, x, y, rotation, scaleX, scaleY, originX, originY)
    local quadX, quadY, quadWidth, quadHeight = quad:getViewport()
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()

    shader:send("u_time", love.timer.getTime())
    shader:send("u_uvMin", {quadX / imageWidth, quadY / imageHeight})
    shader:send("u_uvMax", {(quadX + quadWidth) / imageWidth, (quadY + quadHeight) / imageHeight})

    love.graphics.setShader(shader)
    love.graphics.draw(image, quad, x, y, rotation, scaleX, scaleY, originX, originY)
    love.graphics.setShader()
end

return DropShine
