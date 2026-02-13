-- Bimmies: Delete lowest value grey item addon

local addonName = "Bimmies"

-- Saved variables will be initialized in ADDON_LOADED event

-- Helper function to safely get setting value with default
local function GetSetting(settingName, default)
    if BimmiesDB and BimmiesDB.settings and BimmiesDB.settings[settingName] ~= nil then
        return BimmiesDB.settings[settingName]
    end
    return default == nil and true or default
end

-- Function to scan bags and find the lowest value grey item stack
local function FindLowestValueGreyItem()
    local lowestValue = nil
    local lowestItemInfo = nil

    -- Iterate through all bags (0-4, where 0 is backpack and 1-4 are bags)
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Get item details
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                      itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = C_Item.GetItemInfo(itemID)

                -- Check if item is grey (poor quality, quality = 0)
                if itemQuality == 0 and sellPrice and sellPrice > 0 then
                    local totalValue = sellPrice * stackCount

                    -- Track the lowest value item
                    if not lowestValue or totalValue < lowestValue then
                        lowestValue = totalValue
                        lowestItemInfo = {
                            bag = bag,
                            slot = slot,
                            itemLink = itemLink,
                            stackCount = stackCount,
                            unitPrice = sellPrice,
                            totalValue = totalValue
                        }
                    end
                end
            end
        end
    end

    return lowestItemInfo
end

-- Main function called by the keybind
function Bimmies_DeleteLowestGreyItem()
    local itemInfo = FindLowestValueGreyItem()

    if itemInfo then
        -- Store info before deletion
        local itemLink = itemInfo.itemLink
        local stackCount = itemInfo.stackCount
        local totalValue = itemInfo.totalValue

        -- Delete the item
        C_Container.PickupContainerItem(itemInfo.bag, itemInfo.slot)
        DeleteCursorItem()

        -- Print what was deleted with coin textures
        local moneyStr = GetCoinTextureString(totalValue)
        print(string.format("[Bimmies] Deleted: %s x%d (Total value: %s)",
            itemLink,
            stackCount,
            moneyStr))
    else
        print("[Bimmies] No grey items found in bags.")
    end
end

-- Function to sell all grey items to vendor
local function SellAllGreyItems()
    -- Check if feature is enabled
    if not GetSetting("enableAutoSellGrey", true) then
        return
    end

    local totalValue = 0
    local itemsSold = 0

    -- Iterate through all bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Get item details
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                      itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = C_Item.GetItemInfo(itemID)

                -- Check if item is grey (poor quality, quality = 0)
                if itemQuality == 0 and sellPrice and sellPrice > 0 then
                    -- Sell the item
                    C_Container.UseContainerItem(bag, slot)
                    totalValue = totalValue + (sellPrice * stackCount)
                    itemsSold = itemsSold + 1
                end
            end
        end
    end

    -- Print summary if items were sold
    if itemsSold > 0 then
        local moneyStr = GetCoinTextureString(totalValue)
        print(string.format("[Bimmies] Auto-sold %d grey item stack(s) for %s", itemsSold, moneyStr))
    end
end

-- Function to toggle item marking for auto-sell
local function ToggleItemMarked(itemID)
    if BimmiesDB.markedItems[itemID] then
        BimmiesDB.markedItems[itemID] = nil
        return false
    else
        BimmiesDB.markedItems[itemID] = true
        return true
    end
end

-- Function to sell all marked items at vendor
local function SellMarkedItems()
    -- Check if feature is enabled
    if not GetSetting("enableAutoSellMarked", true) then
        return
    end

    local totalValue = 0
    local itemsSold = 0

    -- Iterate through all bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Check if item is marked for auto-sell
                if BimmiesDB.markedItems[itemID] then
                    -- Get item details
                    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                          itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = C_Item.GetItemInfo(itemID)

                    if sellPrice and sellPrice > 0 then
                        -- Sell the item
                        C_Container.UseContainerItem(bag, slot)
                        totalValue = totalValue + (sellPrice * stackCount)
                        itemsSold = itemsSold + 1
                    end
                end
            end
        end
    end

    -- Print summary if items were sold
    if itemsSold > 0 then
        local moneyStr = GetCoinTextureString(totalValue)
        print(string.format("[Bimmies] Auto-sold %d marked item stack(s) for %s", itemsSold, moneyStr))
    end
