---@class QFontEntry
---@field id string
---@field name string
---@field path string
---@field source "builtin"|"lsm"

---@class QBackgroundEntry
---@field id string
---@field name string
---@field path string
---@field tile boolean
---@field tileSize number
---@field source "builtin"|"lsm"

---@class QBorderEntry
---@field id string
---@field name string
---@field path string|nil
---@field edgeSize number
---@field inset number
---@field source "builtin"|"lsm"

---@class QFontNamespace
local _, ns = ...

-------------------------------------------------------------------------------
-- Built-in World of Warcraft Client Fonts (always available, zero deps)
-------------------------------------------------------------------------------
---@type QFontEntry[]
local BUILTIN_FONTS = {
    {
        id = "frizqt",
        name = "Friz Quadrata (Default UI)",
        path = "Fonts\\FRIZQT__.TTF",
        source = "builtin",
    },
    {
        id = "arialn",
        name = "Arial Narrow (Clean / Compact)",
        path = "Fonts\\ARIALN.TTF",
        source = "builtin",
    },
    {
        id = "morpheus",
        name = "Morpheus (Quest Serif)",
        path = "Fonts\\MORPHEUS.TTF",
        source = "builtin",
    },
    {
        id = "skurri",
        name = "Skurri (Bold Combat)",
        path = "Fonts\\skurri.ttf",
        source = "builtin",
    },
    {
        id = "friends",
        name = "Friends (Rounded Sans)",
        path = "Fonts\\FRIENDS.TTF",
        source = "builtin",
    },
}

-------------------------------------------------------------------------------
-- Built-in World of Warcraft Quest Tracker Background Textures
-------------------------------------------------------------------------------
---@type QBackgroundEntry[]
local BUILTIN_BACKGROUNDS = {
    {
        id = "dialog_dark",
        name = "Blizzard Dialog Dark",
        path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        tile = true,
        tileSize = 32,
        source = "builtin",
    },
    {
        id = "solid",
        name = "Solid Flat (Modern HUD)",
        path = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        source = "builtin",
    },
    {
        id = "tooltip",
        name = "Blizzard Tooltip",
        path = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        source = "builtin",
    },
    {
        id = "dialog",
        name = "Blizzard Dialog Classic",
        path = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        source = "builtin",
    },
    {
        id = "parchment",
        name = "Blizzard Parchment (Quest Scroll)",
        path = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
        tile = false,
        tileSize = 0,
        source = "builtin",
    },
    {
        id = "marble",
        name = "Blizzard Marble (Stone)",
        path = "Interface\\FrameGeneral\\UI-Background-Marble",
        tile = true,
        tileSize = 256,
        source = "builtin",
    },
    {
        id = "rock",
        name = "Blizzard Rock (Carved Slate)",
        path = "Interface\\FrameGeneral\\UI-Background-Rock",
        tile = true,
        tileSize = 256,
        source = "builtin",
    },
}

-------------------------------------------------------------------------------
-- Built-in World of Warcraft Quest Tracker Border Textures
-------------------------------------------------------------------------------
---@type QBorderEntry[]
local BUILTIN_BORDERS = {
    {
        id = "tooltip",
        name = "Blizzard Tooltip Border",
        path = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        inset = 3,
        source = "builtin",
    },
    {
        id = "none",
        name = "None (Borderless)",
        path = nil,
        edgeSize = 0,
        inset = 0,
        source = "builtin",
    },
    {
        id = "pixel",
        name = "Thin Flat Border (1px)",
        path = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        inset = 1,
        source = "builtin",
    },
    {
        id = "dialog",
        name = "Blizzard Dialog Border",
        path = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 20,
        inset = 5,
        source = "builtin",
    },
    {
        id = "gold",
        name = "Blizzard Gold Border",
        path = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 20,
        inset = 5,
        source = "builtin",
    },
    {
        id = "wood",
        name = "Blizzard Achievement Wood",
        path = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
        edgeSize = 22,
        inset = 6,
        source = "builtin",
    },
}

ns.BG_TINT_OPTIONS = {
    { id = "obsidian", label = "Obsidian Dark", r = 0.05, g = 0.06, b = 0.09, br = 0.35, bg = 0.42, bb = 0.55 },
    { id = "natural", label = "Natural (Untinted Texture)", r = 1.00, g = 1.00, b = 1.00, br = 0.85, bg = 0.85, bb = 0.85 },
    { id = "midnight", label = "Midnight Indigo", r = 0.08, g = 0.09, b = 0.22, br = 0.48, bg = 0.62, bb = 1.00 },
    { id = "parchment", label = "Warm Parchment Tint", r = 0.55, g = 0.44, b = 0.30, br = 0.78, bg = 0.62, bb = 0.32 },
    { id = "forest", label = "Emerald Dusk", r = 0.06, g = 0.16, b = 0.11, br = 0.25, bg = 0.75, bb = 0.48 },
    { id = "crimson", label = "Crimson Ember", r = 0.20, g = 0.06, b = 0.07, br = 0.85, bg = 0.30, bb = 0.30 },
    { id = "slate", label = "Cool Slate", r = 0.16, g = 0.20, b = 0.26, br = 0.55, bg = 0.64, bb = 0.76 },
}

