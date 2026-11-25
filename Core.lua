---@class QFontProfile
---@field schemaVersion number
---@field enabled boolean
---@field font string
---@field outline string
---@field shadow boolean
---@field headerSize number
---@field titleSize number
---@field bodySize number
---@field bgEnabled boolean
---@field bgTexture string
---@field bgBorder string
---@field bgTint string
---@field bgAlpha number
---@field bgPadding number
---@field bgFitContent boolean
---@field scrollBarEnabled boolean
---@field maxHeightRatio number
---@field panelPosition { point: string, x: number, y: number }

local addonName, ns = ...

-------------------------------------------------------------------------------
-- Defaults & Constants
-------------------------------------------------------------------------------
---@type QFontProfile
ns.DEFAULTS = {
    schemaVersion = 3,
    enabled = true,
    font = "frizqt",
    outline = "OUTLINE",
    shadow = true,
    headerSize = 16,
    titleSize = 14,
    bodySize = 12,
    bgEnabled = true,
    bgTexture = "dialog_dark",
    bgBorder = "tooltip",
    bgTint = "obsidian",
    bgAlpha = 0.72,
    bgPadding = 8,
    bgFitContent = true,
    scrollBarEnabled = true,
    maxHeightRatio = 0.50,
    panelPosition = {
        point = "CENTER",
        x = 0,
        y = 0,
    },
}

ns.MIN_FONT_SIZE = 8
ns.MAX_FONT_SIZE = 32
ns.MIN_BG_PADDING = 0
ns.MAX_BG_PADDING = 24
ns.MIN_HEIGHT_RATIO = 0.20
ns.MAX_HEIGHT_RATIO = 0.90

-- Known Retail (11.x / 12.x Midnight) Objective Tracker FontObjects.
-- We snapshot each object's original font once before modifying it so disabling
-- or resetting qfont cleanly restores Blizzard's defaults.
local TRACKER_HEADER_FONT_OBJECTS = {
    "ObjectiveTrackerHeaderFont",
}

local TRACKER_BODY_FONT_OBJECTS = {
    "ObjectiveFont",
    "ObjectiveTrackerLineFont",
    "ObjectiveTrackerFont12",
    "ObjectiveTrackerFont13",
    "ObjectiveTrackerFont14",
    "ObjectiveTrackerFont15",
    "ObjectiveTrackerFont16",
    "ObjectiveTrackerFont17",
    "ObjectiveTrackerFont18",
    "ObjectiveTrackerFont19",
    "ObjectiveTrackerFont20",
    "ObjectiveTrackerFont21",
    "ObjectiveTrackerFont22",
}

-- Known Retail 11.x / 12.x modular tracker global frames.
-- We ALSO dynamically discover modules from ObjectiveTrackerFrame.modules and
-- ObjectiveTrackerManager.moduleToContainerMap so future Blizzard modules work
-- automatically.
local KNOWN_MODULE_GLOBALS = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "InitiativeTasksObjectiveTracker",
}

-------------------------------------------------------------------------------
-- Anti-Taint Private State (Weak-Keyed Caches; NEVER write fields onto
-- Blizzard frames or FontStrings)
-------------------------------------------------------------------------------
local originalFontCache = setmetatable({}, { __mode = "k" })
local hookedObjects = setmetatable({}, { __mode = "k" })
local applyQueued = false
local isApplying = false
local layoutRefreshPending = false
local trackerBgFrame = nil
local questieBgFrame = nil
local questieScrollBar = nil
local hookedScrollFrame = nil
local syncingScrollBar = false
local originalQuestieSizes = nil

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
function ns.Print(msg)
    print("|cff7f9effqfont:|r " .. tostring(msg))
end

local function ClampNumber(value, minVal, maxVal, fallback)
    local n = tonumber(value)
    if not n then
        return fallback
    end
    if n < minVal then
        return minVal
    elseif n > maxVal then
        return maxVal
    end
    return n
end
ns.ClampNumber = ClampNumber

local function ClampSize(value, fallback)
    local n = ClampNumber(value, ns.MIN_FONT_SIZE, ns.MAX_FONT_SIZE, fallback)
    return math.floor(n + 0.5)
end
ns.ClampSize = ClampSize

local function ApplyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end
    for key, defaultValue in pairs(defaults) do
        if type(defaultValue) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = CopyTable(defaultValue)
            else
                ApplyDefaults(target[key], defaultValue)
            end
        elseif target[key] == nil then
            target[key] = defaultValue
        end
    end
    return target
end

---Safely records the untouched Blizzard font & shadow state for a FontObject or
---FontString the first time qfont sees it.
local function SnapshotOriginalFont(obj)
    if originalFontCache[obj] ~= nil then
        return
    end
    if not obj or type(obj.GetFont) ~= "function" then
        return
    end

    local ok, fontPath, fontSize, fontFlags = pcall(obj.GetFont, obj)
    if not ok or not fontPath then
        return
    end

    local sr, sg, sb, sa = 0, 0, 0, 1
    local sx, sy = 1, -1
    if type(obj.GetShadowColor) == "function" then
        local cOk, r, g, b, a = pcall(obj.GetShadowColor, obj)
        if cOk and r then
            sr, sg, sb, sa = r, g, b, a
        end
    end
    if type(obj.GetShadowOffset) == "function" then
        local oOk, x, y = pcall(obj.GetShadowOffset, obj)
        if oOk and x then
            sx, sy = x, y
        end
    end

    originalFontCache[obj] = {
        path = fontPath,
        size = fontSize,
        flags = fontFlags or "",
        sr = sr,
        sg = sg,
        sb = sb,
        sa = sa,
        sx = sx,
        sy = sy,
    }
end

