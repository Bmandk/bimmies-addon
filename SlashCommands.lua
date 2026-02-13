-- Bimmies: Slash Commands Module
-- Handles all slash commands for the addon

-- Slash command registration
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
        -- Default action: delete lowest grey item
        Bimmies_DeleteLowestGreyItem()
    end
end