ns.OUTLINE_OPTIONS = {
    { value = "", label = "None", tooltip = "No text outline." },
    { value = "OUTLINE", label = "Outline", tooltip = "Crisp 1px dark outline around letters." },
    { value = "THICKOUTLINE", label = "Thick Outline", tooltip = "Heavy 2px dark outline around letters." },
    { value = "MONOCHROME", label = "Monochrome", tooltip = "Sharp pixel rendering without anti-aliasing." },
    {
        value = "OUTLINE, MONOCHROME",
        label = "Outline + Monochrome",
        tooltip = "Crisp 1px outline with monochrome rendering.",
    },
}

---Returns the optional LibSharedMedia-3.0 instance if installed by another addon.
---@return table|nil
local function GetLSM()
    if LibStub then
        return LibStub("LibSharedMedia-3.0", true)
    end
    return nil
end

---Helper to pull sorted media entries from LibSharedMedia-3.0 without duplicating
---paths already registered in our built-in list.
local function AppendLSMMedia(mediaType, list, seenPaths, buildEntry)
    local lsm = GetLSM()
    if not lsm or not lsm.HashTable then
        return
    end
    local hash = lsm:HashTable(mediaType)
    if type(hash) ~= "table" then
        return
    end

    local lsmNames = {}
    for name in pairs(hash) do
        lsmNames[#lsmNames + 1] = name
    end
    table.sort(lsmNames, function(a, b)
        return a:lower() < b:lower()
    end)

    for i = 1, #lsmNames do
        local name = lsmNames[i]
        local path = hash[name]
        if type(path) == "string" and path ~= "" and not seenPaths[path:lower()] then
            list[#list + 1] = buildEntry(name, path)
            seenPaths[path:lower()] = true
        end
    end
end

-------------------------------------------------------------------------------
-- Fonts API
-------------------------------------------------------------------------------
---@return QFontEntry[]
function ns.GetAvailableFonts()
    local fonts = {}
    local seenPaths = {}

    for i = 1, #BUILTIN_FONTS do
        local entry = BUILTIN_FONTS[i]
        fonts[#fonts + 1] = entry
        seenPaths[entry.path:lower()] = true
    end

    AppendLSMMedia("font", fonts, seenPaths, function(name, path)
        return {
            id = "lsm:" .. name,
            name = name .. " (SharedMedia)",
            path = path,
            source = "lsm",
        }
    end)

    return fonts
end

---@param fontId string|nil
---@return string fontPath
---@return string fontName
function ns.ResolveFont(fontId)
    local target = type(fontId) == "string" and fontId or "frizqt"
    local fonts = ns.GetAvailableFonts()

    for i = 1, #fonts do
        if fonts[i].id == target then
            return fonts[i].path, fonts[i].name
        end
    end

    local lowerTarget = target:lower()
    for i = 1, #fonts do
        local entry = fonts[i]
        if
            entry.id:lower() == lowerTarget
            or entry.name:lower() == lowerTarget
            or entry.name:lower():find(lowerTarget, 1, true)
        then
            return entry.path, entry.name
        end
    end

    if target:find("%.ttf$") or target:find("%.TTF$") or target:find("%.otf$") or target:find("%.OTF$") then
        return target, target
    end

    return BUILTIN_FONTS[1].path, BUILTIN_FONTS[1].name
end

---@param query string
---@return QFontEntry|nil
function ns.FindFontEntry(query)
    if type(query) ~= "string" or query == "" then
        return nil
    end

    local q = strtrim(query):lower()
    local fonts = ns.GetAvailableFonts()

    for i = 1, #fonts do
        local entry = fonts[i]
        if entry.id:lower() == q or entry.name:lower() == q then
            return entry
        end
    end

    for i = 1, #fonts do
        local entry = fonts[i]
        if entry.id:lower():find(q, 1, true) or entry.name:lower():find(q, 1, true) then
            return entry
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Backgrounds API
-------------------------------------------------------------------------------
---@return QBackgroundEntry[]
function ns.GetAvailableBackgrounds()
    local list = {}
    local seenPaths = {}

    for i = 1, #BUILTIN_BACKGROUNDS do
        local entry = BUILTIN_BACKGROUNDS[i]
        list[#list + 1] = entry
        seenPaths[entry.path:lower()] = true
    end

    AppendLSMMedia("background", list, seenPaths, function(name, path)
        return {
            id = "lsm:" .. name,
            name = name .. " (SharedMedia)",
            path = path,
            tile = true,
            tileSize = 32,
            source = "lsm",
        }
    end)

    return list
end

---@param bgId string|nil
---@return QBackgroundEntry
function ns.ResolveBackground(bgId)
    local target = type(bgId) == "string" and bgId or "dialog_dark"
    local list = ns.GetAvailableBackgrounds()

    for i = 1, #list do
        if list[i].id == target then
            return list[i]
        end
    end

    local lowerTarget = target:lower()
    for i = 1, #list do
        local entry = list[i]
        if entry.id:lower() == lowerTarget or entry.name:lower():find(lowerTarget, 1, true) then
            return entry
        end
    end

    return BUILTIN_BACKGROUNDS[1]
end

---@param query string
---@return QBackgroundEntry|nil
function ns.FindBackgroundEntry(query)
    if type(query) ~= "string" or query == "" then
        return nil
    end
    local q = strtrim(query):lower()
    local list = ns.GetAvailableBackgrounds()

    for i = 1, #list do
        if list[i].id:lower() == q or list[i].name:lower() == q then
            return list[i]
        end
    end
    for i = 1, #list do
        if list[i].id:lower():find(q, 1, true) or list[i].name:lower():find(q, 1, true) then
            return list[i]
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Borders API
-------------------------------------------------------------------------------
---@return QBorderEntry[]
function ns.GetAvailableBorders()
    local list = {}
    local seenPaths = {}

    for i = 1, #BUILTIN_BORDERS do
        local entry = BUILTIN_BORDERS[i]
        list[#list + 1] = entry
        if entry.path then
            seenPaths[entry.path:lower()] = true
        end
    end

    AppendLSMMedia("border", list, seenPaths, function(name, path)
        return {
            id = "lsm:" .. name,
            name = name .. " (SharedMedia)",
            path = path,
            edgeSize = 14,
            inset = 3,
            source = "lsm",
        }
    end)

    return list
end

---@param borderId string|nil
---@return QBorderEntry
function ns.ResolveBorder(borderId)
    local target = type(borderId) == "string" and borderId or "tooltip"
    local list = ns.GetAvailableBorders()

    for i = 1, #list do
        if list[i].id == target then
            return list[i]
        end
    end

    local lowerTarget = target:lower()
    for i = 1, #list do
        local entry = list[i]
        if entry.id:lower() == lowerTarget or entry.name:lower():find(lowerTarget, 1, true) then
            return entry
        end
    end

    return BUILTIN_BORDERS[1]
end

---@param query string
---@return QBorderEntry|nil
function ns.FindBorderEntry(query)
    if type(query) ~= "string" or query == "" then
        return nil
    end
    local q = strtrim(query):lower()
    local list = ns.GetAvailableBorders()

    for i = 1, #list do
        if list[i].id:lower() == q or list[i].name:lower() == q then
            return list[i]
        end
    end
    for i = 1, #list do
        if list[i].id:lower():find(q, 1, true) or list[i].name:lower():find(q, 1, true) then
            return list[i]
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Background Tint Lookup
-------------------------------------------------------------------------------
function ns.ResolveBgTint(tintId)
    local target = type(tintId) == "string" and tintId or "obsidian"
    for i = 1, #ns.BG_TINT_OPTIONS do
        if ns.BG_TINT_OPTIONS[i].id == target then
            return ns.BG_TINT_OPTIONS[i]
        end
    end
    return ns.BG_TINT_OPTIONS[1]
end

function ns.FindBgTintEntry(query)
    if type(query) ~= "string" or query == "" then
        return nil
    end
    local q = strtrim(query):lower()
    for i = 1, #ns.BG_TINT_OPTIONS do
        local opt = ns.BG_TINT_OPTIONS[i]
        if opt.id:lower() == q or opt.label:lower():find(q, 1, true) then
            return opt
        end
    end
    return nil
end

---Builds a Blizzard BackdropTemplate table from saved background + border IDs.
function ns.BuildBackdropInfo(bgId, borderId)
    local bg = ns.ResolveBackground(bgId)
    local border = ns.ResolveBorder(borderId)
    local inset = border.inset or 0

    return {
        bgFile = bg.path,
        edgeFile = border.path,
        tile = bg.tile,
        tileEdge = border.path ~= nil,
        tileSize = bg.tileSize or 0,
        edgeSize = border.edgeSize or 0,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
end

---Registers a callback with LibSharedMedia-3.0 (if present) so late-loaded
---media packs automatically refresh fonts and backgrounds.
function ns.RegisterFontMediaCallback()
    local lsm = GetLSM()
    if lsm and lsm.RegisterCallback then
        lsm.RegisterCallback(ns, "LibSharedMedia_Registered", function(_, mediaType)
            if (mediaType == "font" or mediaType == "background" or mediaType == "border") and ns.ScheduleApply then
                ns.ScheduleApply()
            end
        end)
    end
end
