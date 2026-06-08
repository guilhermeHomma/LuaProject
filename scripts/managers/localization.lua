local Localization = {
    currentLanguage = "en",
    fallbackLanguage = "en",
    languages = {
        { id = "en", label = "English" },
        { id = "pt", label = "Português" },
        { id = "es", label = "Español" },
    },
    dictionaries = {},
}

local cp1252ToCodepoint = {
    [0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E,
    [0x85] = 0x2026, [0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6,
    [0x89] = 0x2030, [0x8A] = 0x0160, [0x8B] = 0x2039, [0x8C] = 0x0152,
    [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019, [0x93] = 0x201C,
    [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
    [0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A,
    [0x9C] = 0x0153, [0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function isValidUtf8(text)
    if not (utf8 and utf8.codes) then
        return true
    end

    return pcall(function()
        for _ in utf8.codes(text or "") do
        end
    end)
end

local function cp1252ToUtf8(text)
    local result = {}
    for index = 1, #(text or "") do
        local byte = text:byte(index)
        if byte < 0x80 then
            result[#result + 1] = string.char(byte)
        else
            local codepoint = cp1252ToCodepoint[byte] or byte
            result[#result + 1] = utf8 and utf8.char and utf8.char(codepoint) or "?"
        end
    end
    return table.concat(result)
end

local function normalizeText(text)
    text = tostring(text or "")
    if isValidUtf8(text) then
        return text
    end
    return cp1252ToUtf8(text)
end

local function skipWhitespace(text, index)
    while true do
        local char = text:sub(index, index)
        if char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
            return index
        end
        index = index + 1
    end
end

local function parseString(text, index)
    index = index + 1
    local result = {}
    while index <= #text do
        local char = text:sub(index, index)
        if char == "\"" then
            return normalizeText(table.concat(result)), index + 1
        elseif char == "\\" then
            local nextChar = text:sub(index + 1, index + 1)
            if nextChar == "n" then
                result[#result + 1] = "\n"
            elseif nextChar == "t" then
                result[#result + 1] = "\t"
            elseif nextChar == "r" then
                result[#result + 1] = "\r"
            else
                result[#result + 1] = nextChar
            end
            index = index + 2
        else
            result[#result + 1] = char
            index = index + 1
        end
    end

    return table.concat(result), index
end

local parseValue

local function parseObject(text, index)
    local result = {}
    index = skipWhitespace(text, index + 1)
    if text:sub(index, index) == "}" then
        return result, index + 1
    end

    while index <= #text do
        local key
        key, index = parseString(text, index)
        index = skipWhitespace(text, index)
        index = skipWhitespace(text, index + 1)
        result[key], index = parseValue(text, index)
        index = skipWhitespace(text, index)
        local char = text:sub(index, index)
        if char == "}" then
            return result, index + 1
        end
        index = skipWhitespace(text, index + 1)
    end

    return result, index
end

local function parseArray(text, index)
    local result = {}
    index = skipWhitespace(text, index + 1)
    if text:sub(index, index) == "]" then
        return result, index + 1
    end

    while index <= #text do
        local value
        value, index = parseValue(text, index)
        result[#result + 1] = value
        index = skipWhitespace(text, index)
        local char = text:sub(index, index)
        if char == "]" then
            return result, index + 1
        end
        index = skipWhitespace(text, index + 1)
    end

    return result, index
end

function parseValue(text, index)
    index = skipWhitespace(text, index)
    local char = text:sub(index, index)
    if char == "{" then
        return parseObject(text, index)
    elseif char == "[" then
        return parseArray(text, index)
    elseif char == "\"" then
        return parseString(text, index)
    end

    local token = text:match("^[^,%]}%s]+", index) or ""
    if token == "true" then
        return true, index + #token
    elseif token == "false" then
        return false, index + #token
    elseif token == "null" then
        return nil, index + #token
    end
    return tonumber(token), index + #token
end

local function decodeJson(text)
    local value = parseValue(text or "", 1)
    return value or {}
end

local function getNestedValue(source, key)
    local value = source
    for part in tostring(key):gmatch("[^%.]+") do
        value = type(value) == "table" and value[part] or nil
        if value == nil then
            return nil
        end
    end
    return value
end

function Localization:load()
    for _, language in ipairs(self.languages) do
        local path = "assets/i18n/" .. language.id .. ".json"
        local contents = love.filesystem.read(path)
        self.dictionaries[language.id] = contents and decodeJson(contents) or {}
    end
end

function Localization:normalizeText(text)
    return normalizeText(text)
end

function Localization:getLanguageIndex()
    for index, language in ipairs(self.languages) do
        if language.id == self.currentLanguage then
            return index
        end
    end
    return 1
end

function Localization:setLanguage(languageId)
    for _, language in ipairs(self.languages) do
        if language.id == languageId then
            self.currentLanguage = languageId
            return
        end
    end
    self.currentLanguage = self.fallbackLanguage
end

function Localization:cycleLanguage(direction)
    local index = self:getLanguageIndex() + (direction or 1)
    if index < 1 then
        index = #self.languages
    elseif index > #self.languages then
        index = 1
    end
    self:setLanguage(self.languages[index].id)
end

function Localization:getLanguageLabel()
    return self.languages[self:getLanguageIndex()].label
end

function Localization:t(key, replacements)
    local dictionary = self.dictionaries[self.currentLanguage] or {}
    local fallback = self.dictionaries[self.fallbackLanguage] or {}
    local value = normalizeText(getNestedValue(dictionary, key) or getNestedValue(fallback, key) or tostring(key))

    if replacements then
        value = tostring(value):gsub("{([%w_]+)}", function(name)
            local replacement = replacements[name]
            return replacement ~= nil and tostring(replacement) or "{" .. name .. "}"
        end)
    end

    return value
end

return Localization