---Applies either custom qfont styling or restores the original Blizzard styling.
local function StyleFontObject(obj, fontPath, fontSize, fontFlags, useShadow, enabled)
    if not obj or type(obj.SetFont) ~= "function" then
        return
    end

    SnapshotOriginalFont(obj)

    if not enabled then
        local orig = originalFontCache[obj]
        if orig and orig.path and orig.size then
            pcall(obj.SetFont, obj, orig.path, orig.size, orig.flags)
            if type(obj.SetShadowColor) == "function" then
                pcall(obj.SetShadowColor, obj, orig.sr, orig.sg, orig.sb, orig.sa)
            end
            if type(obj.SetShadowOffset) == "function" then
                pcall(obj.SetShadowOffset, obj, orig.sx, orig.sy)
            end
        end
        return
    end

    if type(obj.GetFont) == "function" then
        local gOk, curPath, curSize, curFlags = pcall(obj.GetFont, obj)
        if gOk and curPath == fontPath and curSize and math.abs(curSize - fontSize) < 0.01 and (curFlags or "") == fontFlags then
            -- Font already matches; still ensure shadow matches desired setting
            if type(obj.SetShadowColor) == "function" and type(obj.SetShadowOffset) == "function" then
                if useShadow then
                    pcall(obj.SetShadowColor, obj, 0, 0, 0, 0.85)
                    pcall(obj.SetShadowOffset, obj, 1, -1)
                else
                    pcall(obj.SetShadowColor, obj, 0, 0, 0, 0)
                    pcall(obj.SetShadowOffset, obj, 0, 0)
                end
            end
            return
        end
    end

    local ok, applied = pcall(obj.SetFont, obj, fontPath, fontSize, fontFlags)
    if not ok or applied == false then
        -- Fallback to default Friz Quadrata if a third-party font path failed to load
        pcall(obj.SetFont, obj, "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
    end

    if type(obj.SetShadowColor) == "function" and type(obj.SetShadowOffset) == "function" then
        if useShadow then
            pcall(obj.SetShadowColor, obj, 0, 0, 0, 0.85)
            pcall(obj.SetShadowOffset, obj, 1, -1)
        else
            pcall(obj.SetShadowColor, obj, 0, 0, 0, 0)
            pcall(obj.SetShadowOffset, obj, 0, 0)
        end
    end
end

-------------------------------------------------------------------------------
-- Module Discovery & FontString Classification
-------------------------------------------------------------------------------
local function CollectTrackerModules()
    local modules = {}
    local seen = {}

    local function addModule(mod)
        if type(mod) == "table" and not seen[mod] then
            seen[mod] = true
            modules[#modules + 1] = mod
        end
    end

    if ObjectiveTrackerFrame and type(ObjectiveTrackerFrame.modules) == "table" then
        for _, mod in pairs(ObjectiveTrackerFrame.modules) do
            addModule(mod)
        end
    end

    if ObjectiveTrackerManager then
        if type(ObjectiveTrackerManager.moduleToContainerMap) == "table" then
            for mod in pairs(ObjectiveTrackerManager.moduleToContainerMap) do
                addModule(mod)
            end
        end
        if type(ObjectiveTrackerManager.modules) == "table" then
            for _, mod in pairs(ObjectiveTrackerManager.modules) do
                addModule(mod)
            end
        end
    end

    for i = 1, #KNOWN_MODULE_GLOBALS do
        local mod = _G[KNOWN_MODULE_GLOBALS[i]]
        if mod then
            addModule(mod)
        end
    end

    return modules
end

---Builds lookup sets of specific FontStrings that represent Section Headers
---versus Quest/Block Titles so we can apply distinct sizes cleanly.
local function BuildRoleLookup(modules)
    local headerStrings = {}
    local titleStrings = {}

    local function markHeader(headerFrame)
        if type(headerFrame) ~= "table" then
            return
        end
        if headerFrame.Text then
            headerStrings[headerFrame.Text] = true
        end
        if headerFrame.Title then
            headerStrings[headerFrame.Title] = true
        end
    end

    if ObjectiveTrackerFrame then
        markHeader(ObjectiveTrackerFrame.Header)
    end

    for i = 1, #modules do
        local mod = modules[i]
        markHeader(mod.Header)
        if mod.HeaderText then
            headerStrings[mod.HeaderText] = true
        end

        -- Modern 11.x / 12.x modules track active blocks in usedBlocks
        if type(mod.usedBlocks) == "table" then
            for templateOrKey, blocksOrBlock in pairs(mod.usedBlocks) do
                if type(blocksOrBlock) == "table" then
                    if blocksOrBlock.HeaderText then
                        titleStrings[blocksOrBlock.HeaderText] = true
                    else
                        for _, block in pairs(blocksOrBlock) do
                            if type(block) == "table" and block.HeaderText then
                                titleStrings[block.HeaderText] = true
                            end
                        end
                    end
                elseif type(templateOrKey) == "table" and templateOrKey.HeaderText then
                    titleStrings[templateOrKey.HeaderText] = true
                end
            end
        end
    end

    return headerStrings, titleStrings
end

local function IsForbidden(obj)
    return obj and type(obj.IsForbidden) == "function" and obj:IsForbidden()
end

---Recursively walks a frame tree and styles every FontString according to its
---role (module header, quest/block title, or objective line).
local function StyleFrameTree(frame, visited, headerStrings, titleStrings, fontPath, db)
    if not frame or visited[frame] or IsForbidden(frame) then
        return
    end
    visited[frame] = true

    if type(frame.GetRegions) == "function" then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if
                region
                and not IsForbidden(region)
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "FontString"
            then
                local size = db.bodySize
                if headerStrings[region] then
                    size = db.headerSize
                elseif titleStrings[region] or frame.HeaderText == region then
                    size = db.titleSize
                end
                StyleFontObject(region, fontPath, size, db.outline, db.shadow, db.enabled)
            end
        end
    end

    if type(frame.GetChildren) == "function" then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            StyleFrameTree(children[i], visited, headerStrings, titleStrings, fontPath, db)
        end
    end
end

---Politely requests Blizzard's Objective Tracker to recalculate block heights
---after font size changes. Deferred automatically if the player is in combat.
local function RequestTrackerLayoutRefresh(modules)
    if InCombatLockdown() then
        layoutRefreshPending = true
        return
    end
    layoutRefreshPending = false

    for i = 1, #modules do
        local mod = modules[i]
        if type(mod.MarkDirty) == "function" then
            pcall(mod.MarkDirty, mod)
        end
    end

    if ObjectiveTrackerFrame and type(ObjectiveTrackerFrame.Update) == "function" then
        pcall(ObjectiveTrackerFrame.Update, ObjectiveTrackerFrame)
    end
end

-------------------------------------------------------------------------------
-- Taint-Free Quest Tracker Background Texture Frame
-------------------------------------------------------------------------------
local function EnsureTrackerBackgroundFrame()
    if trackerBgFrame then
        return trackerBgFrame
    end
    if not ObjectiveTrackerFrame then
        return nil
    end

    -- Own insecure BackdropTemplate frame parented to ObjectiveTrackerFrame at
    -- BACKGROUND strata so it sits cleanly behind all quest text/buttons and
    -- auto-hides whenever Blizzard hides the tracker (cinematics, pet battles).
    local bg = CreateFrame("Frame", nil, ObjectiveTrackerFrame, "BackdropTemplate")
    bg:SetFrameStrata("BACKGROUND")
    bg:SetFrameLevel(0)
    bg:EnableMouse(false)
    trackerBgFrame = bg
    return bg
end

---Computes the tight vertical bottom edge of active visible modules inside
---ObjectiveTrackerFrame so the background wraps tracked quests cleanly instead
---of spanning empty space down the screen.
local function ComputeVisibleContentHeight(modules)
    if not ObjectiveTrackerFrame then
        return nil
    end
    local top = ObjectiveTrackerFrame:GetTop()
    if not top then
        return nil
    end

    local lowestBottom = nil
    local function consider(frame)
        if not frame or IsForbidden(frame) then
            return
        end
        if type(frame.IsShown) == "function" and not frame:IsShown() then
            return
        end
        local h = type(frame.GetHeight) == "function" and frame:GetHeight() or 0
        local b = type(frame.GetBottom) == "function" and frame:GetBottom() or nil
        if b and h and h > 1 then
            if not lowestBottom or b < lowestBottom then
                lowestBottom = b
            end
        end
    end

    consider(ObjectiveTrackerFrame.Header)

    local isCollapsed = type(ObjectiveTrackerFrame.IsCollapsed) == "function" and ObjectiveTrackerFrame:IsCollapsed()
    if not isCollapsed then
        for i = 1, #modules do
            local mod = modules[i]
            if mod and mod:IsShown() then
                -- Check module frame & its active block bottoms
                consider(mod)
                if type(mod.usedBlocks) == "table" then
                    for _, blocksOrBlock in pairs(mod.usedBlocks) do
                        if type(blocksOrBlock) == "table" then
                            if blocksOrBlock.GetBottom then
                                consider(blocksOrBlock)
                            else
                                for _, block in pairs(blocksOrBlock) do
                                    consider(block)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not lowestBottom or lowestBottom >= top then
        return nil
    end

    return top - lowestBottom
end

function ns.ApplyTrackerBackground(modules)
    local db = ns.db
    if not db or not ObjectiveTrackerFrame then
        return
    end

    local bg = EnsureTrackerBackgroundFrame()
    if not bg then
        return
    end

    if not db.bgEnabled or not ObjectiveTrackerFrame:IsShown() then
        bg:Hide()
        return
    end

    local trackerWidth = ObjectiveTrackerFrame:GetWidth() or 0
    local trackerHeight = ObjectiveTrackerFrame:GetHeight() or 0
    if trackerWidth < 10 or trackerHeight < 10 then
        bg:Hide()
        return
    end

    local pad = math.floor(ClampNumber(db.bgPadding, ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, ns.DEFAULTS.bgPadding) + 0.5)
    local alpha = ClampNumber(db.bgAlpha, 0, 1, ns.DEFAULTS.bgAlpha)
    local tint = ns.ResolveBgTint(db.bgTint)

    local backdropInfo = ns.BuildBackdropInfo(db.bgTexture, db.bgBorder)
    bg:ClearBackdrop()
    bg:SetBackdrop(backdropInfo)
    bg:SetBackdropColor(tint.r, tint.g, tint.b, alpha)
    if backdropInfo.edgeFile then
        local borderAlpha = math.min(1, alpha + 0.25)
        bg:SetBackdropBorderColor(tint.br, tint.bg, tint.bb, borderAlpha)
    end

    bg:ClearAllPoints()
    if db.bgFitContent then
        local contentHeight = ComputeVisibleContentHeight(modules or CollectTrackerModules())
        if not contentHeight or contentHeight < 8 then
            bg:Hide()
            return
        end
        bg:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", -pad, pad)
        bg:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", pad, pad)
        bg:SetHeight(contentHeight + (pad * 2))
    else
        bg:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT", -pad, pad)
        bg:SetPoint("BOTTOMRIGHT", ObjectiveTrackerFrame, "BOTTOMRIGHT", pad, -pad)
    end

    bg:Show()
end

-------------------------------------------------------------------------------
-- Questie Tracker Integration (Questie_BaseFrame / QuestieTracker)
-- Supports WoW Forever & Classic players who use Questie's built-in tracker
-- (which hides Blizzard's default ObjectiveTrackerFrame).
-------------------------------------------------------------------------------
local function GetQuestieTrackerModule()
    if QuestieLoader and type(QuestieLoader.ImportModule) == "function" then
        local ok, mod = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieTracker")
        if ok and type(mod) == "table" then
            return mod
        end
    end
    if type(QuestieTracker) == "table" then
        return QuestieTracker
    end
    return nil
end

local function SyncQuestieFontSizes(db)
    if not (Questie and type(Questie.db) == "table" and type(Questie.db.profile) == "table") then
        return false
    end

    local profile = Questie.db.profile
    if not originalQuestieSizes then
        originalQuestieSizes = {
            header = profile.trackerFontSizeHeader,
            zone = profile.trackerFontSizeZone,
            quest = profile.trackerFontSizeQuest,
            objective = profile.trackerFontSizeObjective,
            heightRatio = profile.trackerHeightRatio,
        }
    end

    local changed = false
    if db.enabled then
        if profile.trackerFontSizeHeader ~= db.headerSize then
            profile.trackerFontSizeHeader = db.headerSize
            changed = true
        end
        if profile.trackerFontSizeZone ~= db.headerSize then
            profile.trackerFontSizeZone = db.headerSize
            changed = true
        end
        if profile.trackerFontSizeQuest ~= db.titleSize then
            profile.trackerFontSizeQuest = db.titleSize
            changed = true
        end
        if profile.trackerFontSizeObjective ~= db.bodySize then
            profile.trackerFontSizeObjective = db.bodySize
            changed = true
        end
    elseif originalQuestieSizes then
        if originalQuestieSizes.header and profile.trackerFontSizeHeader ~= originalQuestieSizes.header then
            profile.trackerFontSizeHeader = originalQuestieSizes.header
            changed = true
        end
        if originalQuestieSizes.zone and profile.trackerFontSizeZone ~= originalQuestieSizes.zone then
            profile.trackerFontSizeZone = originalQuestieSizes.zone
            changed = true
        end
        if originalQuestieSizes.quest and profile.trackerFontSizeQuest ~= originalQuestieSizes.quest then
            profile.trackerFontSizeQuest = originalQuestieSizes.quest
            changed = true
        end
        if originalQuestieSizes.objective and profile.trackerFontSizeObjective ~= originalQuestieSizes.objective then
            profile.trackerFontSizeObjective = originalQuestieSizes.objective
            changed = true
        end
    end

    -- Sync Questie's max height ratio so scrolling kicks in at the user's preferred window height
    if db.scrollBarEnabled then
        local ratio = ClampNumber(db.maxHeightRatio, ns.MIN_HEIGHT_RATIO, ns.MAX_HEIGHT_RATIO, ns.DEFAULTS.maxHeightRatio)
        if not profile.trackerHeightRatio or math.abs(profile.trackerHeightRatio - ratio) > 0.005 then
            profile.trackerHeightRatio = ratio
            changed = true
        end
    elseif originalQuestieSizes and originalQuestieSizes.heightRatio then
        if profile.trackerHeightRatio ~= originalQuestieSizes.heightRatio then
            profile.trackerHeightRatio = originalQuestieSizes.heightRatio
            changed = true
        end
    end

    return changed
end

local function GetQuestieLineSize(frame, inHeader, db)
    if inHeader then
        return db.headerSize
    end
    local mode = type(frame) == "table" and frame.mode or nil
    if mode == "header" or mode == "zone" then
        return db.headerSize
    elseif mode == "quest" or mode == "achieve" then
        return db.titleSize
    elseif mode == "objective" then
        return db.bodySize
    end
    return db.bodySize
end

local function StyleQuestieFrameTree(frame, visited, inHeader, fontPath, db)
    if not frame or visited[frame] or IsForbidden(frame) then
        return
    end
    visited[frame] = true

    local isHeader = inHeader or (Questie_HeaderFrame and frame == Questie_HeaderFrame)
    local lineSize = GetQuestieLineSize(frame, isHeader, db)

    if type(frame.GetRegions) == "function" then
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if
                region
                and not IsForbidden(region)
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "FontString"
            then
                StyleFontObject(region, fontPath, lineSize, db.outline, db.shadow, db.enabled)
            end
        end
    end

    if type(frame.GetChildren) == "function" then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child ~= questieBgFrame and child ~= questieScrollBar then
                StyleQuestieFrameTree(child, visited, isHeader, fontPath, db)
            end
        end
    end
end

local function FindQuestieScrollFrame()
    -- 1. Check Questie's TrackerQuestFrame module directly if exposed
    if QuestieLoader and type(QuestieLoader.ImportModule) == "function" then
        local ok, qfMod = pcall(QuestieLoader.ImportModule, QuestieLoader, "TrackerQuestFrame")
        if ok and type(qfMod) == "table" then
            if qfMod.questFrame and type(qfMod.questFrame.GetObjectType) == "function" and qfMod.questFrame:GetObjectType() == "ScrollFrame" then
                return qfMod.questFrame
            end
            if qfMod.trackedQuestsScrollFrame and type(qfMod.trackedQuestsScrollFrame.GetObjectType) == "function" then
                return qfMod.trackedQuestsScrollFrame
            end
        end
    end

    -- 2. Check well-known global names
    local globalsToCheck = { _G.TrackedQuestsScrollFrame, _G.Questie_ScrollFrame }
    for i = 1, #globalsToCheck do
        local f = globalsToCheck[i]
        if f and not IsForbidden(f) and type(f.GetObjectType) == "function" and f:GetObjectType() == "ScrollFrame" then
            return f
        end
    end

    -- 3. Dynamic BFS over Questie_BaseFrame's children to find its ScrollFrame
    if not Questie_BaseFrame then
        return nil
    end
    local queue = { Questie_BaseFrame }
    local seen = { [Questie_BaseFrame] = true }
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        if type(current.GetChildren) == "function" then
            local children = { current:GetChildren() }
            for i = 1, #children do
                local child = children[i]
                if child and not seen[child] and not IsForbidden(child) and child ~= questieBgFrame and child ~= questieScrollBar then
                    seen[child] = true
                    if type(child.GetObjectType) == "function" and child:GetObjectType() == "ScrollFrame" then
                        return child
                    end
                    queue[#queue + 1] = child
                end
            end
        end
    end

    return nil
end

local function SyncQuestieScrollBar(scrollFrame)
    if not questieScrollBar or not scrollFrame or not ns.db then
        return false
    end

    local db = ns.db
    if not db.scrollBarEnabled or not Questie_BaseFrame or not Questie_BaseFrame:IsShown() or not scrollFrame:IsShown() then
        questieScrollBar:Hide()
        return false
    end

    if type(scrollFrame.UpdateScrollChildRect) == "function" then
        pcall(scrollFrame.UpdateScrollChildRect, scrollFrame)
    end

    local maxScroll = (type(scrollFrame.GetVerticalScrollRange) == "function" and scrollFrame:GetVerticalScrollRange()) or 0
    if maxScroll <= 2 then
        questieScrollBar:Hide()
        return false
    end

    local currentScroll = (type(scrollFrame.GetVerticalScroll) == "function" and scrollFrame:GetVerticalScroll()) or 0
    if currentScroll > maxScroll then
        currentScroll = maxScroll
    elseif currentScroll < 0 then
        currentScroll = 0
    end

    local visibleHeight = scrollFrame:GetHeight() or 100
    local totalHeight = visibleHeight + maxScroll
    local trackHeight = math.max(32, visibleHeight - 4)
    local thumbHeight = math.max(24, math.min(trackHeight * 0.85, trackHeight * (visibleHeight / math.max(1, totalHeight))))

    local tint = ns.ResolveBgTint(db.bgTint)
    questieScrollBar:SetBackdropColor(0.04, 0.05, 0.08, 0.65)
    questieScrollBar:SetBackdropBorderColor(tint.br, tint.bg, tint.bb, 0.55)
    questieScrollBar.thumbTex:SetColorTexture(tint.br, tint.bg, tint.bb, 0.85)
    questieScrollBar.thumbTex:SetSize(8, thumbHeight)

    questieScrollBar:ClearAllPoints()
    questieScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 12, -2)
    questieScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 12, 2)

    syncingScrollBar = true
    questieScrollBar:SetMinMaxValues(0, maxScroll)
    questieScrollBar:SetValue(currentScroll)
    syncingScrollBar = false

    questieScrollBar:Show()
    return true
end

local function EnsureQuestieScrollBar(scrollFrame)
    if not scrollFrame or not Questie_BaseFrame then
        return nil
    end

    if not questieScrollBar then
        local sb = CreateFrame("Slider", nil, Questie_BaseFrame, "BackdropTemplate")
        sb:SetOrientation("VERTICAL")
        sb:SetWidth(12)
        sb:SetFrameLevel(math.max(5, (Questie_BaseFrame:GetFrameLevel() or 1) + 5))
        sb:EnableMouse(true)
        sb:EnableMouseWheel(true)
        sb:SetValueStep(1)

        sb:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })

        local thumb = sb:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 36)
        thumb:SetColorTexture(0.55, 0.68, 1.0, 0.85)
        sb:SetThumbTexture(thumb)
        sb.thumbTex = thumb

        sb:SetScript("OnEnter", function(self)
            self.thumbTex:SetAlpha(1.0)
        end)
        sb:SetScript("OnLeave", function(self)
            self.thumbTex:SetAlpha(0.85)
        end)

        sb:SetScript("OnValueChanged", function(_, value)
            if syncingScrollBar or not hookedScrollFrame then
                return
            end
            pcall(hookedScrollFrame.SetVerticalScroll, hookedScrollFrame, value)
        end)

        sb:SetScript("OnMouseWheel", function(self, delta)
            if not hookedScrollFrame then
                return
            end
            local step = math.max(18, (ns.db and ns.db.bodySize or 12) * 2.5)
            local minVal, maxVal = self:GetMinMaxValues()
            local nextVal = (self:GetValue() or 0) - (delta * step)
            if nextVal < minVal then
                nextVal = minVal
            elseif nextVal > maxVal then
                nextVal = maxVal
            end
            self:SetValue(nextVal)
        end)

        sb:Hide()
        questieScrollBar = sb
    end

    if hookedScrollFrame ~= scrollFrame then
        hookedScrollFrame = scrollFrame
        if type(scrollFrame.HookScript) == "function" then
            scrollFrame:HookScript("OnVerticalScroll", function(self, offset)
                if not questieScrollBar or not questieScrollBar:IsShown() then
                    return
                end
                syncingScrollBar = true
                questieScrollBar:SetValue(offset or 0)
                syncingScrollBar = false
            end)
            scrollFrame:HookScript("OnScrollRangeChanged", function(self)
                SyncQuestieScrollBar(self)
            end)
            scrollFrame:HookScript("OnSizeChanged", function(self)
                SyncQuestieScrollBar(self)
            end)
        end
    end

    return questieScrollBar
