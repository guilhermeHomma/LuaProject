local Settings = {}
local SettingsStorage = require("scripts/managers/settingsStorage")
local Localization = require("scripts/managers/localization")

local BRIGHTNESS_MIN = 0
local BRIGHTNESS_MAX = 10
local BRIGHTNESS_DEFAULT = 5

local function clampInteger(value, minValue, maxValue)
    value = math.floor((tonumber(value) or minValue) + 0.5)
    return math.max(minValue, math.min(maxValue, value))
end

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

function Settings:save()
    if self.loading then
        return
    end

    local preset = self.resolutionPresets and self.resolutionPresets[self.resolutionIndex] or {}
    SettingsStorage:write(SettingsStorage:encode(SettingsStorage:serialize({
        width = preset.width,
        height = preset.height,
        fullscreen = self.fullscreen,
        vsyncEnabled = self.vsyncEnabled,
        crtEnabled = self.crtEnabled,
        cameraShakeEnabled = self.cameraShakeEnabled,
        fpsEnabled = self.fpsEnabled,
        language = self.language,
        brightness = self.brightness,
        masterVolume = self.masterVolume,
        musicVolume = self.musicVolume,
    })))
end

function Settings:loadSavedSettings()
    local saved = SettingsStorage:loadSaved()
    if not saved then
        return
    end

    self.masterVolume = clamp(tonumber(saved.master) or self.masterVolume, 0, 1)
    self.musicVolume = clamp(tonumber(saved.music) or self.musicVolume, 0, 1)
    self.fullscreen = saved.fs == "1"
    self.vsyncEnabled = saved.vs == "1"
    self.crtEnabled = saved.crt == "1"
    self.cameraShakeEnabled = saved.shake ~= "0"
    self.fpsEnabled = saved.fps == "1"
    self.language = saved.lang or self.language
    self.brightness = clampInteger(saved.brightness or self.brightness, BRIGHTNESS_MIN, BRIGHTNESS_MAX)

    local width = tonumber(saved.w)
    local height = tonumber(saved.h)
    if width and height then
        for i, preset in ipairs(self.resolutionPresets or {}) do
            if preset.width == width and preset.height == height then
                self.resolutionIndex = i
                break
            end
        end
    end
end

function Settings:needsWindowModeApply()
    local preset = self.resolutionPresets and self.resolutionPresets[self.resolutionIndex]
    if not preset then
        return false
    end

    local width, height = love.graphics.getDimensions()
    local fullscreen = love.window.getFullscreen()
    if fullscreen ~= (self.fullscreen == true) then
        return true
    end

    if fullscreen then
        return false
    end

    return width ~= preset.width or height ~= preset.height
end

function Settings:load()
    self.loading = true
    Localization:load()
    self.masterVolume = SOUND_VOLUME or 1
    self.musicVolume = MUSIC_VOLUME or 0.6
    self.fullscreen = love.window.getFullscreen()
    self.crtEnabled = GAME_FLAGS and GAME_FLAGS.crt and GAME_FLAGS.crt.enabled == true
    self.cameraShakeEnabled = not (GAME_FLAGS and GAME_FLAGS.cameraShake == false)
    self.fpsEnabled = FPS == true
    self.language = Localization.currentLanguage or "en"
    self.vsyncEnabled = GAME_FLAGS and GAME_FLAGS.vsync == true
    self.brightness = GAME_FLAGS and GAME_FLAGS.brightness or BRIGHTNESS_DEFAULT
    self:buildResolutionPresets()
    self.resolutionIndex = 1
    self:syncResolutionIndex()
    self:loadSavedSettings()
    self:applyAudio()
    self:applyGeneral()
    self:applyVideoEffects()
    if self:needsWindowModeApply() then
        self:applyWindowMode()
    end
    self.loading = false
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

function Settings:applyGeneral()
    FPS = self.fpsEnabled == true
    Localization:setLanguage(self.language or "en")
end

function Settings:getResolutionLabel()
    local preset = self.resolutionPresets[self.resolutionIndex]
    return string.format("%dx%d", preset.width, preset.height)
end

function Settings:getFullscreenLabel()
    return self.fullscreen and Localization:t("settings.on") or Localization:t("settings.off")