end

-- Function to create or get overlay icon for a button
local function GetOrCreateOverlay(button)
    if not button.bimmiesOverlay then
        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        overlay:SetSize(16, 16)
        overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.bimmiesOverlay = overlay
    end
    return button.bimmiesOverlay
end

-- Function to update overlay for a specific button
local function UpdateButtonOverlay(button, bag, slot)
    if not button then return end

    -- Check if marking overlay feature is enabled
    if not GetSetting("enableMarkingOverlay", true) then
        if button.bimmiesOverlay then
            button.bimmiesOverlay:Hide()
        end
        return
    end

    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

    -- Show overlay only if: slot has an item AND that item is marked
    if itemInfo and itemInfo.itemID and BimmiesDB.markedItems[itemInfo.itemID] then
        local overlay = GetOrCreateOverlay(button)
        overlay:SetAlpha(1)
        overlay:Show()
    else
        -- Hide overlay if: no item in slot OR item is not marked
        if button.bimmiesOverlay then
            button.bimmiesOverlay:SetAlpha(0)
            button.bimmiesOverlay:Hide()
        end
    end
end

-- Table to track all Bagnon item buttons we've seen
local bagnonButtonCache = {}

-- Function to update all stacks of a specific itemID
local function UpdateAllStacksOfItem(itemID)
    -- Check if Bagnon is active
    local bagnonLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded("Bagnon")) or (_G.BagBrother ~= nil) or (_G.Bagnon ~= nil)

    -- Iterate through all bags and slots
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                -- If this slot has the item we just marked/unmarked
                if itemInfo and itemInfo.itemID == itemID then
                    local foundButton = false

                    if bagnonLoaded then
                        -- For Bagnon, search through cached buttons
                        local cacheKey = bag .. "_" .. slot
                        if bagnonButtonCache[cacheKey] then
                            UpdateButtonOverlay(bagnonButtonCache[cacheKey], bag, slot)
                            foundButton = true
                        end

                        -- Also try to find it by searching all frames for buttons with matching bag/slot
                        if not foundButton then
                            for i = 1, 1000 do
                                -- Try multiple naming patterns
                                for _, name in ipairs({"ContainerFrame" .. math.floor(i/50) .. "Item" .. i, "BagnonContainerItem" .. i, "ContainerFrame1Item" .. i}) do
                                    local button = _G[name]
                                    if button and type(button.GetBag) == "function" and type(button.GetID) == "function" then
                                        local btnBag = button:GetBag()
                                        local btnSlot = button:GetID()
                                        if btnBag == bag and btnSlot == slot then
                                            bagnonButtonCache[cacheKey] = button
                                            UpdateButtonOverlay(button, bag, slot)
                                            foundButton = true
                                            break
                                        end
                                    end
                                end
                                if foundButton then break end
                            end
                        end
                    else
                        -- For Blizzard bags, use standard frame naming
                        for i = 1, NUM_CONTAINER_FRAMES do
                            local frameName = "ContainerFrame"..i
                            local frame = _G[frameName]
                            if frame and frame:GetID() == bag then
                                for j = 1, numSlots do
                                    local buttonName = frameName.."Item"..j
                                    local button = _G[buttonName]
                                    if button and button:GetID() == slot then
                                        UpdateButtonOverlay(button, bag, slot)
                                        foundButton = true
                                        break
                                    end
                                end
                            end
                            if foundButton then break end
                        end
                    end
                end
            end
        end
    end
end