end

local function EnsureQuestieBackgroundFrame()
    if questieBgFrame then
        return questieBgFrame
    end
    if not Questie_BaseFrame then
        return nil
    end

    local bg = CreateFrame("Frame", nil, Questie_BaseFrame, "BackdropTemplate")
    bg:SetFrameStrata("BACKGROUND")
    bg:SetFrameLevel(0)
    bg:EnableMouse(false)
    questieBgFrame = bg
    return bg
end

local function ApplyQuestieTracker(fontPath, db, refreshLayout)
    if not Questie_BaseFrame then
        return
    end

    local sizesChanged = SyncQuestieFontSizes(db)
    if (refreshLayout or sizesChanged) and not InCombatLockdown() then
        local qt = GetQuestieTrackerModule()
        if qt and type(qt.Update) == "function" then
            pcall(qt.Update, qt)
        end
    end

    -- Apply exact Font Face, Sizes, Outline, and Drop Shadow across all Questie tracker FontStrings
    local visited = {}
    StyleQuestieFrameTree(Questie_BaseFrame, visited, false, fontPath, db)
    if Questie_HeaderFrame then
        StyleQuestieFrameTree(Questie_HeaderFrame, visited, true, fontPath, db)
    end

    -- Attach / sync overflow Scroll Bar on Questie's ScrollFrame
    local scrollFrame = FindQuestieScrollFrame()
    local scrollBarVisible = false
    if scrollFrame then
        EnsureQuestieScrollBar(scrollFrame)
        scrollBarVisible = SyncQuestieScrollBar(scrollFrame)
    elseif questieScrollBar then
        questieScrollBar:Hide()
    end

    -- Apply Quest List Background Texture & Border behind Questie_BaseFrame
    local bg = EnsureQuestieBackgroundFrame()
    if not bg then
        return
    end

    if not db.bgEnabled or not Questie_BaseFrame:IsShown() then
        bg:Hide()
        return
    end

    local w = Questie_BaseFrame:GetWidth() or 0
    local h = Questie_BaseFrame:GetHeight() or 0
    if w < 10 or h < 10 then
        bg:Hide()
        return
    end

    local pad = math.floor(ClampNumber(db.bgPadding, ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, ns.DEFAULTS.bgPadding) + 0.5)
    local rightPad = scrollBarVisible and (pad + 16) or pad
    local alpha = ClampNumber(db.bgAlpha, 0, 1, ns.DEFAULTS.bgAlpha)
    local tint = ns.ResolveBgTint(db.bgTint)

    local backdropInfo = ns.BuildBackdropInfo(db.bgTexture, db.bgBorder)
    bg:ClearBackdrop()
    bg:SetBackdrop(backdropInfo)
    bg:SetBackdropColor(tint.r, tint.g, tint.b, alpha)
    if backdropInfo.edgeFile then
        bg:SetBackdropBorderColor(tint.br, tint.bg, tint.bb, math.min(1, alpha + 0.25))
    end

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", Questie_BaseFrame, "TOPLEFT", -pad, pad)
    bg:SetPoint("BOTTOMRIGHT", Questie_BaseFrame, "BOTTOMRIGHT", rightPad, -pad)
    bg:Show()
