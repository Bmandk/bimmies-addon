-- Bimmies: No Ping On Chat Tabs Module
-- While the cursor is over a chat tab, the middle mouse button is temporarily
-- re-bound to a do-nothing button, so middle-click only closes the tab and
-- does not fire your Ping keybind. Moving off the tab restores your binding.
--
-- Limitation: Blizzard doesn't allow addons to change bindings during combat,
-- so in combat the block is lifted and middle-click behaves as normal.

-- Keys to block while hovering a chat tab. Add e.g. "SHIFT-BUTTON3" if your
-- ping is on a modified middle click.
local KEYS = { "BUTTON3" }

local owner = CreateFrame("Frame")
local dummy = CreateFrame("Button", "BimmiesNoPingDummy", UIParent)
dummy:SetScript("OnClick", function() end)

local hovered -- chat tab currently under the cursor, if any
local blocked = false
local hooked = {}

local function Block()
    if blocked or InCombatLockdown() then return end
    if not GetSetting("enableNoPingChatTabs", true) then return end
    for _, key in ipairs(KEYS) do
        SetOverrideBindingClick(owner, true, key, "BimmiesNoPingDummy")
    end
    blocked = true
end

local function TryUnblock()
    if not blocked or hovered then return end
    if InCombatLockdown() then return end -- cleared on PLAYER_REGEN_DISABLED anyway
    -- Wait until the button is released, so the key-up can't reach Ping.
    if IsMouseButtonDown("MiddleButton") then
        C_Timer.After(0.05, TryUnblock)
        return
    end
    ClearOverrideBindings(owner)
    blocked = false
end

local function OnEnter(tab)
    hovered = tab
    Block()
end

local function OnLeave(tab)
    if hovered == tab then hovered = nil end
    C_Timer.After(0.05, TryUnblock)
end

local function HookTab(tab)
    if not tab or hooked[tab] then return end
    hooked[tab] = true
    tab:HookScript("OnEnter", OnEnter)
    tab:HookScript("OnLeave", OnLeave)
    tab:HookScript("OnHide", OnLeave) -- the tab vanishes when you close it
end

local function HookAllTabs()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        HookTab(_G[name .. "Tab"])
    end
end

-- Called by Core.lua on PLAYER_LOGIN
function NoPingChatTabs_Initialize()
    HookAllTabs()
    -- Whisper/conversation windows create new tabs on the fly.
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", HookAllTabs)
    end

    owner:RegisterEvent("PLAYER_REGEN_DISABLED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Last moment bindings can still be changed: give Ping back for combat.
            if blocked then
                ClearOverrideBindings(owner)
                blocked = false
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if hovered then Block() end
        end
    end)
end