-- Function to update all bag item overlays
local function UpdateBagItemOverlays()
    -- Check if Bagnon is loaded
    local bagnonLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded("Bagnon")) or (_G.BagBrother ~= nil) or (_G.Bagnon ~= nil)

    if bagnonLoaded then
        UpdateBagnonOverlays()
    else
        -- Default Blizzard bags
        for i = 1, NUM_CONTAINER_FRAMES do
            local frameName = "ContainerFrame"..i
            local frame = _G[frameName]

            if frame then
                -- Get the bag ID from the frame (same as in click handler)
                local bag = frame:GetID()
                local numSlots = C_Container.GetContainerNumSlots(bag)

                if numSlots and numSlots > 0 then
                    -- Iterate through all item button indices
                    for j = 1, numSlots do
                        local buttonName = frameName.."Item"..j
                        local button = _G[buttonName]

                        if button then
                            -- Get the slot ID from the button itself (same as in click handler)
                            local slot = button:GetID()
                            UpdateButtonOverlay(button, bag, slot)
                        end
                    end
                end
            end
        end
    end
end

-- Hook into the global bag item click handler (for default Blizzard bags)
local function InitializeBlizzardBagHook()
    -- Hook the modified click function that handles ctrl+clicks on bag items
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
        if button == "RightButton" and IsControlKeyDown() then
            local bag = self:GetParent():GetID()
            local slot = self:GetID()
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local marked = ToggleItemMarked(itemID)

                -- Get item link for display
                local itemLink = C_Container.GetContainerItemLink(bag, slot)

                -- Update this button immediately
                UpdateButtonOverlay(self, bag, slot)

                -- Update all other stacks of this item
                UpdateAllStacksOfItem(itemID)
            end
        end
    end)

    -- Hook ContainerFrame_Update to refresh overlays when bags are opened/updated
    hooksecurefunc("ContainerFrame_Update", function(frame)
        UpdateBagItemOverlays()
    end)
end

-- Hook into Bagnon's item button click handler
local function InitializeBagnonHook()
    -- Check if Bagnon is loaded
    if not C_AddOns or not C_AddOns.IsAddOnLoaded("Bagnon") then
        return false
    end

    -- Get the Bagnon addon and Item class
    local BagBrother = _G.BagBrother or _G.Bagnon
    if not BagBrother then
        return false
    end

    -- Find the Item class
    local ItemClass = BagBrother.Item
    if not ItemClass then
        -- Try alternate path
        for k, v in pairs(BagBrother) do
            if type(v) == "table" and v.PostClick then
                ItemClass = v
                break
            end
        end
    end

    if ItemClass and ItemClass.PostClick then
        -- Store the original PostClick function
        local originalPostClick = ItemClass.PostClick

        -- Replace PostClick to add our functionality
        ItemClass.PostClick = function(self, button)
            -- Call original first
            originalPostClick(self, button)

            -- Check for Ctrl+Right Click
            if button == "RightButton" and IsControlKeyDown() then
                local bag = self:GetBag()
                local slot = self:GetID()
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

                if itemInfo then
                    local itemID = itemInfo.itemID
                    local marked = ToggleItemMarked(itemID)

                    -- Get item link for display
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    
                    -- Update this button immediately
                    UpdateButtonOverlay(self, bag, slot)

                    -- Update all other stacks of this item
                    UpdateAllStacksOfItem(itemID)

                    -- Also trigger Bagnon to refresh (this ensures all items re-render)
                    local BagBrother = _G.BagBrother or _G.Bagnon
                    if BagBrother and BagBrother.Frames and type(BagBrother.Frames.Get) == "function" then
                        local frame = BagBrother.Frames:Get("inventory", "player")
                        if frame and frame.UpdateAllButtons then
                            frame:UpdateAllButtons()
                        elseif frame and frame.Update then
                            frame:Update()
                        end
                    end
                end
            end
        end

        -- Hook into Bagnon's item update to refresh overlays
        if ItemClass.Update then
            local originalUpdate = ItemClass.Update
            ItemClass.Update = function(self, ...)
                originalUpdate(self, ...)
                -- Update overlay for this specific item
                if self and self.GetBag and self.GetID then
                    local bag = self:GetBag()
                    local slot = self:GetID()

                    -- Cache this button for faster lookup later
                    local cacheKey = bag .. "_" .. slot
                    bagnonButtonCache[cacheKey] = self

                    UpdateButtonOverlay(self, bag, slot)
                end
            end
        end

        return true
    end

    return false
