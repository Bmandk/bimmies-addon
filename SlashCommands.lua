-- Bimmies: Slash Commands Module
-- Handles all slash commands for the addon

-- Slash command registration
SLASH_BIMMIES1 = "/bimmies"
SLASH_BIMMIES2 = "/bim"

SlashCmdList["BIMMIES"] = function(msg)
    if msg == "config" or msg == "settings" or msg == "options" then
        Bimmies_OpenOptions()
    elseif msg == "minimap" then
        local show = not GetSetting("showMinimapButton", true)
        BimmiesDB.settings.showMinimapButton = show
        MinimapButton_Refresh()
        print("[Bimmies] Minimap button " .. (show and "shown" or "hidden"))
    elseif msg == "update" or msg == "refresh" then
        UpdateBagItemOverlays()
        print("[Bimmies] Overlays updated!")
    elseif msg == "clear" then
        BimmiesDB.markedItems = {}
        UpdateBagItemOverlays()
        print("[Bimmies] All marked items cleared!")
    elseif msg == "pp" or msg == "pickpocket" then
        local moneyStr = Bimmies_FormatMoney(BimmiesDB.pickpocketGold)
        print(string.format("[Bimmies] Total pickpocket earnings: %s", moneyStr))
    elseif msg == "ppreset" or msg == "pickpocketreset" then
        BimmiesDB.pickpocketGold = 0
        print("[Bimmies] Pickpocket earnings reset to 0!")
    elseif msg == "hideall" then
        print("[Bimmies] Forcefully hiding all overlays...")
        local count = 0
        Bimmies_ForEachBlizzardBagButton(function(button)
            if button.bimmiesOverlay then
                button.bimmiesOverlay:Hide()
                count = count + 1
            end
        end)
        print(string.format("[Bimmies] Hid %d overlays", count))
    elseif msg == "debug" then
        print("[Bimmies] Scanning for overlays...")
        local count = 0
        Bimmies_ForEachBlizzardBagButton(function(button, bag, slot)
            if button.bimmiesOverlay then
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
        end)
        print(string.format("[Bimmies] Found %d overlays", count))
    elseif msg == "pingdebug" then
        NoPingChatTabs_ToggleDebug()
    elseif msg == "ss" or msg == "shards" or msg == "soulshards" then
        SoulShards_Status()
    elseif msg == "help" then
        print("[Bimmies] Available commands:")
        print("  /bimmies - Delete lowest value grey item")
        print("  /bimmies config - Open settings panel")
        print("  /bimmies minimap - Show/hide the minimap button")
        print("  /bimmies update - Refresh overlay icons")
        print("  /bimmies clear - Clear all marked items")
        print("  /bimmies pp - Show pickpocket earnings")
        print("  /bimmies ppreset - Reset pickpocket earnings")
        print("  /bimmies ss - Show soul shard status")
    else
        -- Default action: delete lowest grey item
        Bimmies_DeleteLowestGreyItem()
    end
end
