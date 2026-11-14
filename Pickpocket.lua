-- Bimmies: Pickpocket Tracking Module
-- Tracks pickpocket earnings for rogues

-- Pickpocket tracking variables (local to this module)
local pickpocketActive = false
local pickpocketStartTime = 0

-- Function to start tracking pickpocket loot
function StartPickpocketTracking()
    -- Check if feature is enabled
    if not GetSetting("enablePickpocketTracker", true) then
        return
    end

    pickpocketActive = true
    pickpocketStartTime = GetTime()
    BimmiesDB.pickpocketItems = {}
end

-- Function to process pickpocket loot
function ProcessPickpocketLoot(itemLink, quantity)
    if not pickpocketActive then return end

    -- Ensure pickpocketGold is initialized
    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold or 0

    -- Get item info
    local itemID = Bimmies_GetItemIDFromLink(itemLink)
    if itemID then
        local itemName, _, itemQuality, _, _, _, _, _, _, _, sellPrice = Bimmies_GetItemInfo(itemID)

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
function ProcessPickpocketMoney(amount)
    if not pickpocketActive then return end

    -- Ensure pickpocketGold is initialized
    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold or 0

    BimmiesDB.pickpocketGold = BimmiesDB.pickpocketGold + amount
end

-- Function to finalize pickpocket tracking and print summary
function FinalizePickpocketTracking()
    if not pickpocketActive then return end

    -- Print a summary if we got anything
    if #BimmiesDB.pickpocketItems > 0 then
        local moneyStr = Bimmies_FormatMoney(BimmiesDB.pickpocketGold)
        print(string.format("[Bimmies] Pickpocket Total: %s", moneyStr))
    end

    pickpocketActive = false
    BimmiesDB.pickpocketItems = {}
end

local PICK_POCKET_SPELL_ID = 921

-- Function to add pickpocket earnings to spell tooltip
-- spellID/spellName may be nil depending on which tooltip API supplied them
local function AddPickpocketTooltip(tooltip, spellID, spellName)
    -- Check if feature is enabled
    if not GetSetting("enablePickpocketTracker", true) then
        return
    end

    -- Modern clients may pass secret values in restricted content; skip those
    if Bimmies_IsSecret(spellID) or Bimmies_IsSecret(spellName) then
        return
    end

    if spellID == PICK_POCKET_SPELL_ID or spellName == "Pick Pocket" then
        local goldAmount = (BimmiesDB and BimmiesDB.pickpocketGold) or 0
        tooltip:AddLine(" ")
        local moneyStr = Bimmies_FormatMoney(goldAmount)
        tooltip:AddLine("|cFF00FF00Total Earned: " .. moneyStr .. "|r", 1, 1, 1)
        tooltip:Show() -- Refresh the tooltip to show our addition
    end
end

-- Hook into spell tooltips
-- Called by Core.lua after all modules are loaded
function Pickpocket_Initialize()
    local ok, hasLegacyScript = pcall(GameTooltip.HasScript, GameTooltip, "OnTooltipSetSpell")
    if ok and hasLegacyScript then
        -- Classic clients
        GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
            local spellName, spellID = tooltip:GetSpell()
            AddPickpocketTooltip(tooltip, spellID, spellName)
        end)
    elseif TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell then
        -- Modern clients (Forever/Retail): OnTooltipSetSpell no longer exists
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            AddPickpocketTooltip(tooltip, data and data.id, nil)
        end)
    end
end
