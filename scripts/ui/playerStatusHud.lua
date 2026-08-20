local PlayerStatusHud = {}
local Localization = require("scripts/managers/localization")
local Fonts = require("scripts/ui/fonts")

local font = Fonts:translated("status")
local smallFont = Fonts:translated("statusSmall")
local titleFont = Fonts:translated("statusTitle")
local currentAlpha = 1

local HUD_WIDTH = 870
local HUD_HEIGHT = 200
local BORDER_SIZE = 4
local HUD_PADDING = 16
local HUD_GAP = 12
local HUD_SLOT_COUNT = 2
local SLOT_PADDING_X = 16
local STAT_VALUE_OFFSET = 155
local PLAYER_VALUE_OFFSET = 155
local STAT_HIGHLIGHT_WIDTH = 255
local PLAYER_HIGHLIGHT_WIDTH = 255
local STAT_LINE_SPACING = 25
local SECTION_TITLE_Y_OFFSET = 28
local SECTION_STATS_Y_OFFSET = 80
local HIGHLIGHT_PADDING_X = 10
local HIGHLIGHT_HEIGHT = 20
local HIGHLIGHT_Y_OFFSET = 4

font:setFilter("nearest", "nearest")
smallFont:setFilter("nearest", "nearest")
titleFont:setFilter("nearest", "nearest")

local function round(value)
    return math.floor((value or 0) + 0.5)
end

local function formatDecimal(value)
    return string.format("%.2f", value or 0)
end

local function getWeaponRange(weaponConfig, bulletConfig)
    bulletConfig = bulletConfig or weaponConfig.initialBullet or {}
    return weaponConfig.range
        or bulletConfig.range
        or ((weaponConfig.bulletSpeed or 0) * (bulletConfig.lifeTime or weaponConfig.lifeTime or weaponConfig.defaultBulletLifeTime or 0.35))
end

local function getPrimaryWeaponStats(previewCard, highlightCard)
    local gun = Player and Player.gun
    local slot = gun and gun.primary_weapon
    if not (gun and slot and slot.config) then
        return nil
    end

    local previewWeapon = previewCard
        and previewCard.cardType == "weapon"
        and previewCard.weaponId
        and gun:getWeaponConfig(previewCard.weaponId)
    local base = previewWeapon or slot.config
    local current = previewWeapon or gun:getEffectiveWeaponConfig(slot)
    local bullet = base.initialBullet or {}
    local baseRange = getWeaponRange(base, bullet)
    local currentRange = getWeaponRange(current, current.initialBullet or bullet) * (current.rangeMultiplier or 1)
    local baseReload = base.reloadDuration or gun.defaultReloadDuration or 0
    local currentReload = current.reloadDuration or baseReload

    local stats = {
        gun = gun,
        slot = slot,
        damage = current.damage or base.damage or 0,
        damageBonus = previewWeapon and 0 or (slot.damageBonus or 0),
        reload = currentReload,
        reloadBonus = math.max(0, baseReload - currentReload),
        range = currentRange,
        rangeBonus = previewWeapon and 0 or math.max(0, currentRange - baseRange),
        changed = {},
    }

    local cardId = previewCard and previewCard.id
    if cardId == "primary_damage" then
        stats.damage = stats.damage + 2
        stats.damageBonus = stats.damageBonus + 2
        stats.changed.damage = true
    elseif cardId == "primary_damage_epic" then
        stats.damage = stats.damage + 4
        stats.damageBonus = stats.damageBonus + 4
        stats.changed.damage = true
    elseif cardId == "primary_reload" then
        local previewReload = stats.reload * 0.9
        stats.reloadBonus = stats.reloadBonus + math.max(0, stats.reload - previewReload)
        stats.reload = previewReload
        stats.changed.reload = true
    elseif cardId == "primary_range" then
        local previewRange = stats.range * 1.1
        stats.rangeBonus = stats.rangeBonus + math.max(0, previewRange - stats.range)
        stats.range = previewRange
        stats.changed.range = true
    end

    local highlightId = highlightCard and highlightCard.id
    if highlightId == "primary_damage" or highlightId == "primary_damage_epic" then
        stats.changed.damage = true
    elseif highlightId == "primary_reload" then
        stats.changed.reload = true
    elseif highlightId == "primary_range" then
        stats.changed.range = true
    end

    return stats
