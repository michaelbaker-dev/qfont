local _, ns = ...

local settingsCategory

function ns.InitSettings()
    local db = ns.db
    local defaults = ns.DEFAULTS

    local category = Settings.RegisterVerticalLayoutCategory("qfont")

    local function OnChanged()
        ns.OnSettingChanged()
    end

    local function FormatPixels(value)
        return string.format("%d px", math.floor(value + 0.5))
    end

    local function FormatPercent(value)
        return string.format("%d%%", math.floor(value * 100 + 0.5))
    end

    ---------------------------------------------------------------------------
    -- Font Settings
    ---------------------------------------------------------------------------
    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_ENABLED",
            "enabled",
            db,
            Settings.VarType.Boolean,
            "Enable Custom Quest Fonts",
            defaults.enabled
        )
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(
            category,
            setting,
            "Enable or disable custom font and size overrides on the Quest / Objective Tracker."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_FONT",
            "font",
            db,
            Settings.VarType.String,
            "Font Family",
            defaults.font
        )
        setting:SetValueChangedCallback(OnChanged)

        local function GetFontOptions()
            local container = Settings.CreateControlTextContainer()
            local fonts = ns.GetAvailableFonts()
            for i = 1, #fonts do
                local entry = fonts[i]
                local tip = entry.source == "lsm" and "Provided by LibSharedMedia-3.0." or "Built-in World of Warcraft font."
                container:Add(entry.id, entry.name, tip)
            end
            return container:GetData()
        end

        Settings.CreateDropdown(
            category,
            setting,
            GetFontOptions,
            "Choose the font face for the Quest / Objective Tracker."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_OUTLINE",
            "outline",
            db,
            Settings.VarType.String,
            "Font Outline",
            defaults.outline
        )
        setting:SetValueChangedCallback(OnChanged)

        local function GetOutlineOptions()
            local container = Settings.CreateControlTextContainer()
            for i = 1, #ns.OUTLINE_OPTIONS do
                local opt = ns.OUTLINE_OPTIONS[i]
                container:Add(opt.value, opt.label, opt.tooltip)
            end
            return container:GetData()
        end

        Settings.CreateDropdown(
            category,
            setting,
            GetOutlineOptions,
            "Set the outline / rendering flags applied to tracker text."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_SHADOW",
            "shadow",
            db,
            Settings.VarType.Boolean,
            "Text Drop Shadow",
            defaults.shadow
        )
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(
            category,
            setting,
            "Draw a subtle dark drop shadow behind Quest / Objective Tracker text for readability."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_HEADER_SIZE",
            "headerSize",
            db,
            Settings.VarType.Number,
            "Section Header Size",
            defaults.headerSize
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(ns.MIN_FONT_SIZE, ns.MAX_FONT_SIZE, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPixels)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Font size for tracker section headers (Quests, Campaign, Achievements, etc.)."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_TITLE_SIZE",
            "titleSize",
            db,
            Settings.VarType.Number,
            "Quest Title Size",
            defaults.titleSize
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(ns.MIN_FONT_SIZE, ns.MAX_FONT_SIZE, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPixels)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Font size for individual quest and achievement titles."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BODY_SIZE",
            "bodySize",
            db,
            Settings.VarType.Number,
            "Objective Line Size",
            defaults.bodySize
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(ns.MIN_FONT_SIZE, ns.MAX_FONT_SIZE, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPixels)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Font size for quest objective bullet lines and progress text."
        )
    end

    ---------------------------------------------------------------------------
    -- Quest List Background Texture Settings
    ---------------------------------------------------------------------------
    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_ENABLED",
            "bgEnabled",
            db,
            Settings.VarType.Boolean,
            "Show Quest List Background",
            defaults.bgEnabled
        )
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(
            category,
            setting,
            "Display a textured background frame behind the Quest / Objective Tracker."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_TEXTURE",
            "bgTexture",
            db,
            Settings.VarType.String,
            "Background Texture",
            defaults.bgTexture
        )
        setting:SetValueChangedCallback(OnChanged)

        local function GetBackgroundOptions()
            local container = Settings.CreateControlTextContainer()
            local bgs = ns.GetAvailableBackgrounds()
            for i = 1, #bgs do
                local entry = bgs[i]
                local tip = entry.source == "lsm" and "Provided by LibSharedMedia-3.0." or "Built-in World of Warcraft texture."
                container:Add(entry.id, entry.name, tip)
            end
            return container:GetData()
        end

        Settings.CreateDropdown(
            category,
            setting,
            GetBackgroundOptions,
            "Choose the background texture for the Quest / Objective Tracker (Parchment, Marble, Rock, Dialog, Solid, or SharedMedia)."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_BORDER",
            "bgBorder",
            db,
            Settings.VarType.String,
            "Background Border",
            defaults.bgBorder
        )
        setting:SetValueChangedCallback(OnChanged)

        local function GetBorderOptions()
            local container = Settings.CreateControlTextContainer()
            local borders = ns.GetAvailableBorders()
            for i = 1, #borders do
                local entry = borders[i]
                local tip = entry.source == "lsm" and "Provided by LibSharedMedia-3.0." or "Built-in World of Warcraft border."
                container:Add(entry.id, entry.name, tip)
            end
            return container:GetData()
        end

        Settings.CreateDropdown(
            category,
            setting,
            GetBorderOptions,
            "Choose the border frame around the Quest List background."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_TINT",
            "bgTint",
            db,
            Settings.VarType.String,
            "Background Color Tint",
            defaults.bgTint
        )
        setting:SetValueChangedCallback(OnChanged)

        local function GetTintOptions()
            local container = Settings.CreateControlTextContainer()
            for i = 1, #ns.BG_TINT_OPTIONS do
                local opt = ns.BG_TINT_OPTIONS[i]
                container:Add(opt.id, opt.label, "Tint the background and border with this color preset.")
            end
            return container:GetData()
        end

        Settings.CreateDropdown(
            category,
            setting,
            GetTintOptions,
            "Color tint applied over the background texture (pick 'Natural' for untinted Parchment/Marble/Rock artwork)."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_ALPHA",
            "bgAlpha",
            db,
            Settings.VarType.Number,
            "Background Opacity",
            defaults.bgAlpha
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(0.0, 1.0, 0.05)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercent)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Adjust how transparent or opaque the Quest List background texture is."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_PADDING",
            "bgPadding",
            db,
            Settings.VarType.Number,
            "Background Padding",
            defaults.bgPadding
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(ns.MIN_BG_PADDING, ns.MAX_BG_PADDING, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPixels)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Extra margin (in pixels) around the quest list text inside the background."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_BG_FIT_CONTENT",
            "bgFitContent",
            db,
            Settings.VarType.Boolean,
            "Fit Background to Tracked Quests",
            defaults.bgFitContent
        )
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(
            category,
            setting,
            "Resize the background tightly around currently tracked quests. Uncheck to fill the full Edit Mode tracker height."
        )
    end

    ---------------------------------------------------------------------------
    -- Scroll Bar & Max Height Settings
    ---------------------------------------------------------------------------
    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_SCROLLBAR_ENABLED",
            "scrollBarEnabled",
            db,
            Settings.VarType.Boolean,
            "Show Scroll Bar (When Overflowing)",
            defaults.scrollBarEnabled
        )
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(
            category,
            setting,
            "Display a draggable scroll bar alongside the quest list whenever tracked quests exceed the visible window height."
        )
    end

    do
        local setting = Settings.RegisterAddOnSetting(
            category,
            "QFONT_MAX_HEIGHT_RATIO",
            "maxHeightRatio",
            db,
            Settings.VarType.Number,
            "Max Quest Window Height",
            defaults.maxHeightRatio
        )
        setting:SetValueChangedCallback(OnChanged)

        local options = Settings.CreateSliderOptions(ns.MIN_HEIGHT_RATIO, ns.MAX_HEIGHT_RATIO, 0.05)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercent)
        Settings.CreateSlider(
            category,
            setting,
            options,
            "Maximum vertical height of the quest list (% of screen height) before scrolling kicks in."
        )
    end

    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
end

function ns.OpenSettings()
    if InCombatLockdown() then
        ns.Print("Cannot open Blizzard Settings while in combat. Use |cffffffff/qfont|r for the live config window.")
        return
    end
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end