end

-- Function to update Bagnon bag item overlays
function UpdateBagnonOverlays()
    local BagBrother = _G.BagBrother or _G.Bagnon
    if not BagBrother then return end

    -- Trigger Bagnon to update all items by sending update signals
    -- This will cause all visible item buttons to call their Update method
    -- which we've hooked to update overlays
    if BagBrother.Frames and type(BagBrother.Frames.Get) == "function" then
        -- Get inventory frame and update it
        local frame = BagBrother.Frames:Get("inventory", "player")
        if frame and frame.Update then
            frame:Update()
        end
    end

    -- Also manually check visible item buttons as fallback
    -- Bagnon items are created with a prefix, try common patterns
    local patterns = {"ContainerFrame%dItem%d", "BagnonContainer%dItem%d"}
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            -- Try to find item buttons using various naming patterns
            for _, pattern in ipairs(patterns) do
                local buttonName = string.format(pattern, bag + 1, slot)
                local button = _G[buttonName]

                if button and button.GetBag and button.GetID then
                    if type(button.GetBag) == "function" and type(button.GetID) == "function" then
                        local btnBag = button:GetBag()
                        local btnSlot = button:GetID()
                        if btnBag == bag and btnSlot == slot then
                            UpdateButtonOverlay(button, bag, slot)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Initialize both hooks
local function InitializeBagItemHook()
    local bagnonLoaded = InitializeBagnonHook()
    if bagnonLoaded then
        print("[Bimmies] Bagnon detected - using Bagnon compatibility mode!")
    else
        InitializeBlizzardBagHook()
    end
end

-- Function to automatically repair gear at vendor
local function AutoRepairGear()
    -- Check if feature is enabled
    if not GetSetting("enableAutoRepair", true) then
        return
    end

    -- Check if merchant can repair
    if CanMerchantRepair() then
        local repairCost, canRepair = GetRepairAllCost()

        if canRepair and repairCost > 0 then
            -- Try to repair using guild bank funds first if available
            local useGuildBank = false
            if CanGuildBankRepair() then
                local guildRepairable = GetGuildBankWithdrawMoney()
                if guildRepairable == -1 or guildRepairable >= repairCost then
                    useGuildBank = true
                end
            end

            -- Perform the repair
            RepairAllItems(useGuildBank)

            -- Print repair summary
            local moneyStr = GetCoinTextureString(repairCost)
            if useGuildBank then
                print(string.format("[Bimmies] Auto-repaired all items using guild bank funds: %s", moneyStr))
            else
                print(string.format("[Bimmies] Auto-repaired all items for %s", moneyStr))
            end
        end
    end
end

-- Quest reward best value indicator
local rewardIcons = {}

local function ClearRewardIcons()
    for _, icon in pairs(rewardIcons) do
        if icon then
            icon:Hide()
        end
    end
    wipe(rewardIcons)
end

local function CreateRewardIcon(parent)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    return icon
end

