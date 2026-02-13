-- Bimmies: Quest Rewards Module
-- Handles highlighting the best quest reward by value

-- Quest reward best value indicator
local rewardIcons = {}

local function ClearRewardIcons()
    for _, icon in pairs(rewardIcons) do
        if icon then
            icon:Hide()
        end
    end
    wipe(rewardIcons)
end

local function CreateRewardIcon(parent)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    return icon
end

function HighlightBestReward()
    ClearRewardIcons()

    -- Check if feature is enabled
    if not GetSetting("enableQuestRewardHighlight", true) then
        return
    end

    -- Get number of quest reward choices
    local numChoices = GetNumQuestChoices()

    if numChoices <= 1 then
        return -- No choices or only one option
    end

    local bestValue = 0
    local bestIndex = nil

    -- Check each reward option for sell price
    for i = 1, numChoices do
        local itemLink = GetQuestItemLink("choice", i)

        if itemLink then
            local itemID = GetItemInfoFromHyperlink(itemLink)
            if itemID then
                local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemID)

                if sellPrice and sellPrice > bestValue then
                    bestValue = sellPrice
                    bestIndex = i
                end
            end
        end
    end

    -- Add gold icon to the best value item
    if bestIndex and bestValue > 0 then
        local rewardButton = _G["QuestInfoRewardsFrameQuestInfoItem" .. bestIndex]

        if not rewardButton then
            -- Try alternate frame name for quest complete
            rewardButton = _G["QuestInfoItem" .. bestIndex]
        end

        if rewardButton then
            local icon = CreateRewardIcon(rewardButton)
            icon:Show()
            table.insert(rewardIcons, icon)
        end
    end
end

-- Export ClearRewardIcons for use by Core.lua
function QuestRewards_Clear()
    ClearRewardIcons()
end
