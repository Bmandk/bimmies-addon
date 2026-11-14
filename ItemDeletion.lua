-- Bimmies: Item Deletion Module
-- Handles finding and deleting the lowest value grey item

-- Function to scan bags and find the lowest value grey item stack
local function FindLowestValueGreyItem()
    local lowestValue = nil
    local lowestItemInfo = nil

    -- Iterate through all bags (0-4, where 0 is backpack and 1-4 are bags)
    for bag = 0, Bimmies_GetLastBagID() do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)

            if itemInfo then
                local itemID = itemInfo.itemID
                local stackCount = itemInfo.stackCount

                -- Get item details
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType,
                      itemStackCount, itemEquipLoc, iconFileDataID, sellPrice = Bimmies_GetItemInfo(itemID)

                -- Check if item is grey (poor quality, quality = 0)
                if itemQuality == 0 and sellPrice and sellPrice > 0 then
                    local totalValue = sellPrice * stackCount

                    -- Track the lowest value item
                    if not lowestValue or totalValue < lowestValue then
                        lowestValue = totalValue
                        lowestItemInfo = {
                            bag = bag,
                            slot = slot,
                            itemLink = itemLink,
                            stackCount = stackCount,
                            unitPrice = sellPrice,
                            totalValue = totalValue
                        }
                    end
                end
            end
        end
    end

    return lowestItemInfo
end

-- Main function called by the keybind
-- This must be global for the keybinding system to access it
function Bimmies_DeleteLowestGreyItem()
    local itemInfo = FindLowestValueGreyItem()

    if itemInfo then
        -- Store info before deletion
        local itemLink = itemInfo.itemLink
        local stackCount = itemInfo.stackCount
        local totalValue = itemInfo.totalValue

        -- Delete the item
        C_Container.PickupContainerItem(itemInfo.bag, itemInfo.slot)
        DeleteCursorItem()

        -- Print what was deleted with coin textures
        local moneyStr = Bimmies_FormatMoney(totalValue)
        print(string.format("[Bimmies] Deleted: %s x%d (Total value: %s)",
            itemLink,
            stackCount,
            moneyStr))
    else
        print("[Bimmies] No grey items found in bags.")
    end
end
