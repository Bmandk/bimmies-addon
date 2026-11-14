-- Bimmies: Minimap Button Module
-- Draggable button on the minimap edge. Self-contained (no LibDBIcon dependency).
--   Left click:        open settings
--   Shift+Right click: delete lowest-value grey item
--   Drag:              reposition around the minimap

local BUTTON_RADIUS_OFFSET = 5

local button

-- Quadrant lookup for square/rounded minimap shapes (same convention as LibDBIcon)
local quadTable = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(GetSetting("minimapAngle", 220))
    local x, y = math.cos(angle), math.sin(angle)

    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadrants = quadTable[shape] or quadTable["ROUND"]
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local w = (Minimap:GetWidth() / 2) + BUTTON_RADIUS_OFFSET
    local h = (Minimap:GetHeight() / 2) + BUTTON_RADIUS_OFFSET
    if quadrants[q] then
        x, y = x * w, y * h
    else
        local diagW = math.sqrt(2 * w ^ 2) - 10
        local diagH = math.sqrt(2 * h ^ 2) - 10
        x = math.max(-w, math.min(x * diagW, w))
        y = math.max(-h, math.min(y * diagH, h))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    if BimmiesDB and BimmiesDB.settings then
        BimmiesDB.settings.minimapAngle = angle
    end
    UpdatePosition()
end

local function CreateButton()
    button = CreateFrame("Button", "BimmiesMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            Bimmies_OpenOptions()
        elseif mouseButton == "RightButton" and IsShiftKeyDown() then
            Bimmies_DeleteLowestGreyItem()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self.isDragging = nil
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        if self.isDragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Bimmies", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift+Right-click: delete lowest grey item", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move this button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

-- Show or hide according to the showMinimapButton setting
function MinimapButton_Refresh()
    if not button then return end
    if GetSetting("showMinimapButton", true) then
        UpdatePosition()
        button:Show()
    else
        button:Hide()
    end
end

-- Called by Core.lua on PLAYER_LOGIN
function MinimapButton_Initialize()
    if not Minimap then return end
    CreateButton()
    MinimapButton_Refresh()
end
