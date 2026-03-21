-- Bimmies: Options Panel Module
-- Handles the settings UI panel

-- Create options panel
-- Called by Core.lua after all modules are loaded
function Options_CreatePanel()
    local panel = CreateFrame("Frame", "BimmiesOptionsPanel", UIParent)
    panel.name = "Bimmies"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bimmies Settings")

    -- Description
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Toggle features on or off:")

    -- Helper function to create checkboxes
    local function CreateCheckbox(name, label, tooltip, yOffset, setting)
        local checkbox = CreateFrame("CheckButton", "Bimmies" .. name .. "Checkbox", panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, yOffset)
        _G[checkbox:GetName() .. "Text"]:SetText(label)
        checkbox.tooltipText = tooltip

        checkbox:SetChecked(GetSetting(setting, true))
        checkbox:SetScript("OnClick", function(self)
            if BimmiesDB and BimmiesDB.settings then
                BimmiesDB.settings[setting] = self:GetChecked()
                -- Update overlays if marking overlay setting changed
                if setting == "enableMarkingOverlay" then
                    UpdateBagItemOverlays()
                end
            end
        end)

        return checkbox
    end

    -- Create checkboxes for each feature
    local autoSellGreyCheck = CreateCheckbox(
        "AutoSellGrey",
        "Auto-sell grey items at vendor",
        "Automatically sells all grey (poor quality) items when you open a merchant window.",
        -32,
        "enableAutoSellGrey"
    )

    local autoSellMarkedCheck = CreateCheckbox(
        "AutoSellMarked",
        "Auto-sell marked items at vendor",
        "Automatically sells items you've marked (Ctrl+Right Click) when you open a merchant window.",
        -58,
        "enableAutoSellMarked"
    )

    local autoRepairCheck = CreateCheckbox(
        "AutoRepair",
        "Auto-repair at vendor",
        "Automatically repairs all equipped items when you open a merchant window.",
        -84,
        "enableAutoRepair"
    )

    local questRewardCheck = CreateCheckbox(
        "QuestRewardHighlight",
        "Highlight best quest rewards",
        "Shows a gold coin icon on the highest-value quest reward option.",
        -110,
        "enableQuestRewardHighlight"
    )

    local pickpocketCheck = CreateCheckbox(
        "PickpocketTracker",
        "Track pickpocket earnings",
        "Tracks gold earned from pickpocketing and shows it on the Pick Pocket spell tooltip.",
        -136,
        "enablePickpocketTracker"
    )

    local markingOverlayCheck = CreateCheckbox(
        "MarkingOverlay",
        "Show marking overlay icons",
        "Shows gold coin icons on items you've marked for auto-sell in your bags.",
        -162,
        "enableMarkingOverlay"
    )

    -- Soul Shard Manager section
    local shardHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shardHeader:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -200)
    shardHeader:SetText("Soul Shard Manager (requires AutoHotKey script)")

    local soulShardCheck = CreateCheckbox(
        "SoulShardManager",
        "Enable soul shard auto-delete signal",
        "Shows a green pixel at the top-left of the screen when soul shards exceed the threshold. The external AHK script reads this pixel and triggers deletion.",
        -226,
        "enableSoulShardManager"
    )

    -- Threshold slider
    local sliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 4, -260)
    sliderLabel:SetText("Soul Shard threshold: " .. GetSetting("soulShardThreshold", 8))

    local slider = CreateFrame("Slider", "BimmiesSoulShardSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetWidth(200)
    slider:SetMinMaxValues(1, 28)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(GetSetting("soulShardThreshold", 8))

    _G[slider:GetName() .. "Low"]:SetText("1")
    _G[slider:GetName() .. "High"]:SetText("28")

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        if BimmiesDB and BimmiesDB.settings then
            BimmiesDB.settings.soulShardThreshold = value
        end
        sliderLabel:SetText("Soul Shard threshold: " .. value)
        SoulShards_UpdateSignal()
    end)

    -- Refresh function called when panel is opened
    panel.refresh = function()
        autoSellGreyCheck:SetChecked(GetSetting("enableAutoSellGrey", true))
        autoSellMarkedCheck:SetChecked(GetSetting("enableAutoSellMarked", true))
        autoRepairCheck:SetChecked(GetSetting("enableAutoRepair", true))
        questRewardCheck:SetChecked(GetSetting("enableQuestRewardHighlight", true))
        pickpocketCheck:SetChecked(GetSetting("enablePickpocketTracker", true))
        markingOverlayCheck:SetChecked(GetSetting("enableMarkingOverlay", true))
        soulShardCheck:SetChecked(GetSetting("enableSoulShardManager", false))
        slider:SetValue(GetSetting("soulShardThreshold", 8))
        sliderLabel:SetText("Soul Shard threshold: " .. GetSetting("soulShardThreshold", 8))
    end

    -- Default function called when defaults button is clicked
    panel.default = function()
        if BimmiesDB and BimmiesDB.settings then
            BimmiesDB.settings.enableAutoSellGrey = true
            BimmiesDB.settings.enableAutoSellMarked = true
            BimmiesDB.settings.enableAutoRepair = true
            BimmiesDB.settings.enableQuestRewardHighlight = true
            BimmiesDB.settings.enablePickpocketTracker = true
            BimmiesDB.settings.enableMarkingOverlay = true
            BimmiesDB.settings.enableSoulShardManager = false
            BimmiesDB.settings.soulShardThreshold = 8
            panel.refresh()
            UpdateBagItemOverlays()
            SoulShards_UpdateSignal()
        end
    end

    -- Register the panel in the appropriate way for this WoW version
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Modern WoW (Dragonflight+)
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        -- Classic/Pre-Dragonflight
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end