local function HighlightBestReward()
    ClearRewardIcons()

    -- Check if feature is enabled
    if not GetSetting("enableQuestRewardHighlight", true) then
        return
    end

    -- Get number of quest reward choices
    local numChoices = GetNumQuestChoices()

    if numChoices <= 1 then
        return -- No choices or only one option
    end

    local bestValue = 0
    local bestIndex = nil

    -- Check each reward option for sell price
    for i = 1, numChoices do
        local itemLink = GetQuestItemLink("choice", i)

        if itemLink then
            local itemID = GetItemInfoFromHyperlink(itemLink)
            if itemID then
                local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)

                if sellPrice and sellPrice > bestValue then
                    bestValue = sellPrice
                    bestIndex = i
                end
            end
        end
    end

    -- Add gold icon to the best value item
    if bestIndex and bestValue > 0 then
        local rewardButton = _G["QuestInfoRewardsFrameQuestInfoItem" .. bestIndex]

        if not rewardButton then
            -- Try alternate frame name for quest complete
            rewardButton = _G["QuestInfoItem" .. bestIndex]
        end

        if rewardButton then
            local icon = CreateRewardIcon(rewardButton)
            icon:Show()
            table.insert(rewardIcons, icon)
        end
    end
end

-- Pickpocket tracking variables
local pickpocketActive = false
local pickpocketStartTime = 0

-- Function to start tracking pickpocket loot
local function StartPickpocketTracking()
    -- Check if feature is enabled
    if not GetSetting("enablePickpocketTracker", true) then
        return
    end

    pickpocketActive = true
    pickpocketStartTime = GetTime()
    BimmiesDB.pickpocketItems = {}
end

-- Function to process pickpocket loot
local function ProcessPickpocketLoot(itemLink, quantity)
    if not pickpocketActive then return end

    -- Ensure pickpocketGold is initialized
    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold or 0

    -- Get item info
    local itemID = GetItemInfoFromHyperlink(itemLink)
    if itemID then
        local itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)

        -- Track gray items (quality 0)
        if itemQuality == 0 and sellPrice and sellPrice > 0 then
            local totalValue = sellPrice * (quantity or 1)
            BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold + totalValue

            -- Store item info temporarily
            table.insert(BimmiesDB.pickpocketItems, {
                link = itemLink,
                quantity = quantity or 1,
                value = totalValue
            })
        end
    end
end

-- Function to process pickpocket money loot
local function ProcessPickpocketMoney(amount)
    if not pickpocketActive then return end

    -- Ensure pickpocketGold is initialized
    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold or 0

    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold + amount
end

-- Function to finalize pickpocket tracking and print summary
local function FinalizePickpocketTracking()
    if not pickpocketActive then return end

    -- Print a summary if we got anything
    if #BimmiesDB.pickpocketItems > 0 then
        local moneyStr = GetCoinTextureString(BimmiesDB.pickpocketGold)
        print(string.format("[Bimmies] Pickpocket Total: %s", moneyStr))
    end

    pickpocketActive = false
    BimmiesDB.pickpocketItems = {}
end

-- Function to add pickpocket earnings to spell tooltip
local function AddPickpocketTooltip(tooltip)
    -- Check if feature is enabled
    if not GetSetting("enablePickpocketTracker", true) then
        return
    end

    -- Check if this is the Pick Pocket spell
    local spellName, spellID = tooltip:GetSpell()

    -- Pick Pocket spell ID is 921 (Classic) or check by name
    if spellID == 921 or spellName == "Pick Pocket" or spellName == "Pick Pocket " then
        local goldAmount = (BimmiesDB and BimmiesDB.pickpocketGold) or 0
        tooltip:AddLine(" ")
        local moneyStr = GetCoinTextureString(goldAmount)
        tooltip:AddLine("|cFF00FF00Total Earned: " .. moneyStr .. "|r", 1, 1, 1)
        tooltip:Show() -- Refresh the tooltip to show our addition
    end
end

-- Hook into spell tooltips
local function InitializePickpocketTooltipHook()
    GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
        AddPickpocketTooltip(tooltip)
    end)
end

-- Create options panel
local function CreateOptionsPanel()
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

    -- Refresh function called when panel is opened
    panel.refresh = function()
        autoSellGreyCheck:SetChecked(GetSetting("enableAutoSellGrey", true))
        autoSellMarkedCheck:SetChecked(GetSetting("enableAutoSellMarked", true))
        autoRepairCheck:SetChecked(GetSetting("enableAutoRepair", true))
        questRewardCheck:SetChecked(GetSetting("enableQuestRewardHighlight", true))
        pickpocketCheck:SetChecked(GetSetting("enablePickpocketTracker", true))
        markingOverlayCheck:SetChecked(GetSetting("enableMarkingOverlay", true))
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
            panel.refresh()
            UpdateBagItemOverlays()
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

