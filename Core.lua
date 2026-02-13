-- Bimmies: Core Module
-- Event dispatcher and module initialization coordinator
-- This file MUST load last after all other modules

local addonName = "Bimmies"

-- Event handler frame
local coreFrame = CreateFrame("Frame")

-- Register all events (except ADDON_LOADED which is handled by Init.lua)
coreFrame:RegisterEvent("PLAYER_LOGIN")
coreFrame:RegisterEvent("MERCHANT_SHOW")
coreFrame:RegisterEvent("MERCHANT_CLOSED")
coreFrame:RegisterEvent("QUEST_DETAIL")
coreFrame:RegisterEvent("QUEST_PROGRESS")
coreFrame:RegisterEvent("QUEST_COMPLETE")
coreFrame:RegisterEvent("QUEST_FINISHED")
coreFrame:RegisterEvent("BAG_UPDATE_DELAYED")
coreFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
coreFrame:RegisterEvent("CHAT_MSG_LOOT")
coreFrame:RegisterEvent("CHAT_MSG_MONEY")

-- Event dispatcher with clear mapping of events to module functions
coreFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1, arg2, arg3, arg4 = ...

    if event == "PLAYER_LOGIN" then
        -- Initialize modules that need setup
        Options_CreatePanel()
        BagHooks_Initialize()
        Pickpocket_Initialize()

        -- Print welcome message
        print("[Bimmies] Loaded! Set your keybind in ESC > Keybindings > Bimmies, or use /bimmies")
        print("[Bimmies] Type /bimmies config to open settings, or find it in ESC > Interface > AddOns > Bimmies")

    elseif event == "MERCHANT_SHOW" then
        -- Auto-repair, then sell marked items, then sell grey items
        AutoRepairGear()
        SellMarkedItems()
        SellAllGreyItems()

    elseif event == "MERCHANT_CLOSED" then
        -- Update overlays after leaving vendor
        C_Timer.After(0.1, UpdateBagItemOverlays)

    elseif event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
        -- Small delay to ensure quest frame is fully loaded
        C_Timer.After(0.1, HighlightBestReward)

    elseif event == "QUEST_FINISHED" then
        QuestRewards_Clear()

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

        -- Check if this is a player loot message during pickpocketing
        if message then
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

        if message then
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
