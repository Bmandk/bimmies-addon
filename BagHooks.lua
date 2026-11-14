-- Bimmies: Bag Hooks Module
-- Handles bag addon compatibility and overlay update logic
-- Depends on ItemMarking.lua for overlay functions

-- Table to track all Bagnon item buttons we've seen
local bagnonButtonCache = {}

local function IsBagnonActive()
    return Bimmies_IsAddOnLoaded("Bagnon") or (_G.BagBrother ~= nil) or (_G.Bagnon ~= nil)
end

-- Function to update all stacks of a specific itemID
function UpdateAllStacksOfItem(itemID)
    -- Check if Bagnon is active
    local bagnonLoaded = IsBagnonActive()

    if not bagnonLoaded then
        -- Blizzard bags: refreshing every visible button is cheap and handles
        -- both the classic per-bag frames and the modern combined bag.
        UpdateBlizzardBagOverlays()
        return
    end

    -- Iterate through all bags and slots
    for bag = 0, Bimmies_GetLastBagID() do
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
                    end
                end
            end
        end
    end
end

-- Buttons whose OnClick we've already hooked (weak keys so pooled buttons can be collected)
local hookedButtons = setmetatable({}, { __mode = "k" })
-- Container frames whose show/update we've already hooked
local hookedFrames = {}

-- Bag/slot for a Blizzard bag item button.
-- Modern clients (Forever/Retail) expose GetBagID(); classic uses the parent frame's ID.
local function GetButtonBagAndSlot(button)
    local bag
    if button.GetBagID then
        bag = button:GetBagID()
    elseif button.GetParent and button:GetParent() then
        bag = button:GetParent():GetID()
    end
    return bag, button:GetID()
end

-- Ctrl+Right Click handler for Blizzard bag buttons
local function OnBlizzardItemClick(self, mouseButton)
    if mouseButton ~= "RightButton" or not IsControlKeyDown() then return end

    local bag, slot = GetButtonBagAndSlot(self)
    if type(bag) ~= "number" then return end

    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
    if itemInfo and itemInfo.itemID then
        ToggleItemMarked(itemInfo.itemID)
        UpdateBlizzardBagOverlays()
    end
end

local function HookItemButton(button)
    if hookedButtons[button] then return end
    hookedButtons[button] = true
    button:HookScript("OnClick", OnBlizzardItemClick)
end

-- All Blizzard container frames that may hold item buttons
local function GetBlizzardContainerFrames()
    local frames = {}
    if _G.ContainerFrameCombinedBags then
        table.insert(frames, _G.ContainerFrameCombinedBags)
    end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            table.insert(frames, frame)
        end
    end
    return frames
end

-- Call fn(button) for each item button in a container frame
local function ForEachItemButton(frame, fn)
    if frame.EnumerateValidItems then
        -- Modern bag UI
        for _, button in frame:EnumerateValidItems() do
            fn(button)
        end
    elseif frame.Items then
        for _, button in ipairs(frame.Items) do
            fn(button)
        end
    else
        -- Classic bag UI: buttons are named ContainerFrameNItemM
        local frameName = frame:GetName()
        local numSlots = C_Container.GetContainerNumSlots(frame:GetID()) or 0
        for j = 1, numSlots do
            local button = _G[frameName .. "Item" .. j]
            if button then
                fn(button)
            end
        end
    end
end

-- Call fn(button, bag, slot) for every item button in every visible Blizzard bag frame.
-- Global so SlashCommands.lua debug helpers can reuse it.
function Bimmies_ForEachBlizzardBagButton(fn)
    for _, frame in ipairs(GetBlizzardContainerFrames()) do
        if frame:IsShown() then
            ForEachItemButton(frame, function(button)
                local bag, slot = GetButtonBagAndSlot(button)
                if type(bag) == "number" then
                    fn(button, bag, slot)
                end
            end)
        end
    end
end

function UpdateBlizzardBagOverlays()
    Bimmies_ForEachBlizzardBagButton(function(button, bag, slot)
        HookItemButton(button)
        UpdateButtonOverlay(button, bag, slot)
    end)
end

-- Function to update all bag item overlays
function UpdateBagItemOverlays()
    if IsBagnonActive() then
        UpdateBagnonOverlays()
    else
        UpdateBlizzardBagOverlays()
    end
end

-- Hook Blizzard bag frames so overlays refresh (and click hooks attach) whenever bags open or redraw
function InitializeBlizzardBagHook()
    local function DeferredUpdate()
        C_Timer.After(0, UpdateBlizzardBagOverlays)
    end

    for _, frame in ipairs(GetBlizzardContainerFrames()) do
        if not hookedFrames[frame] then
            hookedFrames[frame] = true
            frame:HookScript("OnShow", DeferredUpdate)
            -- Modern bag UI redraws via a per-frame UpdateItems method
            if type(frame.UpdateItems) == "function" then
                hooksecurefunc(frame, "UpdateItems", DeferredUpdate)
            end
        end
    end

    -- Classic bag UI redraws via a global function
    if type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", DeferredUpdate)
    end
end

-- Hook into Bagnon's item button click handler
function InitializeBagnonHook()
    -- Check if Bagnon is loaded
    if not Bimmies_IsAddOnLoaded("Bagnon") then
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
    for bag = 0, Bimmies_GetLastBagID() do
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
