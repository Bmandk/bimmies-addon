-- Bimmies: Soul Shard Manager Module
-- Automatically deletes soul shards when over a configurable threshold.
-- Communicates with an external AutoHotKey script via a signal pixel frame.
-- AHK detects the signal and sends a keypress to trigger the in-game deletion.

local SOUL_SHARD_ID = 6265

-- Signal frame: a small colored pixel at the top-left corner of the screen.
-- Green = "delete a shard", hidden = "no action needed".
local signalFrame = CreateFrame("Frame", "BimmiesSoulShardSignal", UIParent)
signalFrame:SetSize(5, 5)
signalFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
signalFrame:SetFrameStrata("TOOLTIP")
signalFrame:SetFrameLevel(999)

local signalTexture = signalFrame:CreateTexture(nil, "BACKGROUND")
signalTexture:SetAllPoints()
signalTexture:SetColorTexture(0, 1, 0, 1) -- bright green

signalFrame:Hide()

-- Count soul shards in bags
local function CountSoulShards()
    local count = 0
    for bag = 0, Bimmies_GetLastBagID() do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.itemID == SOUL_SHARD_ID then
                count = count + (itemInfo.stackCount or 1)
            end
        end
    end
    return count
end

-- Find the first soul shard slot in bags
local function FindSoulShard()
    for bag = 0, Bimmies_GetLastBagID() do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.itemID == SOUL_SHARD_ID then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- Update the signal pixel based on current shard count vs threshold
function SoulShards_UpdateSignal()
    if not GetSetting("enableSoulShardManager", false) then
        signalFrame:Hide()
        return
    end

    local threshold = GetSetting("soulShardThreshold", 8)
    local count = CountSoulShards()

    if count > threshold then
        signalFrame:Show()
    else
        signalFrame:Hide()
    end
end

-- Delete one soul shard. Called via keybind (requires hardware event).
function Bimmies_DeleteSoulShard()
    if not GetSetting("enableSoulShardManager", false) then
        return
    end

    local threshold = GetSetting("soulShardThreshold", 8)
    local count = CountSoulShards()

    if count <= threshold then
        signalFrame:Hide()
        return
    end

    local bag, slot = FindSoulShard()
    if bag and slot then
        C_Container.PickupContainerItem(bag, slot)
        DeleteCursorItem()
        print(string.format("[Bimmies] Soul Shard deleted (%d/%d remaining)", count - 1, threshold))
    end

    -- Signal will be updated on the next BAG_UPDATE_DELAYED
end

-- Slash command: show shard count
function SoulShards_Status()
    local count = CountSoulShards()
    local threshold = GetSetting("soulShardThreshold", 8)
    local enabled = GetSetting("enableSoulShardManager", false)
    print(string.format("[Bimmies] Soul Shards: %d (threshold: %d, manager: %s, signal: %s)",
        count, threshold, enabled and "ON" or "OFF",
        signalFrame:IsShown() and "ACTIVE" or "idle"))
end
