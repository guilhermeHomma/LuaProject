local Settings = {}

local function containsResolution(presets, width, height)
    for _, preset in ipairs(presets) do
        if preset.width == width and preset.height == height then
            return true
        end
    end

    return false
end

local function getDesktop16x9Bounds()
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
    local maxWidth = math.min(desktopWidth, math.floor(desktopHeight * 16 / 9))
    local maxHeight = math.floor(maxWidth * 9 / 16)

    if maxHeight > desktopHeight then
        maxHeight = desktopHeight
        maxWidth = math.floor(maxHeight * 16 / 9)
    end

    return maxWidth, maxHeight
end

function Settings:buildResolutionPresets()
    local maxWidth, maxHeight = getDesktop16x9Bounds()
    local presets = {
        { width = 960, height = 540 },
        { width = 1120, height = 630 },
        { width = 1280, height = 720 },
        { width = 1600, height = 900 },
        { width = 1920, height = 1080 },
        { width = 2560, height = 1440 },
    }

    self.resolutionPresets = {}

    for _, preset in ipairs(presets) do
        if preset.width <= maxWidth and preset.height <= maxHeight then
            self.resolutionPresets[#self.resolutionPresets + 1] = {
                width = preset.width,
                height = preset.height,
            }
        end
    end

    if not containsResolution(self.resolutionPresets, maxWidth, maxHeight) then
        self.resolutionPresets[#self.resolutionPresets + 1] = {
            width = maxWidth,
            height = maxHeight,
        }
    end

    if #self.resolutionPresets == 0 then
        self.resolutionPresets[1] = {
            width = maxWidth,
            height = maxHeight,
        }
    end
end

function Settings:load()
    self.masterVolume = SOUND_VOLUME or 1
    self.musicVolume = MUSIC_VOLUME or 0.6
    self.fullscreen = love.window.getFullscreen()
    self:buildResolutionPresets()
    self.resolutionIndex = 1
    self:syncResolutionIndex()
    self:applyAudio()
end

function Settings:syncResolutionIndex()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    for i, preset in ipairs(self.resolutionPresets) do
        if preset.width == windowWidth and preset.height == windowHeight then
            self.resolutionIndex = i
            return
        end
    end
end

function Settings:applyAudio()
    SOUND_VOLUME = self.masterVolume
    MUSIC_VOLUME = self.musicVolume
    love.audio.setVolume(self.masterVolume)
end

function Settings:getResolutionLabel()
    local preset = self.resolutionPresets[self.resolutionIndex]
    return string.format("%dx%d", preset.width, preset.height)
end

function Settings:getFullscreenLabel()
    return self.fullscreen and "on" or "off"
end

function Settings:getMasterPercent()
    return math.floor(self.masterVolume * 100 + 0.5)
end

function Settings:getMusicPercent()
    return math.floor(self.musicVolume * 100 + 0.5)
end

function Settings:setResolutionIndex(index)
    self:buildResolutionPresets()

    if index < 1 then
        index = #self.resolutionPresets
    elseif index > #self.resolutionPresets then
        index = 1
    end

    self.resolutionIndex = index
    self:applyWindowMode()
end

function Settings:applyWindowMode()
    local preset = self.resolutionPresets[self.resolutionIndex]
    self.fullscreen = self.fullscreen == true
    love.window.setMode(preset.width, preset.height, {
        resizable = false,
        fullscreen = self.fullscreen,
        fullscreentype = "desktop",
        vsync = 0,
    })

    local width, height = love.graphics.getDimensions()
    if updateWindowLayout then
        updateWindowLayout(width, height)
    else
        local GameConfig = require("scripts/config/gameConfig")
        GameConfig:updateWindowScale(width, height)
        if camera and camera.resize then
            camera:resize(width, height)
        end
    end
end

function Settings:cycleResolution(direction)
    self:setResolutionIndex(self.resolutionIndex + direction)
end

function Settings:setFullscreen(enabled)
    self.fullscreen = enabled == true
    self:applyWindowMode()
end

function Settings:toggleFullscreen()
    self:setFullscreen(not self.fullscreen)
end

function Settings:setMasterVolume(value)
    self.masterVolume = clamp(value, 0, 1)
    self:applyAudio()
end

function Settings:adjustMasterVolume(step)
    self:setMasterVolume(self.masterVolume + step)
end

function Settings:setMusicVolume(value)
    self.musicVolume = clamp(value, 0, 1)
    self:applyAudio()
end

function Settings:adjustMusicVolume(step)
    self:setMusicVolume(self.musicVolume + step)
end

return Settings
