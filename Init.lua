-- Bimmies: Initialization Module
-- This file MUST load first to initialize BimmiesDB before any other module accesses it

local addonName = "Bimmies"

-- Event frame for ADDON_LOADED only
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
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
            enableMarkingOverlay = true,
            enableSoulShardManager = false,
            soulShardThreshold = 8
        }
        -- Backfill new settings for existing users
        if BimmiesDB.settings.enableSoulShardManager == nil then
            BimmiesDB.settings.enableSoulShardManager = false
        end
        if BimmiesDB.settings.soulShardThreshold == nil then
            BimmiesDB.settings.soulShardThreshold = 8
        end

        -- Unregister this frame after initialization is complete
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
