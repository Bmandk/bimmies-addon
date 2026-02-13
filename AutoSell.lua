-- Bimmies: Auto-Sell Module
-- Handles automatic selling of grey items and marked items at vendors

-- Function to sell all grey items to vendor
function SellAllGreyItems()
    -- Check if feature is enabled
    if not GetSetting("enableAutoSellGrey", true) then
        return
    end

    local totalValue = 0
    local itemsSold = 0

    -- Iterate through all bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Get item details
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                      itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = C_Item.GetItemInfo(itemID)

                -- Check if item is grey (poor quality, quality = 0)
                if itemQuality == 0 and sellPrice and sellPrice > 0 then
                    -- Sell the item
                    C_Container.UseContainerItem(bag, slot)
                    totalValue = totalValue + (sellPrice * stackCount)
                    itemsSold = itemsSold + 1
                end
            end
        end
    end

    -- Print summary if items were sold
    if itemsSold > 0 then
        local moneyStr = GetCoinTextureString(totalValue)
        print(string.format("[Bimmies] Auto-sold %d grey item stack(s) for %s", itemsSold, moneyStr))
    end
end

-- Function to sell all marked items at vendor
function SellMarkedItems()
    -- Check if feature is enabled
    if not GetSetting("enableAutoSellMarked", true) then
        return
    end

    local totalValue = 0
    local itemsSold = 0

    -- Iterate through all bags
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Check if item is marked for auto-sell
                if BimmiesDB.markedItems[itemID] then
                    -- Get item details
                    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                          itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = C_Item.GetItemInfo(itemID)

                    if sellPrice and sellPrice > 0 then
                        -- Sell the item
                        C_Container.UseContainerItem(bag, slot)
                        totalValue = totalValue + (sellPrice * stackCount)
                        itemsSold = itemsSold + 1
                    end
                end
            end
        end
    end

    -- Print summary if items were sold
    if itemsSold > 0 then
        local moneyStr = GetCoinTextureString(totalValue)
        print(string.format("[Bimmies] Auto-sold %d marked item stack(s) for %s", itemsSold, moneyStr))
    end
end
