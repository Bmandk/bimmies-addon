-- Bimmies: Item Marking Module
-- Core marking logic - only handles marking/unmarking and overlay creation
-- Bag iteration and update functions are in BagHooks.lua

-- Function to toggle item marking for auto-sell
function ToggleItemMarked(itemID)
    if BimmiesDB.markedItems[itemID] then
        BimmiesDB.markedItems[itemID] = nil
        return false
    else
        BimmiesDB.markedItems[itemID] = true
        return true
    end
end

-- Function to create or get overlay icon for a button
function GetOrCreateOverlay(button)
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
function UpdateButtonOverlay(button, bag, slot)
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
