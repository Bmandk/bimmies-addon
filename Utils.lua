-- Bimmies: Utilities Module
-- Shared utility functions used across all modules

-- Helper function to safely get setting value with default
function GetSetting(settingName, default)
    if BimmiesDB and BimmiesDB.settings and BimmiesDB.settings[settingName] ~= nil then
        return BimmiesDB.settings[settingName]
    end
    return default == nil and true or default
end