end

function Settings:getCrtLabel()
    return self.crtEnabled and Localization:t("settings.on") or Localization:t("settings.off")
end

function Settings:getCameraShakeLabel()
    return self.cameraShakeEnabled and Localization:t("settings.on") or Localization:t("settings.off")
end

function Settings:getFpsLabel()
    return self.fpsEnabled and Localization:t("settings.on") or Localization:t("settings.off")
end

function Settings:getLanguageLabel()
    return Localization:getLanguageLabel()
end

function Settings:getVsyncLabel()
    return self.vsyncEnabled and Localization:t("settings.on") or Localization:t("settings.off")
end

function Settings:getBrightnessValue()
    return self.brightness or BRIGHTNESS_DEFAULT
end

function Settings:getBrightnessLabel()
    return tostring(self:getBrightnessValue())
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
    self:save()
end

function Settings:applyWindowMode()
    local preset = self.resolutionPresets[self.resolutionIndex]
    self.fullscreen = self.fullscreen == true
    love.window.setMode(preset.width, preset.height, {
        resizable = false,
        fullscreen = self.fullscreen,
        fullscreentype = "desktop",
        vsync = self.vsyncEnabled and 1 or 0,
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
    self:save()
end

function Settings:toggleFullscreen()
    self:setFullscreen(not self.fullscreen)
end

function Settings:applyVideoEffects()
    GAME_FLAGS = GAME_FLAGS or {}
    GAME_FLAGS.crt = GAME_FLAGS.crt or {}
    GAME_FLAGS.crt.enabled = self.crtEnabled == true
    GAME_FLAGS.cameraShake = self.cameraShakeEnabled ~= false
    GAME_FLAGS.vsync = self.vsyncEnabled == true
    GAME_FLAGS.brightness = clampInteger(self.brightness, BRIGHTNESS_MIN, BRIGHTNESS_MAX)

    if GAME_FLAGS.cameraShake == false and camera then
        camera.shakeIntensity = 0
        camera.shakeOffsetX = 0
        camera.shakeOffsetY = 0
    end
end

function Settings:setCrtEnabled(enabled)
    self.crtEnabled = enabled == true
    self:applyVideoEffects()
    self:save()
end

function Settings:toggleCrt()
    self:setCrtEnabled(not self.crtEnabled)
end

function Settings:setCameraShakeEnabled(enabled)
    self.cameraShakeEnabled = enabled == true
    self:applyVideoEffects()
    self:save()
end

function Settings:toggleCameraShake()
    self:setCameraShakeEnabled(not self.cameraShakeEnabled)
end

function Settings:setFpsEnabled(enabled)
    self.fpsEnabled = enabled == true
    self:applyGeneral()
    self:save()
end

function Settings:toggleFps()
    self:setFpsEnabled(not self.fpsEnabled)
end

function Settings:cycleLanguage(direction)
    Localization:cycleLanguage(direction or 1)
    self.language = Localization.currentLanguage
    self:applyGeneral()
    self:save()
end

function Settings:setVsyncEnabled(enabled)
    self.vsyncEnabled = enabled == true
    self:applyVideoEffects()
    self:applyWindowMode()
    self:save()
end

function Settings:toggleVsync()
    self:setVsyncEnabled(not self.vsyncEnabled)
end

function Settings:setBrightness(value)
    self.brightness = clampInteger(value, BRIGHTNESS_MIN, BRIGHTNESS_MAX)
    self:applyVideoEffects()
    self:save()
end

function Settings:adjustBrightness(step)
    self:setBrightness((self.brightness or BRIGHTNESS_DEFAULT) + step)
end

function Settings:setMasterVolume(value)
    self.masterVolume = clamp(value, 0, 1)
    self:applyAudio()
    self:save()
end

function Settings:adjustMasterVolume(step)
    self:setMasterVolume(self.masterVolume + step)
end

function Settings:setMusicVolume(value)
    self.musicVolume = clamp(value, 0, 1)
    self:applyAudio()
    self:save()
end

function Settings:adjustMusicVolume(step)
    self:setMusicVolume(self.musicVolume + step)
end

return Settings
