local ParallelParticles = {}
local MIN_BATCH = 64
local MAX_WAIT = 0.15

local thread, requests, results, disabled
local generation, nextId, nextBatchId = 0, 0, 0
local currentList, pending

local function ensureWorker()
    if disabled then return false end
    if thread then
        if thread:getError() then disabled = true return false end
        return true
    end
    if not (love.thread and love.thread.newThread) then return false end
    local ok, worker, input, output = pcall(function()
        local requestChannel = love.thread.newChannel()
        local resultChannel = love.thread.newChannel()
        local workerThread = love.thread.newThread("scripts/particles/particleUpdateWorker.lua")
        workerThread:start(requestChannel, resultChannel)
        return workerThread, requestChannel, resultChannel
    end)
    if not ok then disabled = true return false end
    thread, requests, results = worker, input, output
    return true
end

local function applyResult(batch, updates)
    for _, update in ipairs(updates) do
        local particle = batch.particles[update.id]
        if particle and particle.isAlive then
            particle.x, particle.y = update.x, update.y
            particle.vx, particle.vy = update.vx, update.vy
            particle.timer = update.timer
            particle.isAlive = update.isAlive
            if particle.parallelKind == "ball" then
                particle.radius = update.radius
                particle.speed = update.speed
                particle.height = update.height
            elseif particle.parallelKind == "walkBall" then
                particle.radius = update.radius
                particle.alpha = update.alpha
                particle.height = update.height
            elseif particle.parallelKind == "walkSquare" then
                particle.alpha = update.alpha
            elseif particle.parallelKind == "bloodPixel" then
                particle.height = update.height
                particle.heightVelocity = update.heightVelocity
                particle.grounded = update.grounded
                particle.groundedTimer = update.groundedTimer
                if update.freezeColor and not particle.frozenColor then
                    local palette = particle.palette
                    if palette and #palette > 0 then
                        local index = (math.floor(particle.timer * 12 + particle.colorOffset) % #palette) + 1
                        particle.frozenColor = palette[index]
                    end
                end
            end
        end
    end
end

function ParallelParticles:beginFrame(list)
    if currentList ~= list then
        currentList = list
        generation = generation + 1
        pending = nil
        if requests then requests:clear() end
        if results then results:clear() end
    end

    if results then
        while true do
            local result = results:pop()
            if not result then break end
            if pending and result.id == pending.id and result.generation == generation then
                applyResult(pending, result.items)
                pending = nil
            end
        end
    end

    if pending and (thread:getError() or love.timer.getTime() - pending.startedAt > MAX_WAIT) then
        pending = nil
        disabled = true
    end

    local eligible = 0
    for _, particle in ipairs(list) do
        if particle.isAlive and particle.parallelKind then
            eligible = eligible + 1
        end
    end
    return pending ~= nil or (eligible >= MIN_BATCH and ensureWorker())
end

function ParallelParticles:isPending()
    return pending ~= nil
end

function ParallelParticles:dispatch(items, particles)
    if #items == 0 or pending or not ensureWorker() then return end
    nextBatchId = nextBatchId + 1
    pending = {id = nextBatchId, generation = generation, particles = particles, startedAt = love.timer.getTime()}
    requests:push({id = nextBatchId, generation = generation, items = items})
end

function ParallelParticles:makeItem(particle, dt)
    nextId = nextId + 1
    local item = {
        id = nextId, kind = particle.parallelKind, dt = dt,
        x = particle.x, y = particle.y, vx = particle.vx, vy = particle.vy,
        timer = particle.timer, lifeTime = particle.lifeTime,
    }
    if particle.parallelKind == "bulletColor" then
        item.wobblePhase = particle.wobblePhase
    elseif particle.parallelKind == "ball" then
        item.dx, item.dy = particle.dx, particle.dy
        item.speed, item.speedDown = particle.speed, particle.speedDown
        item.initialRadius = particle.initialRadius
        item.height = particle.height
    elseif particle.parallelKind == "walkBall" then
        item.radius, item.alpha = particle.radius, particle.alpha
        item.height, item.speedDown = particle.height, particle.speedDown
    elseif particle.parallelKind == "walkSquare" then
        item.alpha = particle.alpha
    elseif particle.parallelKind == "bloodPixel" then
        item.height = particle.height
        item.heightVelocity = particle.heightVelocity
        item.gravity = particle.gravity
        item.grounded = particle.grounded
        item.groundedTimer = particle.groundedTimer or 0
        item.colorFreezeDelay = particle.colorFreezeDelay or 0.16
        item.hasFrozenColor = particle.frozenColor ~= nil
    end
    return item
end

return ParallelParticles
