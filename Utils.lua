-- Bimmies: Utilities Module
-- Shared utility functions used across all modules.
-- Also hosts small API-compatibility shims so the same code runs on both
-- Classic Era/Anniversary (11504) and WoW Forever (16001, modern client).

-- Helper function to safely get setting value with default
function GetSetting(settingName, default)
    if BimmiesDB and BimmiesDB.settings and BimmiesDB.settings[settingName] ~= nil then
        return BimmiesDB.settings[settingName]
    end
    return default == nil and true or default
end

-- Highest equipped bag ID (0 = backpack). Modern clients add a reagent bag (5).
function Bimmies_GetLastBagID()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

-- GetItemInfo moved to C_Item on modern clients; fall back to the global.
function Bimmies_GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end
    return GetItemInfo(item)
end

-- Extract the numeric itemID from an item hyperlink.
function Bimmies_GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    if GetItemInfoFromHyperlink then
        local itemID = GetItemInfoFromHyperlink(itemLink)
        if itemID then return itemID end
    end
    local id = itemLink:match("item:(%d+)")
    return id and tonumber(id) or nil
end

-- Format copper as a coin-texture string.
function Bimmies_FormatMoney(copper)
    copper = copper or 0
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    return tostring(copper) .. "c"
end

-- Modern clients (Forever/Retail) can hand addons "secret" values (e.g. chat
-- text or spell IDs in restricted content). Any string/arithmetic op on them
-- errors, so callers bail out early when this returns true.
function Bimmies_IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

function Bimmies_IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end
