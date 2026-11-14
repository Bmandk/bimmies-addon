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
dummy:RegisterForClicks("AnyUp", "AnyDown")

local hovered -- chat tab currently under the cursor, if any
local blocked = false
local hooked = {}
local pressed = false -- a blocked key is currently held (seen via the dummy's click events)
local debugOn = false

local function Debug(...)
    if debugOn then print("[Bimmies ping]", ...) end
end

dummy:SetScript("OnClick", function(_, button, down)
    pressed = down and true or false
    Debug("dummy click", tostring(button), down and "down" or "up")
end)

-- The ping system ignores override bindings, so we also temporarily unbind the
-- real binding (in memory only: SaveBindings is never called) and restore it after.
local savedActions = {}

local function Block()
    if blocked or InCombatLockdown() then return end
    if not GetSetting("enableNoPingChatTabs", true) then return end
    for _, key in ipairs(KEYS) do
        local action = GetBindingAction(key)
        if action and action ~= "" then
            savedActions[key] = action
            SetBinding(key) -- unbind
        end
        SetOverrideBindingClick(owner, true, key, "BimmiesNoPingDummy")
    end
    blocked = true
    pressed = false
end

local function Release()
    ClearOverrideBindings(owner)
    for key, action in pairs(savedActions) do
        SetBinding(key, action)
        savedActions[key] = nil
    end
    blocked = false
end

local unblockAt

local function TryUnblock()
    if not blocked or hovered then unblockAt = nil return end
    if InCombatLockdown() then return end -- cleared on PLAYER_REGEN_DISABLED anyway
    -- Wait until the button is released, so the key-up can't reach Ping.
    -- Trust both our own click tracking and the client's button state.
    if pressed or IsMouseButtonDown("MiddleButton") then
        C_Timer.After(0.05, TryUnblock)
        return
    end
    -- Small grace period after release in case the up-event is still in flight.
    if not unblockAt then
        unblockAt = GetTime() + 0.15
    end
    if GetTime() < unblockAt then
        C_Timer.After(0.05, TryUnblock)
        return
    end
    unblockAt = nil
    Release()
    Debug("unblocked")
end

local function OnEnter(tab)
    hovered = tab
    Block()
    Debug("enter", tab:GetName() or "?", "blocked=" .. tostring(blocked),
        "combat=" .. tostring(InCombatLockdown()),
        "BUTTON3->" .. tostring(GetBindingAction("BUTTON3", true)),
        "(base: " .. tostring(GetBindingAction("BUTTON3")) .. ")")
end

-- /bimmies pingdebug
function NoPingChatTabs_ToggleDebug()
    debugOn = not debugOn
    local n = 0
    for _ in pairs(hooked) do n = n + 1 end
    print("[Bimmies] Ping debug " .. (debugOn and "on" or "off") .. ", hooked tabs: " .. n
        .. ", setting=" .. tostring(GetSetting("enableNoPingChatTabs", true))
        .. ", CHAT_FRAMES=" .. tostring(CHAT_FRAMES and #CHAT_FRAMES))
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
    -- These fire no matter which frame consumes the click (the chat tab eats the
    -- middle-click, so the dummy button never sees it). pcall: not every client has them.
    pcall(owner.RegisterEvent, owner, "GLOBAL_MOUSE_DOWN")
    pcall(owner.RegisterEvent, owner, "GLOBAL_MOUSE_UP")
    owner:SetScript("OnEvent", function(_, event, button)
        if event == "GLOBAL_MOUSE_DOWN" then
            if blocked and button == "MiddleButton" then
                pressed = true
                Debug("global mouse down")
            end
        elseif event == "GLOBAL_MOUSE_UP" then
            if button == "MiddleButton" then
                pressed = false
                Debug("global mouse up")
            end
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Last moment bindings can still be changed: give Ping back for combat.
            if blocked then
                Release()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if hovered then Block() end
        end
    end)
end
