local _, ns = ...

-------------------------------------------------------------------------------
-- Compact Draggable Live-Preview Config Window (/qfont)
-- Features two tabs ("Fonts" and "Background") plus a live sample preview box
-- that renders both the active quest font styling and background texture/border
-- while updating the real Quest / Objective Tracker simultaneously.
-------------------------------------------------------------------------------
local panel
local activeTab = "fonts"

local function CycleList(list, currentVal, keyField, delta)
    if #list == 0 then
        return currentVal
    end
    local currentIndex = 1
    for i = 1, #list do
        if list[i][keyField] == currentVal then
            currentIndex = i
            break
        end
    end
    local nextIndex = ((currentIndex - 1 + delta) % #list) + 1
    return list[nextIndex][keyField]
end

local function GetOutlineLabel(value)
    for i = 1, #ns.OUTLINE_OPTIONS do
        if ns.OUTLINE_OPTIONS[i].value == value then
            return ns.OUTLINE_OPTIONS[i].label
        end
    end
    return "None"
end

local function CreateCycleRow(parent, anchorTo, offsetY, labelText, onPrev, onNext)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(308, 26)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetWidth(86)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(labelText)

    local nextBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    nextBtn:SetSize(24, 22)
    nextBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", onNext)

    local prevBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    prevBtn:SetSize(24, 22)
    prevBtn:SetPoint("LEFT", label, "RIGHT", 4, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", onPrev)

    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
    valueText:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
    valueText:SetJustifyH("CENTER")
    valueText:SetWordWrap(false)

    row.valueText = valueText
    return row
end

local function CreateStepperRow(parent, anchorTo, offsetY, labelText, onMinus, onPlus)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(308, 26)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(labelText)

    local plusBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    plusBtn:SetSize(28, 22)
    plusBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    plusBtn:SetText("+")
    plusBtn:SetScript("OnClick", onPlus)

    local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetWidth(54)
    valueText:SetJustifyH("CENTER")
    valueText:SetPoint("RIGHT", plusBtn, "LEFT", -4, 0)

    local minusBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minusBtn:SetSize(28, 22)
    minusBtn:SetPoint("RIGHT", valueText, "LEFT", -4, 0)
    minusBtn:SetText("-")
    minusBtn:SetScript("OnClick", onMinus)

    row.valueText = valueText
    return row
end

local function SetActiveTab(tabName)
    activeTab = tabName
    if not panel then
        return
    end
    local isFonts = (tabName == "fonts")
    panel.fontsPage:SetShown(isFonts)
    panel.bgPage:SetShown(not isFonts)

    panel.fontsTabBtn:SetEnabled(not isFonts)
    panel.bgTabBtn:SetEnabled(isFonts)
end

function ns.RefreshQuickPanel()
    if not panel or not ns.db then
        return
    end

    local db = ns.db
    local fontPath, fontName = ns.ResolveFont(db.font)
    local bgEntry = ns.ResolveBackground(db.bgTexture)
    local borderEntry = ns.ResolveBorder(db.bgBorder)
    local tintEntry = ns.ResolveBgTint(db.bgTint)

    -- Fonts tab controls
    panel.fontRow.valueText:SetText(fontName)
    panel.headerRow.valueText:SetText(string.format("%d px", db.headerSize))
    panel.titleRow.valueText:SetText(string.format("%d px", db.titleSize))
    panel.bodyRow.valueText:SetText(string.format("%d px", db.bodySize))
    panel.outlineBtn:SetText("Outline: " .. GetOutlineLabel(db.outline))
    panel.shadowBtn:SetText("Shadow: " .. (db.shadow and "On" or "Off"))

    -- Background & Scroll tab controls
    panel.bgToggleBtn:SetText("Background: " .. (db.bgEnabled and "On" or "Off"))
    panel.scrollToggleBtn:SetText("Scroll Bar: " .. (db.scrollBarEnabled and "On" or "Off"))
    panel.bgTextureRow.valueText:SetText(bgEntry.name)
    panel.bgBorderRow.valueText:SetText(borderEntry.name)
    panel.bgTintRow.valueText:SetText(tintEntry.label)
    panel.bgAlphaRow.valueText:SetText(string.format("%d%%", math.floor(db.bgAlpha * 100 + 0.5)))
    panel.bgPaddingRow.valueText:SetText(string.format("%d px", db.bgPadding))
    panel.maxHeightRow.valueText:SetText(string.format("%d%%", math.floor(db.maxHeightRatio * 100 + 0.5)))

    -- Bottom toggle
    panel.enableBtn:SetText("Fonts: " .. (db.enabled and "On" or "Off"))

    -- Live preview box (renders BOTH active font styling AND background texture!)
    panel.previewBox:ClearBackdrop()
    if db.bgEnabled then
        local backdropInfo = ns.BuildBackdropInfo(db.bgTexture, db.bgBorder)
        panel.previewBox:SetBackdrop(backdropInfo)
        panel.previewBox:SetBackdropColor(tintEntry.r, tintEntry.g, tintEntry.b, db.bgAlpha)
        if backdropInfo.edgeFile then
            panel.previewBox:SetBackdropBorderColor(tintEntry.br, tintEntry.bg, tintEntry.bb, math.min(1, db.bgAlpha + 0.25))
        end
    else
        panel.previewBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        panel.previewBox:SetBackdropColor(0, 0, 0, 0.25)
        panel.previewBox:SetBackdropBorderColor(0.35, 0.35, 0.45, 0.5)
    end

    local previewHeaderSize = math.min(db.headerSize, 20)
    local previewTitleSize = math.min(db.titleSize, 18)
    local previewBodySize = math.min(db.bodySize, 16)
    pcall(panel.previewHeader.SetFont, panel.previewHeader, fontPath, previewHeaderSize, db.outline)
    pcall(panel.previewTitle.SetFont, panel.previewTitle, fontPath, previewTitleSize, db.outline)
    pcall(panel.previewBody.SetFont, panel.previewBody, fontPath, previewBodySize, db.outline)

    local previewStrings = { panel.previewHeader, panel.previewTitle, panel.previewBody }
    for i = 1, #previewStrings do
        if db.shadow then
            previewStrings[i]:SetShadowColor(0, 0, 0, 0.85)
            previewStrings[i]:SetShadowOffset(1, -1)
        else
            previewStrings[i]:SetShadowColor(0, 0, 0, 0)
            previewStrings[i]:SetShadowOffset(0, 0)
        end
    end
end

local function CreateQuickPanel()
    if panel then
        return panel
    end

    local f = CreateFrame("Frame", "QFontQuickPanel", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "QFontQuickPanel")
    f:SetSize(340, 420)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        ns.db.panelPosition.point = point or "CENTER"
        ns.db.panelPosition.x = math.floor((x or 0) + 0.5)
        ns.db.panelPosition.y = math.floor((y or 0) + 0.5)
    end)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.07, 0.11, 0.96)
    f:SetBackdropBorderColor(0.48, 0.62, 1.0, 0.95)

    -- Header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("|cff7f9effqfont|r — Quest Tracker Config")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    -- Tab buttons ("Fonts" | "Background")
    local fontsTabBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    fontsTabBtn:SetSize(150, 24)
    fontsTabBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    fontsTabBtn:SetText("Fonts & Sizes")
    fontsTabBtn:SetScript("OnClick", function()
        SetActiveTab("fonts")
    end)
    f.fontsTabBtn = fontsTabBtn

    local bgTabBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bgTabBtn:SetSize(150, 24)
    bgTabBtn:SetPoint("LEFT", fontsTabBtn, "RIGHT", 8, 0)
    bgTabBtn:SetText("Background & Scroll")
    bgTabBtn:SetScript("OnClick", function()
        SetActiveTab("background")
    end)
    f.bgTabBtn = bgTabBtn

    ---------------------------------------------------------------------------
    -- Tab 1: Fonts & Sizes Page
    ---------------------------------------------------------------------------
    local fontsPage = CreateFrame("Frame", nil, f)
    fontsPage:SetSize(308, 178)
    fontsPage:SetPoint("TOPLEFT", fontsTabBtn, "BOTTOMLEFT", 0, -10)
    f.fontsPage = fontsPage

    local fontsAnchor = CreateFrame("Frame", nil, fontsPage)
    fontsAnchor:SetSize(308, 1)
    fontsAnchor:SetPoint("TOPLEFT", fontsPage, "TOPLEFT", 0, 0)

    f.fontRow = CreateCycleRow(fontsPage, fontsAnchor, 0, "Font Face", function()
        ns.db.font = CycleList(ns.GetAvailableFonts(), ns.db.font, "id", -1)
        ns.OnSettingChanged()
    end, function()
        ns.db.font = CycleList(ns.GetAvailableFonts(), ns.db.font, "id", 1)
        ns.OnSettingChanged()
    end)

    f.headerRow = CreateStepperRow(fontsPage, f.fontRow, -8, "Section Header Size", function()
        ns.db.headerSize = ns.ClampSize(ns.db.headerSize - 1, ns.DEFAULTS.headerSize)
        ns.OnSettingChanged()
    end, function()
        ns.db.headerSize = ns.ClampSize(ns.db.headerSize + 1, ns.DEFAULTS.headerSize)
        ns.OnSettingChanged()
    end)

    f.titleRow = CreateStepperRow(fontsPage, f.headerRow, -4, "Quest Title Size", function()
        ns.db.titleSize = ns.ClampSize(ns.db.titleSize - 1, ns.DEFAULTS.titleSize)
        ns.OnSettingChanged()
    end, function()
        ns.db.titleSize = ns.ClampSize(ns.db.titleSize + 1, ns.DEFAULTS.titleSize)
        ns.OnSettingChanged()
    end)

    f.bodyRow = CreateStepperRow(fontsPage, f.titleRow, -4, "Objective Line Size", function()
        ns.db.bodySize = ns.ClampSize(ns.db.bodySize - 1, ns.DEFAULTS.bodySize)
        ns.OnSettingChanged()
    end, function()
        ns.db.bodySize = ns.ClampSize(ns.db.bodySize + 1, ns.DEFAULTS.bodySize)
        ns.OnSettingChanged()
    end)

    local outlineBtn = CreateFrame("Button", nil, fontsPage, "UIPanelButtonTemplate")
    outlineBtn:SetSize(196, 24)
    outlineBtn:SetPoint("TOPLEFT", f.bodyRow, "BOTTOMLEFT", 0, -10)
    outlineBtn:SetScript("OnClick", function()
        ns.db.outline = CycleList(ns.OUTLINE_OPTIONS, ns.db.outline, "value", 1)
        ns.OnSettingChanged()
    end)
    f.outlineBtn = outlineBtn

    local shadowBtn = CreateFrame("Button", nil, fontsPage, "UIPanelButtonTemplate")
    shadowBtn:SetSize(104, 24)
    shadowBtn:SetPoint("LEFT", outlineBtn, "RIGHT", 8, 0)
    shadowBtn:SetScript("OnClick", function()
        ns.db.shadow = not ns.db.shadow
        ns.OnSettingChanged()
    end)
    f.shadowBtn = shadowBtn

    ---------------------------------------------------------------------------
    -- Tab 2: Background Texture Page
    ---------------------------------------------------------------------------
    local bgPage = CreateFrame("Frame", nil, f)
    bgPage:SetSize(308, 206)
    bgPage:SetPoint("TOPLEFT", fontsTabBtn, "BOTTOMLEFT", 0, -10)
    bgPage:Hide()
    f.bgPage = bgPage

    local bgToggleBtn = CreateFrame("Button", nil, bgPage, "UIPanelButtonTemplate")
    bgToggleBtn:SetSize(150, 24)
    bgToggleBtn:SetPoint("TOPLEFT", bgPage, "TOPLEFT", 0, 0)
    bgToggleBtn:SetScript("OnClick", function()
        ns.db.bgEnabled = not ns.db.bgEnabled
        ns.OnSettingChanged()
    end)
    f.bgToggleBtn = bgToggleBtn

    local scrollToggleBtn = CreateFrame("Button", nil, bgPage, "UIPanelButtonTemplate")
    scrollToggleBtn:SetSize(150, 24)
    scrollToggleBtn:SetPoint("LEFT", bgToggleBtn, "RIGHT", 8, 0)
    scrollToggleBtn:SetScript("OnClick", function()
        ns.db.scrollBarEnabled = not ns.db.scrollBarEnabled
        ns.OnSettingChanged()
    end)
    f.scrollToggleBtn = scrollToggleBtn

    f.bgTextureRow = CreateCycleRow(bgPage, bgToggleBtn, -6, "Texture", function()
        ns.db.bgTexture = CycleList(ns.GetAvailableBackgrounds(), ns.db.bgTexture, "id", -1)
        ns.OnSettingChanged()
    end, function()
        ns.db.bgTexture = CycleList(ns.GetAvailableBackgrounds(), ns.db.bgTexture, "id", 1)
        ns.OnSettingChanged()
    end)

    f.bgBorderRow = CreateCycleRow(bgPage, f.bgTextureRow, -4, "Border", function()
        ns.db.bgBorder = CycleList(ns.GetAvailableBorders(), ns.db.bgBorder, "id", -1)
        ns.OnSettingChanged()
    end, function()
        ns.db.bgBorder = CycleList(ns.GetAvailableBorders(), ns.db.bgBorder, "id", 1)
        ns.OnSettingChanged()
    end)

    f.bgTintRow = CreateCycleRow(bgPage, f.bgBorderRow, -4, "Color Tint", function()
        ns.db.bgTint = CycleList(ns.BG_TINT_OPTIONS, ns.db.bgTint, "id", -1)
        ns.OnSettingChanged()
    end, function()
        ns.db.bgTint = CycleList(ns.BG_TINT_OPTIONS, ns.db.bgTint, "id", 1)
        ns.OnSettingChanged()
    end)

    f.bgAlphaRow = CreateStepperRow(bgPage, f.bgTintRow, -4, "Background Opacity", function()
        ns.db.bgAlpha = ns.ClampNumber(ns.db.bgAlpha - 0.05, 0, 1, ns.DEFAULTS.bgAlpha)
        ns.OnSettingChanged()
    end, function()
        ns.db.bgAlpha = ns.ClampNumber(ns.db.bgAlpha + 0.05, 0, 1, ns.DEFAULTS.bgAlpha)
        ns.OnSettingChanged()
    end)

    f.bgPaddingRow = CreateStepperRow(bgPage, f.bgAlphaRow, -2, "Background Padding", function()
        ns.db.bgPadding = math.floor(ns.ClampNumber(ns.db.bgPadding - 1, ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, ns.DEFAULTS.bgPadding) + 0.5)
        ns.OnSettingChanged()
    end, function()
        ns.db.bgPadding = math.floor(ns.ClampNumber(ns.db.bgPadding + 1, ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, ns.DEFAULTS.bgPadding) + 0.5)
        ns.OnSettingChanged()
    end)

    f.maxHeightRow = CreateStepperRow(bgPage, f.bgPaddingRow, -2, "Max Window Height", function()
        ns.db.maxHeightRatio = ns.ClampNumber(ns.db.maxHeightRatio - 0.05, ns.MIN_HEIGHT_RATIO, ns.MAX_HEIGHT_RATIO, ns.DEFAULTS.maxHeightRatio)
        ns.OnSettingChanged()
    end, function()
        ns.db.maxHeightRatio = ns.ClampNumber(ns.db.maxHeightRatio + 0.05, ns.MIN_HEIGHT_RATIO, ns.MAX_HEIGHT_RATIO, ns.DEFAULTS.maxHeightRatio)
        ns.OnSettingChanged()
    end)

    ---------------------------------------------------------------------------
    -- Shared Live Sample Preview Box
    ---------------------------------------------------------------------------
    local previewBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewBox:SetSize(308, 78)
    previewBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 46)
    f.previewBox = previewBox

    local previewHeader = previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewHeader:SetPoint("TOPLEFT", previewBox, "TOPLEFT", 12, -10)
    previewHeader:SetPoint("RIGHT", previewBox, "RIGHT", -12, 0)
    previewHeader:SetJustifyH("LEFT")
    previewHeader:SetTextColor(1.0, 0.82, 0.0)
    previewHeader:SetText("QUESTS")
    f.previewHeader = previewHeader

    local previewTitle = previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewTitle:SetPoint("TOPLEFT", previewHeader, "BOTTOMLEFT", 0, -4)
    previewTitle:SetPoint("RIGHT", previewBox, "RIGHT", -12, 0)
    previewTitle:SetJustifyH("LEFT")
    previewTitle:SetTextColor(0.95, 0.80, 0.30)
    previewTitle:SetText("The Midnight Vigil")
    f.previewTitle = previewTitle

    local previewBody = previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewBody:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 8, -3)
    previewBody:SetPoint("RIGHT", previewBox, "RIGHT", -12, 0)
    previewBody:SetJustifyH("LEFT")
    previewBody:SetTextColor(0.88, 0.88, 0.88)
    previewBody:SetText("- Void Shards collected: 5/8")
    f.previewBody = previewBody

    ---------------------------------------------------------------------------
    -- Bottom Action Buttons
    ---------------------------------------------------------------------------
    local enableBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    enableBtn:SetSize(96, 24)
    enableBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
    enableBtn:SetScript("OnClick", function()
        ns.db.enabled = not ns.db.enabled
        ns.OnSettingChanged()
    end)
    f.enableBtn = enableBtn

    local settingsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    settingsBtn:SetSize(112, 24)
    settingsBtn:SetPoint("LEFT", enableBtn, "RIGHT", 6, 0)
    settingsBtn:SetText("Blizzard Options")
    settingsBtn:SetScript("OnClick", function()
        ns.OpenSettings()
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(88, 24)
    resetBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
    resetBtn:SetText("Reset All")
    resetBtn:SetScript("OnClick", function()
        ns.ResetDefaults()
    end)

    local pos = ns.db.panelPosition
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    f:Hide()

    f:SetScript("OnShow", ns.RefreshQuickPanel)

    panel = f
    SetActiveTab(activeTab)
    ns.RefreshQuickPanel()
    return f
end

function ns.ToggleQuickPanel()
    if not ns.db then
        return
    end
    local f = CreateQuickPanel()
    f:SetShown(not f:IsShown())
end