-- Event handler frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_MONEY")
frame:SetScript("OnEvent", function(self, event, ...)
    local arg1, arg2, arg3, arg4 = ...

    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize saved variables for marked items and pickpocket tracking
        BimmiesDB = BimmiesDB or {}
        BimmiesDB.markedItems = BimmiesDB.markedItems or {}
        BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold or 0
        BimmiesDB.pickpocketItems = BimmiesDB.pickpocketItems or {} -- Temporary storage for items during pickpocket

        -- Initialize settings with defaults
        BimmiesDB.settings = BimmiesDB.settings or {
            enableAutoSellGrey = true,
            enableAutoSellMarked = true,
            enableAutoRepair = true,
            enableQuestRewardHighlight = true,
            enablePickpocketTracker = true,
            enableMarkingOverlay = true
        }

        print("[Bimmies] Loaded! Set your keybind in ESC > Keybindings > Bimmies, or use /bimmies")
        print("[Bimmies] Type /bimmies config to open settings, or find it in ESC > Interface > AddOns > Bimmies")

        -- Create options panel
        CreateOptionsPanel()

        -- Initialize the bag item click hook
        InitializeBagItemHook()
        UpdateBagItemOverlays()

        -- Initialize pickpocket tooltip hook
        InitializePickpocketTooltipHook()
    elseif event == "MERCHANT_SHOW" then
        -- Repair gear when merchant window opens
        AutoRepairGear()
        -- Sell all marked items first
        SellMarkedItems()
        -- Then sell all grey items
        SellAllGreyItems()
    elseif event == "MERCHANT_CLOSED" then
        -- Update overlays after leaving vendor
        C_Timer.After(0.1, UpdateBagItemOverlays)
    elseif event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
        -- Small delay to ensure quest frame is fully loaded
        C_Timer.After(0.1, HighlightBestReward)
    elseif event == "QUEST_FINISHED" then
        ClearRewardIcons()
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Update overlays when bags change
        UpdateBagItemOverlays()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID
        local unit, castGUID, spellID = arg1, arg2, arg3

        -- Check if player cast Pick Pocket (spell ID 921)
        if unit == "player" and spellID == 921 then
            StartPickpocketTracking()
            -- Auto-finalize after 2 seconds (loot window timeout)
            C_Timer.After(2, FinalizePickpocketTracking)
        end
    elseif event == "CHAT_MSG_LOOT" then
        -- arg1 = message
        local message = arg1

        -- Check if this is a player loot message
        if pickpocketActive and message then
            -- Pattern for item loot: "You receive loot: [ItemLink]xQuantity" or "You receive loot: [ItemLink]"
            -- Also handle "You receive item: [ItemLink]" variant
            local itemLink, quantity = message:match("You receive loot: (.+)x(%d+)")
            if not itemLink then
                itemLink, quantity = message:match("You receive item: (.+)x(%d+)")
            end
            if not itemLink then
                itemLink = message:match("You receive loot: (.+)")
                quantity = 1
            end
            if not itemLink then
                itemLink = message:match("You receive item: (.+)")
                quantity = 1
            end

            if itemLink then
                ProcessPickpocketLoot(itemLink, tonumber(quantity) or 1)
            end
        end
    elseif event == "CHAT_MSG_MONEY" then
        -- arg1 = message
        local message = arg1

        if pickpocketActive and message then
            -- Pattern for money loot
            -- Examples: "You loot 1 Gold, 50 Silver, 25 Copper" or "You loot 50 Silver"
            local gold = message:match("(%d+) Gold") or 0
            local silver = message:match("(%d+) Silver") or 0
            local copper = message:match("(%d+) Copper") or 0

            gold = tonumber(gold) or 0
            silver = tonumber(silver) or 0
            copper = tonumber(copper) or 0

            local totalCopper = (gold * 10000) + (silver * 100) + copper
            if totalCopper > 0 then
                ProcessPickpocketMoney(totalCopper)
            end
        end
    end
end)