end

-------------------------------------------------------------------------------
-- Main Apply Function
-------------------------------------------------------------------------------
---@param refreshLayout? boolean Whether to ask Blizzard's tracker to re-layout heights
function ns.ApplyFonts(refreshLayout)
    local db = ns.db
    if not db or isApplying then
        return
    end
    isApplying = true

    local fontPath = ns.ResolveFont(db.font)

    -- 1. Update Blizzard Objective Tracker FontObjects
    for i = 1, #TRACKER_HEADER_FONT_OBJECTS do
        local fontObj = _G[TRACKER_HEADER_FONT_OBJECTS[i]]
        if fontObj then
            StyleFontObject(fontObj, fontPath, db.headerSize, db.outline, db.shadow, db.enabled)
        end
    end

    for i = 1, #TRACKER_BODY_FONT_OBJECTS do
        local fontObj = _G[TRACKER_BODY_FONT_OBJECTS[i]]
        if fontObj then
            StyleFontObject(fontObj, fontPath, db.bodySize, db.outline, db.shadow, db.enabled)
        end
    end

    -- 2. Discover modules and style all active FontStrings in ObjectiveTrackerFrame
    local modules = CollectTrackerModules()
    local headerStrings, titleStrings = BuildRoleLookup(modules)
    local visited = {}

    if ObjectiveTrackerFrame then
        StyleFrameTree(ObjectiveTrackerFrame, visited, headerStrings, titleStrings, fontPath, db)
    end

    for i = 1, #modules do
        StyleFrameTree(modules[i], visited, headerStrings, titleStrings, fontPath, db)
    end

    -- 3. Apply background texture / border behind Blizzard's ObjectiveTrackerFrame
    ns.ApplyTrackerBackground(modules)

    -- 4. Style & apply background behind Questie Tracker (Questie_BaseFrame) if present
    ApplyQuestieTracker(fontPath, db, refreshLayout)

    -- 5. Trigger Blizzard height/wrapping layout refresh when sizes changed by user action
    if refreshLayout then
        RequestTrackerLayoutRefresh(modules)
    end

    isApplying = false