end

local function drawText(text, x, y, color, customFont)
    local activeFont = customFont or font
    love.graphics.setFont(activeFont)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    love.graphics.setColor(0.01, 0.01, 0.02, 0.85 * currentAlpha)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * currentAlpha)
    love.graphics.print(text, x, y)
end

local function drawSectionTitle(text, x, y)
    drawText(text, x, y, {0.98, 0.86, 0.46, 1}, titleFont)
end

local function drawPixelBorder(x, y, width, height, color, thickness)
    thickness = thickness or BORDER_SIZE
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * currentAlpha)
    love.graphics.rectangle("fill", x, y, width, thickness)
    love.graphics.rectangle("fill", x, y + height - thickness, width, thickness)
    love.graphics.rectangle("fill", x, y, thickness, height)
    love.graphics.rectangle("fill", x + width - thickness, y, thickness, height)
end

local function drawCenteredHighlight(x, y, width)
    love.graphics.setColor(0.92, 0.78, 0.28, 0.18 * currentAlpha)
    love.graphics.rectangle(
        "fill",
        x - HIGHLIGHT_PADDING_X,
        y + HIGHLIGHT_Y_OFFSET,
        width,
        HIGHLIGHT_HEIGHT
    )
end

local function drawStat(label, total, bonusText, x, y, bonusColor, highlighted, options)
    options = options or {}
    local valueOffset = options.valueOffset or STAT_VALUE_OFFSET
    local highlightWidth = options.highlightWidth or STAT_HIGHLIGHT_WIDTH

    if highlighted then
        drawCenteredHighlight(x, y, highlightWidth)
    end

    drawText(label, x, y, highlighted and {0.98, 0.86, 0.46, 1} or {0.67, 0.68, 0.66, 1}, smallFont)
    local valueX = x + valueOffset
    drawText(total, valueX, y, highlighted and {1, 0.96, 0.72, 1} or {1, 1, 1, 1}, font)
    if bonusText and bonusText ~= "" then
        drawText(bonusText, valueX + font:getWidth(total) + 7, y, bonusColor, font)
    end
end

local function getPlayerPreview(previewCard, highlightCard)
    local slots = math.max(0, math.floor(((Player and Player.totalLife) or 0) / 2 + 0.5))
    local life = math.max(0, (Player and Player.life) or 0)
    local changedLife = false
    local changedMaxLife = false
    local speedBase = (Player and (Player.baseSpeed or 92)) or 92
    local speed = (Player and Player.speed) or speedBase

    local cardId = previewCard and previewCard.id
    if cardId == "half_heart" then
        local previewLife = math.min(slots * 2, life + 2)
        changedLife = previewLife ~= life
        life = previewLife
    elseif cardId == "full_heal" then
        changedLife = life ~= slots * 2
        life = slots * 2
    elseif cardId == "heart_container" then
        slots = slots + 1
        life = slots * 2
        changedLife = true
        changedMaxLife = true
    elseif cardId == "speed" then
        speed = speed + 5
    elseif cardId == "speed_rare" then
        speed = speed + 10
    end

    local result = {
        slots = slots,
        life = life,
        speed = speed,
        speedBase = speedBase,
        speedBonus = math.max(0, speed - speedBase),
        changedLife = changedLife,
        changedMaxLife = changedMaxLife,
        changedSpeed = cardId == "speed" or cardId == "speed_rare",
    }

    local highlightId = highlightCard and highlightCard.id
    if highlightId == "speed" or highlightId == "speed_rare" then
        result.changedSpeed = true
    elseif highlightId == "half_heart" or highlightId == "full_heal" then
        result.changedLife = true
    elseif highlightId == "heart_container" then
        result.changedLife = true
        result.changedMaxLife = true
    end

    return result
end

