-- Bimmies: Bag Hooks Module
-- Handles bag addon compatibility and overlay update logic
-- Depends on ItemMarking.lua for overlay functions

-- Table to track all Bagnon item buttons we've seen
local bagnonButtonCache = {}

-- Function to update all stacks of a specific itemID
function UpdateAllStacksOfItem(itemID)
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
function UpdateBagItemOverlays()
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
function InitializeBlizzardBagHook()
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
function InitializeBagnonHook()
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
-- Made global for compatibility with other modules
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
-- Called by Core.lua after all modules are loaded
function BagHooks_Initialize()
    local bagnonLoaded = InitializeBagnonHook()
    if bagnonLoaded then
        print("[Bimmies] Bagnon detected - using Bagnon compatibility mode!")
    else
        InitializeBlizzardBagHook()
    end
    UpdateBagItemOverlays()
end
