local AmbienceEvents = {}

local FloorManager = require("scripts/managers/floorManager")

local CONFIG = {
    florest = {
        crow = {enabled = true, min = 40, max = 300, volume = {min = 0.018, max = 0.032}, pitch = {min = 0.90, max = 1.02}},
        owl = {enabled = true, min = 40, max = 300, volume = {min = 0.012, max = 0.025}, pitch = {min = 0.88, max = 1.00}},
        cricket = {enabled = true, min = 14, max = 60, volume = {min = 0.030, max = 0.055}, pitch = {min = 0.96, max = 1.08}},
    },
    cave = {
        crow = {enabled = false},
        owl = {enabled = false},
        cricket = {enabled = true, min = 8, max = 45, volume = {min = 0.035, max = 0.060}, pitch = {min = 0.88, max = 1.00}},
    },
}

local sounds = {
    crow = {
        "assets/sfx/ambience/crow.mp3",
        "assets/sfx/ambience/crow2.mp3",
    },
    owl = {
        "assets/sfx/ambience/owl.mp3",
    },
    cricket = {
        "assets/sfx/ambience/crickets.mp3",
        "assets/sfx/ambience/cricket.mp3",
    },
}

local function randomRange(range)
    return (range.min or 0) + math.random() * ((range.max or range.min or 0) - (range.min or 0))
end

local function getThemeId()
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    return theme and theme.id or "florest"
end

local function getEventConfig(eventId)
    local themeId = getThemeId()
    local themeConfig = CONFIG[themeId] or CONFIG.florest
    local eventConfig = themeConfig[eventId] or CONFIG.florest[eventId]
    local theme = FloorManager.getCurrentRoomTheme and FloorManager:getCurrentRoomTheme() or nil
    local ambience = theme and theme.ambience or {}

    if ambience[eventId] == false then
        return {enabled = false, min = eventConfig.min, max = eventConfig.max}
    end

    return eventConfig
end

function AmbienceEvents:load()
    self.timers = {}
    for eventId in pairs(sounds) do
        self:resetTimer(eventId)
    end
end

function AmbienceEvents:resetTimer(eventId)
    local config = getEventConfig(eventId) or {}
    local minTime = config.min or 20
    local maxTime = config.max or minTime
    self.timers = self.timers or {}
    self.timers[eventId] = randomRange({min = minTime, max = maxTime})
end

function AmbienceEvents:play(eventId)
    local config = getEventConfig(eventId)
    if not (config and config.enabled ~= false) then
        self:resetTimer(eventId)
        return
    end

    local list = sounds[eventId]
    local path = list and list[math.random(1, #list)]
    if not path then
        return
    end

    local sound = love.audio.newSource(path, "static")
    sound:setVolume(randomRange(config.volume or {min = 0.02, max = 0.05}) * (SOUND_VOLUME or 1))
    sound:setPitch(randomRange(config.pitch or {min = 1, max = 1}) * (GAME_PITCH or 1))

    if eventId == "crow" or eventId == "owl" then
        local angle = math.random() * math.pi * 2
        local distance = 0.35 + math.random() * 0.65
        pcall(function()
            sound:setPosition(math.cos(angle) * distance, 0.4, math.sin(angle) * distance)
        end)
    end

    sound:play()
    self:resetTimer(eventId)
end

function AmbienceEvents:update(dt)
    if not (state == STATES.game and Player and Player.isAlive) then
        return
    end

    for eventId in pairs(sounds) do
        local config = getEventConfig(eventId)
        if not (config and config.enabled ~= false) then
            self:resetTimer(eventId)
        else
            self.timers[eventId] = (self.timers[eventId] or 0) - dt
            if self.timers[eventId] <= 0 then
                self:play(eventId)
            end
        end
    end
end

return AmbienceEvents