local function getSlotLayout(x, y, width, height)
    local innerWidth = width - HUD_PADDING * 2
    local slotWidth = math.floor((innerWidth - HUD_GAP * (HUD_SLOT_COUNT - 1)) / HUD_SLOT_COUNT)
    local slotHeight = height - HUD_PADDING * 2

    return {
        width = slotWidth,
        height = slotHeight,
        primaryX = x + HUD_PADDING,
        playerX = x + HUD_PADDING + slotWidth + HUD_GAP,
        y = y + HUD_PADDING,
    }
end

local function formatHeartText(playerStats)
    local currentHearts = math.ceil((playerStats.life or 0) / 2)
    return tostring(currentHearts) .. "/" .. tostring(playerStats.slots)
end

local function drawHeartSlots(x, y, playerStats)
    if playerStats.changedLife or playerStats.changedMaxLife then
        drawCenteredHighlight(x, y, PLAYER_HIGHLIGHT_WIDTH)
    end

    drawText("TOTAL LIFE", x, y, playerStats.changedMaxLife and {0.98, 0.86, 0.46, 1} or {0.67, 0.68, 0.66, 1}, smallFont)
    drawText(formatHeartText(playerStats), x + PLAYER_VALUE_OFFSET, y, playerStats.changedLife and {1, 0.96, 0.72, 1} or {1, 1, 1, 1}, font)
end

function PlayerStatusHud:draw(x, y, options)
    options = options or {}
    currentAlpha = options.alpha or 1
    local width = options.width or HUD_WIDTH
    local height = options.height or HUD_HEIGHT
    local previewCard = options.previewCard
    local highlightCard = options.highlightCard
    local stats = getPrimaryWeaponStats(previewCard, highlightCard)
    if not stats then
        return
    end
    local playerStats = getPlayerPreview(previewCard, highlightCard)

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)

    love.graphics.setColor(0.035, 0.025, 0.045, 0.78 * currentAlpha)
    love.graphics.rectangle("fill", x, y, width, height)
    drawPixelBorder(x, y, width, height, {0.90, 0.84, 0.70, 0.30}, BORDER_SIZE)
    local layout = getSlotLayout(x, y, width, height)
    drawPixelBorder(layout.primaryX, layout.y, layout.width, layout.height, {0.90, 0.84, 0.70, 0.16}, BORDER_SIZE)
    drawPixelBorder(layout.playerX, layout.y, layout.width, layout.height, {0.90, 0.84, 0.70, 0.16}, BORDER_SIZE)

    drawSectionTitle("PRIMARY GUN", layout.primaryX + SLOT_PADDING_X, y + SECTION_TITLE_Y_OFFSET)

    local gunStatsX = layout.primaryX + SLOT_PADDING_X
    local topY = y + SECTION_STATS_Y_OFFSET

    drawStat(Localization:t("cards.primary_damage.name"), tostring(round(stats.damage)), "+" .. tostring(round(stats.damageBonus)), gunStatsX, topY, {0.50, 0.95, 0.58, 1}, stats.changed.damage)
    drawStat(Localization:t("cards.primary_reload.name"), formatDecimal(stats.reload), "-" .. formatDecimal(stats.reloadBonus), gunStatsX, topY + STAT_LINE_SPACING, {0.45, 0.78, 1.00, 1}, stats.changed.reload)
    drawStat(Localization:t("cards.primary_range.name"), tostring(round(stats.range)), "+" .. tostring(round(stats.rangeBonus)), gunStatsX, topY + STAT_LINE_SPACING * 2, {0.50, 0.95, 0.58, 1}, stats.changed.range)

    local playerX = layout.playerX + SLOT_PADDING_X
    drawSectionTitle("PLAYER", playerX, y + SECTION_TITLE_Y_OFFSET)
    drawHeartSlots(playerX, topY + STAT_LINE_SPACING, playerStats)
    drawStat(Localization:t("cards.speed.name"), tostring(round(playerStats.speed)), "+" .. tostring(round(playerStats.speedBonus)), playerX, topY + STAT_LINE_SPACING * 2, {0.50, 0.95, 0.58, 1}, playerStats.changedSpeed, {
        valueOffset = PLAYER_VALUE_OFFSET,
        highlightWidth = PLAYER_HIGHLIGHT_WIDTH,
    })

    love.graphics.setColor(1, 1, 1, 1)
    currentAlpha = 1
end

return PlayerStatusHud
