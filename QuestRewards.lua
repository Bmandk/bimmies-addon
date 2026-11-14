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

local function GetRewardIcon(parent)
    if not parent.bimmiesRewardIcon then
        local icon = parent:CreateTexture(nil, "OVERLAY")
        icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        parent.bimmiesRewardIcon = icon
    end
    return parent.bimmiesRewardIcon
end

-- Locate the reward choice button for a given index
local function GetRewardButton(index)
    -- Modern clients (Forever/Retail) pool reward buttons; ask QuestInfo for it
    if QuestInfo_GetRewardButton and QuestInfoFrame and QuestInfoFrame.rewardsFrame then
        local button = QuestInfo_GetRewardButton(QuestInfoFrame.rewardsFrame, index)
        if button then return button end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. index] or _G["QuestInfoItem" .. index]
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
            local itemID = Bimmies_GetItemIDFromLink(itemLink)
            if itemID then
                local _, _, _, _, _, _, _, _, _, _, sellPrice = Bimmies_GetItemInfo(itemID)

                if sellPrice and sellPrice > bestValue then
                    bestValue = sellPrice
                    bestIndex = i
                end
            end
        end
    end

    -- Add gold icon to the best value item
    if bestIndex and bestValue > 0 then
        local rewardButton = GetRewardButton(bestIndex)

        if rewardButton then
            local icon = GetRewardIcon(rewardButton)
            icon:Show()
            table.insert(rewardIcons, icon)
        end
    end
end

-- Export ClearRewardIcons for use by Core.lua
function QuestRewards_Clear()
    ClearRewardIcons()
end