end

---Coalesces rapid Blizzard tracker updates into a single next-frame font pass.
---@param refreshLayout? boolean
function ns.ScheduleApply(refreshLayout)
    if applyQueued and not refreshLayout then
        return
    end
    applyQueued = true
    C_Timer.After(0, function()
        applyQueued = false
        ns.ApplyFonts(refreshLayout)
    end)
end

-------------------------------------------------------------------------------
-- Taint-Free Secure Hooks (hooksecurefunc only)
-------------------------------------------------------------------------------
local function HookOnce(target, methodName, callback)
    if type(target) ~= "table" or type(target[methodName]) ~= "function" then
        return
    end
    local methods = hookedObjects[target]
    if methods and methods[methodName] then
        return
    end
    if not methods then
        methods = {}
        hookedObjects[target] = methods
    end
    methods[methodName] = true
    hooksecurefunc(target, methodName, callback)
end

local function InstallTrackerHooks()
    local onTrackerUpdated = function()
        ns.ScheduleApply(false)
    end

    if ObjectiveTrackerFrame then
        HookOnce(ObjectiveTrackerFrame, "Update", onTrackerUpdated)
        HookOnce(ObjectiveTrackerFrame, "UpdateHeight", onTrackerUpdated)
        HookOnce(ObjectiveTrackerFrame, "SetCollapsed", onTrackerUpdated)
    end

    if ObjectiveTrackerManager then
        HookOnce(ObjectiveTrackerManager, "SetTextSize", function()
            ns.ScheduleApply(false)
        end)
        HookOnce(ObjectiveTrackerManager, "UpdateAll", onTrackerUpdated)
    end

    if ObjectiveTrackerBlockMixin then
        HookOnce(ObjectiveTrackerBlockMixin, "SetHeader", onTrackerUpdated)
        HookOnce(ObjectiveTrackerBlockMixin, "SetStringText", onTrackerUpdated)
    end

    local modules = CollectTrackerModules()
    for i = 1, #modules do
        local mod = modules[i]
        HookOnce(mod, "Update", onTrackerUpdated)
        HookOnce(mod, "LayoutContents", onTrackerUpdated)
    end

    -- Hook Questie Tracker updates if Questie is installed
    local qt = GetQuestieTrackerModule()
    if qt then
        HookOnce(qt, "Update", onTrackerUpdated)
        HookOnce(qt, "UpdateHeight", onTrackerUpdated)
        HookOnce(qt, "UpdateWidth", onTrackerUpdated)
        HookOnce(qt, "UpdateFormatting", onTrackerUpdated)
    end
