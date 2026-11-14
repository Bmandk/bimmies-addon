-- Bimmies: Options Panel Module
-- Handles the settings UI panel

-- True if an XML template exists. Modern clients removed several old options
-- templates; C_XMLUtil lets us check before CreateFrame throws.
local function TemplateExists(template)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        return C_XMLUtil.GetTemplateInfo(template) ~= nil
    end
    return true -- older clients without C_XMLUtil still ship the classic templates
end

local function FirstTemplate(...)
    for i = 1, select("#", ...) do
        local template = select(i, ...)
        if TemplateExists(template) then
            return template
        end
    end
end

-- Open the settings panel (used by /bimmies config and the minimap button)
function Bimmies_OpenOptions()
    if Settings and Settings.OpenToCategory then
        -- Modern Settings API wants the category ID; fall back to the name
        local categoryID = BimmiesSettingsCategory and BimmiesSettingsCategory.GetID
            and BimmiesSettingsCategory:GetID()
        Settings.OpenToCategory(categoryID or "Bimmies")
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("Bimmies")
        -- Call twice to fix a Blizzard bug where it doesn't open the first time
        InterfaceOptionsFrame_OpenToCategory("Bimmies")
    end
end

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
        local template = FirstTemplate("InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate")
        local checkbox = CreateFrame("CheckButton", "Bimmies" .. name .. "Checkbox", panel, template)
        checkbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, yOffset)
        local text = checkbox.Text or _G[checkbox:GetName() .. "Text"]
        if text then
            text:SetText(label)
        end
        checkbox.tooltipText = tooltip
        checkbox:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        checkbox:HookScript("OnLeave", GameTooltip_Hide or function() GameTooltip:Hide() end)

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

    local noPingCheck = CreateCheckbox(
        "NoPingChatTabs",
        "Block pings when middle-clicking chat tabs",
        "While hovering a chat tab, middle-click only closes the tab and won't fire your Ping keybind. Not active during combat.",
        -188,
        "enableNoPingChatTabs"
    )

    local minimapCheck = CreateCheckbox(
        "MinimapButton",
        "Show minimap button",
        "Shows the Bimmies button on the minimap. Left-click opens settings; drag to reposition.",
        -214,
        "showMinimapButton"
    )
    local minimapBaseClick = minimapCheck:GetScript("OnClick")
    minimapCheck:SetScript("OnClick", function(self, ...)
        minimapBaseClick(self, ...)
        MinimapButton_Refresh()
    end)

    -- Soul Shard Manager section
    local shardHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    shardHeader:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -252)
    shardHeader:SetText("Soul Shard Manager (requires AutoHotKey script)")

    local soulShardCheck = CreateCheckbox(
        "SoulShardManager",
        "Enable soul shard auto-delete signal",
        "Shows a green pixel at the top-left of the screen when soul shards exceed the threshold. The external AHK script reads this pixel and triggers deletion.",
        -278,
        "enableSoulShardManager"
    )

    -- Threshold slider
    local sliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 4, -312)
    sliderLabel:SetText("Soul Shard threshold: " .. GetSetting("soulShardThreshold", 8))

    local sliderTemplate = FirstTemplate("OptionsSliderTemplate", "UISliderTemplateWithLabels", "UISliderTemplate")
    local slider = CreateFrame("Slider", "BimmiesSoulShardSlider", panel, sliderTemplate)
    slider:SetPoint("TOPLEFT", sliderLabel, "BOTTOMLEFT", 0, -8)
    slider:SetWidth(200)
    slider:SetMinMaxValues(1, 28)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(GetSetting("soulShardThreshold", 8))

    local function SliderLabel(key, point, relPoint)
        local fs = slider[key] or _G[slider:GetName() .. key]
        if not fs then
            fs = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint(point, slider, relPoint, 0, -2)
        end
        return fs
    end
    SliderLabel("Low", "TOPLEFT", "BOTTOMLEFT"):SetText("1")
    SliderLabel("High", "TOPRIGHT", "BOTTOMRIGHT"):SetText("28")

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
        noPingCheck:SetChecked(GetSetting("enableNoPingChatTabs", true))
        minimapCheck:SetChecked(GetSetting("showMinimapButton", true))
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
            BimmiesDB.settings.enableNoPingChatTabs = true
            BimmiesDB.settings.enableSoulShardManager = false
            BimmiesDB.settings.soulShardThreshold = 8
            BimmiesDB.settings.showMinimapButton = true
            panel.refresh()
            MinimapButton_Refresh()
            UpdateBagItemOverlays()
            SoulShards_UpdateSignal()
        end
    end

    -- Modern Settings canvas calls OnRefresh/OnDefault; legacy panel uses refresh/default
    panel.OnRefresh = panel.refresh
    panel.OnDefault = panel.default
    panel.OnCommit = function() end
    panel:HookScript("OnShow", panel.refresh)

    -- Register the panel in the appropriate way for this WoW version
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Modern Settings API (Forever, Retail, Classic Era 1.15+)
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        -- Global so /bimmies config can open it by ID
        BimmiesSettingsCategory = category
    elseif InterfaceOptions_AddCategory then
        -- Classic/Pre-Dragonflight
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end
