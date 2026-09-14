local requests, results = ...

while true do
    local request = requests:demand()
    if request == false then break end

    local output = {}
    for i, item in ipairs(request.items) do
        local dt = item.dt
        local timer = item.timer + dt
        local x, y = item.x, item.y
        local vx, vy = item.vx, item.vy
        local state = {id = item.id, timer = timer}

        if item.kind == "bulletColor" then
            local wobble = item.wobblePhase + timer * 18
            vx = (vx + math.cos(wobble) * 18 * dt) * math.max(0, 1 - 1.6 * dt)
            vy = (vy + math.sin(wobble * 0.83) * 18 * dt) * math.max(0, 1 - 1.6 * dt)
            x = x + vx * dt
            y = y + vy * dt
        elseif item.kind == "ball" then
            x = x + item.dx * item.speed * dt
            y = y + item.dy * item.speed * dt
            state.radius = item.initialRadius * (1 - timer / item.lifeTime)
            state.speed = math.max(0, item.speed - 33 * dt)
            state.height = item.height + item.speedDown * dt
        elseif item.kind == "walkBall" then
            state.radius = item.radius + 0.1 * dt
            state.alpha = item.alpha - 2 * dt
            state.height = item.height + item.speedDown * dt
        elseif item.kind == "walkSquare" then
            state.alpha = item.alpha - 0.4 * dt
        elseif item.kind == "bloodPixel" then
            x = x + vx * dt
            y = y + vy * dt
            local height = item.height
            local heightVelocity = item.heightVelocity
            local grounded = item.grounded
            local groundedTimer = item.groundedTimer
            if not grounded then
                height = height + heightVelocity * dt
                heightVelocity = heightVelocity - item.gravity * dt
                if height <= 0 then
                    height = 0
                    grounded = true
                    groundedTimer = 0
                    vx = vx * 0.35
                    vy = vy * 0.35
                end
            else
                groundedTimer = groundedTimer + dt
                if not item.hasFrozenColor and groundedTimer >= item.colorFreezeDelay then
                    state.freezeColor = true
                end
                local friction = math.max(0, 1 - 7 * dt)
                vx = vx * friction
                vy = vy * friction
            end
            state.height = height
            state.heightVelocity = heightVelocity
            state.grounded = grounded
            state.groundedTimer = groundedTimer
        end

        state.x, state.y, state.vx, state.vy = x, y, vx, vy
        state.isAlive = timer < item.lifeTime
        output[i] = state
    end
    results:push({id = request.id, generation = request.generation, items = output})
end