end

-------------------------------------------------------------------------------
-- Reset & Settings Sync
-------------------------------------------------------------------------------
function ns.ResetDefaults()
    wipe(QFontDB)
    ApplyDefaults(QFontDB, ns.DEFAULTS)
    ns.ApplyFonts(true)
    if ns.RefreshQuickPanel then
        ns.RefreshQuickPanel()
    end
    ns.Print("All settings reset to defaults.")
end

function ns.OnSettingChanged()
    ns.ApplyFonts(true)
    if ns.RefreshQuickPanel then
        ns.RefreshQuickPanel()
    end
end

-------------------------------------------------------------------------------
-- Lifecycle Events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            QFontDB = ApplyDefaults(QFontDB, ns.DEFAULTS)
            ns.db = QFontDB

            ns.RegisterFontMediaCallback()
            if ns.InitSettings then
                ns.InitSettings()
            end

            if C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") or ObjectiveTrackerFrame then
                InstallTrackerHooks()
                ns.ScheduleApply(true)
            end
        elseif arg1 == "Blizzard_ObjectiveTracker" or arg1 == "Questie" then
            InstallTrackerHooks()
            ns.ScheduleApply(true)
        end
    elseif event == "PLAYER_LOGIN" then
        InstallTrackerHooks()
        ns.ScheduleApply(true)
        -- Questie initializes its tracker asynchronously after PLAYER_LOGIN;
        -- schedule a follow-up hook & style pass once Questie_BaseFrame exists.
        C_Timer.After(1.5, function()
            InstallTrackerHooks()
            ns.ScheduleApply(true)
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        InstallTrackerHooks()
        ns.ScheduleApply(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if layoutRefreshPending then
            ns.ScheduleApply(true)
        end
    else
        ns.ScheduleApply(false)
    end
end)

-------------------------------------------------------------------------------
-- Slash Commands (/qfont, /qf)
-------------------------------------------------------------------------------
SLASH_QFONT1 = "/qfont"
SLASH_QFONT2 = "/qf"

local function PrintHelp()
    ns.Print("Commands:")
    print("  |cffffffff/qfont|r — Open live quick-config window (Fonts & Background tabs)")
    print("  |cffffffff/qfont options|r — Open Blizzard Settings config screen")
    print("  |cffffffff/qfont font <name>|r — Set font (e.g. frizqt, arial, morpheus, skurri, friends)")
    print("  |cffffffff/qfont list|r — List all available fonts (including LibSharedMedia)")
    print("  |cffffffff/qfont size <n>|r — Set objective size (auto-scales titles +2, headers +4)")
    print("  |cffffffff/qfont header <n>|r / |cfffffffftitle <n>|r / |cffffffffbody <n>|r — Set individual sizes (8-32)")
    print("  |cffffffff/qfont outline <none|outline|thick|mono>|r — Set text outline")
    print("  |cffffffff/qfont shadow <on|off>|r — Toggle text drop shadow")
    print("  |cffffffff/qfont bg <on|off|texture>|r — Toggle or pick background (e.g. parchment, marble, rock, solid)")
    print("  |cffffffff/qfont bglist|r — List all available background & border textures")
    print("  |cffffffff/qfont border <name>|r — Set border (tooltip, none, pixel, dialog, gold, wood)")
    print("  |cffffffff/qfont tint <name>|r — Set background tint (obsidian, natural, midnight, parchment, forest, crimson, slate)")
    print("  |cffffffff/qfont alpha <0-100>|r — Set background opacity percentage")
    print("  |cffffffff/qfont padding <0-24>|r — Set background padding in pixels")
    print("  |cffffffff/qfont scroll <on|off>|r — Show/hide overflow scroll bar")
    print("  |cffffffff/qfont height <20-90>|r — Max quest window height (% of screen) before scrolling")
    print("  |cffffffff/qfont toggle|r — Enable or disable qfont")
    print("  |cffffffff/qfont reset|r — Reset all settings to defaults")
end

SlashCmdList["QFONT"] = function(msg)
    if not ns.db then
        return
    end
    local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
    cmd = (cmd or ""):lower()
    rest = strtrim(rest or "")

    if cmd == "" or cmd == "ui" or cmd == "panel" then
        if ns.ToggleQuickPanel then
            ns.ToggleQuickPanel()
        end
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        if ns.OpenSettings then
            ns.OpenSettings()
        end
    elseif cmd == "toggle" then
        ns.db.enabled = not ns.db.enabled
        ns.OnSettingChanged()
        ns.Print("qfont " .. (ns.db.enabled and "|cff33ff66enabled|r." or "|cffff5555disabled|r."))
    elseif cmd == "list" or cmd == "fonts" then
        local fonts = ns.GetAvailableFonts()
        ns.Print(string.format("Available fonts (%d):", #fonts))
        for i = 1, #fonts do
            local marker = (fonts[i].id == ns.db.font) and " |cff33ff66[active]|r" or ""
            print(string.format("  |cff7f9eff%s|r — %s%s", fonts[i].id, fonts[i].name, marker))
        end
    elseif cmd == "font" then
        if rest == "" then
            local _, name = ns.ResolveFont(ns.db.font)
            ns.Print("Current font: |cffffffff" .. name .. "|r. Use |cffffffff/qfont list|r to see options.")
            return
        end
        local entry = ns.FindFontEntry(rest)
        if not entry then
            ns.Print("Font not found: '" .. rest .. "'. Type |cffffffff/qfont list|r to see available fonts.")
            return
        end
        ns.db.font = entry.id
        ns.OnSettingChanged()
        ns.Print("Font set to |cffffffff" .. entry.name .. "|r.")
    elseif cmd == "size" then
        local base = tonumber(rest)
        if not base then
            ns.Print(
                string.format(
                    "Current sizes — Header: |cffffffff%d|r, Title: |cffffffff%d|r, Objective: |cffffffff%d|r",
                    ns.db.headerSize,
                    ns.db.titleSize,
                    ns.db.bodySize
                )
            )
            return
        end
        ns.db.bodySize = ClampSize(base, ns.DEFAULTS.bodySize)
        ns.db.titleSize = ClampSize(base + 2, ns.DEFAULTS.titleSize)
        ns.db.headerSize = ClampSize(base + 4, ns.DEFAULTS.headerSize)
        ns.OnSettingChanged()
        ns.Print(
            string.format(
                "Sizes set — Header: |cffffffff%d|r, Title: |cffffffff%d|r, Objective: |cffffffff%d|r",
                ns.db.headerSize,
                ns.db.titleSize,
                ns.db.bodySize
            )
        )
    elseif cmd == "header" then
        local n = tonumber(rest)
        if not n then
            ns.Print("Usage: /qfont header <8-32>")
            return
        end
        ns.db.headerSize = ClampSize(n, ns.DEFAULTS.headerSize)
        ns.OnSettingChanged()
        ns.Print("Section header size set to |cffffffff" .. ns.db.headerSize .. "|r.")
    elseif cmd == "title" then
        local n = tonumber(rest)
        if not n then
            ns.Print("Usage: /qfont title <8-32>")
            return
        end
        ns.db.titleSize = ClampSize(n, ns.DEFAULTS.titleSize)
        ns.OnSettingChanged()
        ns.Print("Quest title size set to |cffffffff" .. ns.db.titleSize .. "|r.")
    elseif cmd == "body" or cmd == "line" or cmd == "objective" then
        local n = tonumber(rest)
        if not n then
            ns.Print("Usage: /qfont body <8-32>")
            return
        end
        ns.db.bodySize = ClampSize(n, ns.DEFAULTS.bodySize)
        ns.OnSettingChanged()
        ns.Print("Objective line size set to |cffffffff" .. ns.db.bodySize .. "|r.")
    elseif cmd == "outline" then
        local map = {
            none = "",
            off = "",
            outline = "OUTLINE",
            thick = "THICKOUTLINE",
            thickoutline = "THICKOUTLINE",
            mono = "MONOCHROME",
            monochrome = "MONOCHROME",
            both = "OUTLINE, MONOCHROME",
        }
        local flag = map[rest:lower()]
        if flag == nil then
            ns.Print("Usage: /qfont outline <none | outline | thick | mono | both>")
            return
        end
        ns.db.outline = flag
        ns.OnSettingChanged()
        ns.Print("Outline set to |cffffffff" .. (flag == "" and "None" or flag) .. "|r.")
    elseif cmd == "shadow" then
        local v = rest:lower()
        if v == "on" or v == "true" or v == "1" then
            ns.db.shadow = true
        elseif v == "off" or v == "false" or v == "0" then
            ns.db.shadow = false
        else
            ns.db.shadow = not ns.db.shadow
        end
        ns.OnSettingChanged()
        ns.Print("Drop shadow " .. (ns.db.shadow and "|cff33ff66enabled|r." or "|cffff5555disabled|r."))
    elseif cmd == "bglist" or cmd == "backgrounds" then
        local bgs = ns.GetAvailableBackgrounds()
        ns.Print(string.format("Available backgrounds (%d):", #bgs))
        for i = 1, #bgs do
            local marker = (bgs[i].id == ns.db.bgTexture) and " |cff33ff66[active]|r" or ""
            print(string.format("  |cff7f9eff%s|r — %s%s", bgs[i].id, bgs[i].name, marker))
        end
        local borders = ns.GetAvailableBorders()
        ns.Print(string.format("Available borders (%d):", #borders))
        for i = 1, #borders do
            local marker = (borders[i].id == ns.db.bgBorder) and " |cff33ff66[active]|r" or ""
            print(string.format("  |cff7f9eff%s|r — %s%s", borders[i].id, borders[i].name, marker))
        end
    elseif cmd == "bg" or cmd == "background" then
        local v = rest:lower()
        if v == "" then
            ns.db.bgEnabled = not ns.db.bgEnabled
            ns.OnSettingChanged()
            ns.Print("Quest tracker background " .. (ns.db.bgEnabled and "|cff33ff66enabled|r." or "|cffff5555disabled|r."))
            return
        elseif v == "on" or v == "true" or v == "1" then
            ns.db.bgEnabled = true
            ns.OnSettingChanged()
            ns.Print("Quest tracker background |cff33ff66enabled|r.")
            return
        elseif v == "off" or v == "false" or v == "0" then
            ns.db.bgEnabled = false
            ns.OnSettingChanged()
            ns.Print("Quest tracker background |cffff5555disabled|r.")
            return
        end
        local entry = ns.FindBackgroundEntry(rest)
        if not entry then
            ns.Print("Background not found: '" .. rest .. "'. Type |cffffffff/qfont bglist|r to see options.")
            return
        end
        ns.db.bgEnabled = true
        ns.db.bgTexture = entry.id
        ns.OnSettingChanged()
        ns.Print("Background texture set to |cffffffff" .. entry.name .. "|r.")
    elseif cmd == "border" then
        local entry = ns.FindBorderEntry(rest)
        if not entry then
            ns.Print("Border not found: '" .. rest .. "'. Type |cffffffff/qfont bglist|r to see options.")
            return
        end
        ns.db.bgBorder = entry.id
        ns.OnSettingChanged()
        ns.Print("Border set to |cffffffff" .. entry.name .. "|r.")
    elseif cmd == "tint" or cmd == "color" then
        local entry = ns.FindBgTintEntry(rest)
        if not entry then
            ns.Print("Usage: /qfont tint <obsidian | natural | midnight | parchment | forest | crimson | slate>")
            return
        end
        ns.db.bgTint = entry.id
        ns.OnSettingChanged()
        ns.Print("Background tint set to |cffffffff" .. entry.label .. "|r.")
    elseif cmd == "alpha" or cmd == "opacity" then
        local pct = tonumber(rest)
        if not pct then
            ns.Print(string.format("Current background opacity: |cffffffff%d%%|r (Usage: /qfont alpha 0-100)", math.floor(ns.db.bgAlpha * 100 + 0.5)))
            return
        end
        local normalized = pct > 1 and (pct / 100) or pct
        ns.db.bgAlpha = ClampNumber(normalized, 0, 1, ns.DEFAULTS.bgAlpha)
        ns.OnSettingChanged()
        ns.Print(string.format("Background opacity set to |cffffffff%d%%|r.", math.floor(ns.db.bgAlpha * 100 + 0.5)))
    elseif cmd == "padding" or cmd == "pad" then
        local n = tonumber(rest)
        if not n then
            ns.Print("Usage: /qfont padding <0-24>")
            return
        end
        ns.db.bgPadding = math.floor(ClampNumber(n, ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, ns.DEFAULTS.bgPadding) + 0.5)
        ns.OnSettingChanged()
        ns.Print("Background padding set to |cffffffff" .. ns.db.bgPadding .. " px|r.")
    elseif cmd == "scroll" or cmd == "scrollbar" then
        local v = rest:lower()
        if v == "on" or v == "true" or v == "1" then
            ns.db.scrollBarEnabled = true
        elseif v == "off" or v == "false" or v == "0" then
            ns.db.scrollBarEnabled = false
        else
            ns.db.scrollBarEnabled = not ns.db.scrollBarEnabled
        end
        ns.OnSettingChanged()
        ns.Print("Overflow scroll bar " .. (ns.db.scrollBarEnabled and "|cff33ff66enabled|r." or "|cffff5555disabled|r."))
    elseif cmd == "height" or cmd == "maxheight" then
        local pct = tonumber(rest)
        if not pct then
            ns.Print(string.format("Current max window height: |cffffffff%d%%|r (Usage: /qfont height 20-90)", math.floor(ns.db.maxHeightRatio * 100 + 0.5)))
            return
        end
        local normalized = pct > 1 and (pct / 100) or pct
        ns.db.maxHeightRatio = ClampNumber(normalized, ns.MIN_HEIGHT_RATIO, ns.MAX_HEIGHT_RATIO, ns.DEFAULTS.maxHeightRatio)
        ns.OnSettingChanged()
        ns.Print(string.format("Max quest window height set to |cffffffff%d%%|r of screen.", math.floor(ns.db.maxHeightRatio * 100 + 0.5)))
    elseif cmd == "reset" then
        ns.ResetDefaults()
    else
        PrintHelp()
    end
end

-------------------------------------------------------------------------------
-- Addon Compartment Global Handlers (declared in qfont.toc)
-------------------------------------------------------------------------------
function QFont_OnCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        if ns.OpenSettings then
            ns.OpenSettings()
        end
    else
        if ns.ToggleQuickPanel then
            ns.ToggleQuickPanel()
        end
    end
end

function QFont_OnCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("qfont", 0.48, 0.62, 1.0)
    GameTooltip:AddLine("Left-Click: Toggle live quick-adjuster", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Open Blizzard Settings", 1, 1, 1)
    GameTooltip:Show()
end

function QFont_OnCompartmentLeave()
    GameTooltip:Hide()
end