-- Slash command for testing
SLASH_BIMMIES1 = "/bimmies"
SLASH_BIMMIES2 = "/bim"
SlashCmdList["BIMMIES"] = function(msg)
    if msg == "config" or msg == "settings" or msg == "options" then
        -- Open the options panel
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Bimmies")
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory("Bimmies")
            -- Call twice to fix a Blizzard bug where it doesn't open the first time
            InterfaceOptionsFrame_OpenToCategory("Bimmies")
        end
    elseif msg == "update" or msg == "refresh" then
        UpdateBagItemOverlays()
        print("[Bimmies] Overlays updated!")
    elseif msg == "clear" then
        BimmiesDB.markedItems = {}
        UpdateBagItemOverlays()
        print("[Bimmies] All marked items cleared!")
    elseif msg == "pp" or msg == "pickpocket" then
        local moneyStr = GetCoinTextureString(BimmiesDB.pickpocketGold)
        print(string.format("[Bimmies] Total pickpocket earnings: %s", moneyStr))
    elseif msg == "ppreset" or msg == "pickpocketreset" then
        BimmiesDB.pickpocketGold = 0
        print("[Bimmies] Pickpocket earnings reset to 0!")
    elseif msg == "hideall" then
        print("[Bimmies] Forcefully hiding all overlays...")
        local count = 0
        for i = 1, NUM_CONTAINER_FRAMES do
            local frameName = "ContainerFrame"..i
            local frame = _G[frameName]
            if frame then
                local bag = frame:GetID()
                local numSlots = C_Container.GetContainerNumSlots(bag)
                if numSlots and numSlots > 0 then
                    for j = 1, numSlots do
                        local buttonName = frameName.."Item"..j
                        local button = _G[buttonName]
                        if button and button.bimmiesOverlay then
                            button.bimmiesOverlay:Hide()
                            count = count + 1
                        end
                    end
                end
            end
        end
        print(string.format("[Bimmies] Hid %d overlays", count))
    elseif msg == "debug" then
        print("[Bimmies] Scanning for overlays...")
        local count = 0
        for i = 1, NUM_CONTAINER_FRAMES do
            local frameName = "ContainerFrame"..i
            local frame = _G[frameName]
            if frame then
                local bag = frame:GetID()
                local numSlots = C_Container.GetContainerNumSlots(bag)
                if numSlots and numSlots > 0 then
                    for j = 1, numSlots do
                        local buttonName = frameName.."Item"..j
                        local button = _G[buttonName]
                        if button and button.bimmiesOverlay then
                            local slot = button:GetID()
                            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                            local isShown = button.bimmiesOverlay:IsShown()
                            print(string.format("  Bag %d Slot %d: overlay=%s, hasItem=%s",
                                bag, slot, tostring(isShown), tostring(itemInfo ~= nil)))
                            if itemInfo then
                                print(string.format("    ItemID: %d, Marked: %s",
                                    itemInfo.itemID, tostring(BimmiesDB.markedItems[itemInfo.itemID] == true)))
                            end
                            count = count + 1
                        end
                    end
                end
            end
        end
        print(string.format("[Bimmies] Found %d overlays", count))
    elseif msg == "help" then
        print("[Bimmies] Available commands:")
        print("  /bimmies - Delete lowest value grey item")
        print("  /bimmies config - Open settings panel")
        print("  /bimmies update - Refresh overlay icons")
        print("  /bimmies clear - Clear all marked items")
        print("  /bimmies pp - Show pickpocket earnings")
        print("  /bimmies ppreset - Reset pickpocket earnings")
    else
        Bimmies_DeleteLowestGreyItem()
    end
end
