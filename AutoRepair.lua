-- Bimmies: Auto-Repair Module
-- Handles automatic repair at vendors

-- Function to automatically repair gear at vendor
function AutoRepairGear()
    -- Check if feature is enabled
    if not GetSetting("enableAutoRepair", true) then
        return
    end

    -- Check if merchant can repair
    if CanMerchantRepair() then
        local repairCost, canRepair = GetRepairAllCost()

        if canRepair and repairCost > 0 then
            -- Try to repair using guild bank funds first if available
            local useGuildBank = false
            if CanGuildBankRepair() then
                local guildRepairable = GetGuildBankWithdrawMoney()
                if guildRepairable == -1 or guildRepairable >= repairCost then
                    useGuildBank = true
                end
            end

            -- Perform the repair
            RepairAllItems(useGuildBank)

            -- Print repair summary
            local moneyStr = GetCoinTextureString(repairCost)
            if useGuildBank then
                print(string.format("[Bimmies] Auto-repaired all items using guild bank funds: %s", moneyStr))
            else
                print(string.format("[Bimmies] Auto-repaired all items for %s", moneyStr))
            end
        end
    end
end
