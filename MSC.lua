-- ========================================================
-- MSC - WotLK 3.3.5 Compatible
-- Track raid mainspec changes and export
-- ========================================================

MSCDB = MSCDB or {}
MSCOptions = MSCOptions or { showMinimap = true }

local notes = MSCDB
local selectedPlayer = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[MSC]|r " .. tostring(msg))
end

-- *** NEW HELPER FUNCTION ***
local function GetClassColor(unitID)
    local _, englishClass = UnitClass(unitID)
    if englishClass then
        -- GetClassColor is a global table holding color information
        local color = RAID_CLASS_COLORS[englishClass]
        if color then
            -- Return the color in a format usable for SetTextColor: r, g, b
            return color.r, color.g, color.b
        end
    end
    -- Default to white if class/color not found
    return 1.0, 1.0, 1.0 
end

-- --------------------------------------------------------
-- Slash Command
-- --------------------------------------------------------
SLASH_MSC1 = "/msc"
SlashCmdList["MSC"] = function()
    if MSCMainFrame then MSCMainFrame:Show() end
end

-- --------------------------------------------------------
-- Main Frame
-- --------------------------------------------------------
local f = CreateFrame("Frame", "MSCMainFrame", UIParent)
f:SetSize(400, 600)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetTexture(0, 0, 0, 0.7)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("MSC - Main Spec Changes")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

-- --------------------------------------------------------
-- Raid List
-- --------------------------------------------------------
local MAX_ROWS = 25
local raidRows = {}

for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", "MSCRow"..i, f)
    row:SetSize(350, 22)
    row:SetPoint("TOPLEFT", 10, -40 - (i - 1) * 22)

    -- Player Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT")
    row.nameText:SetWidth(150)

    -- Assigned Spec
    row.specText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.specText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
    row.specText:SetWidth(150)
    row.specText:SetTextColor(1, 1, 0)

    row:SetScript("OnClick", function(self)
        local name = self.nameText:GetText()
        if name and name ~= "" then
            selectedPlayer = name
            Print("Selected: " .. name)
            if notes[selectedPlayer] then
                UIDropDownMenu_SetText(MSCDropdown, notes[selectedPlayer])
            else
                UIDropDownMenu_SetText(MSCDropdown, "Select Spec")
            end
        end
    end)

    raidRows[i] = row
end

local function RefreshRaidList()
    local total = GetNumRaidMembers() or 0

    for i = 1, MAX_ROWS do
        local row = raidRows[i]
        local unitID = "raid"..i
        local name = UnitName(unitID) or ""

        if row then
            if name ~= "" then
                -- Get the RGB color values
                local r, g, b = GetClassColor(unitID)

                -- Set the name text color
                row.nameText:SetTextColor(r, g, b)

                -- Set the name text
                row.nameText:SetText(name)
            else
                -- If no raid member, clear name and revert color to white
                row.nameText:SetTextColor(1.0, 1.0, 1.0)
                row.nameText:SetText("")
            end

        row.specText:SetText(notes[name] or "")
        end
    end
end

f:SetScript("OnShow", RefreshRaidList)

-- --------------------------------------------------------
-- Spec Dropdown
-- --------------------------------------------------------
local SPECS = { "PVE Tank", "PVE Heal", "PVE Melee", "PVE Range", "PVP Tank", "PVP Heal", "PVP Melee", "PVP Ranged" }

MSCDropdown = CreateFrame("Frame", "MSCDropdown", f, "UIDropDownMenuTemplate")
local dropdown = MSCDropdown
dropdown:SetPoint("BOTTOMLEFT", 10, 10)
UIDropDownMenu_SetWidth(dropdown, 150)

dropdown:SetScript("OnShow", function(self)
    UIDropDownMenu_Initialize(self, function(self)
        -- Clear option
        local clearInfo = UIDropDownMenu_CreateInfo()
        clearInfo.text = "Clear"
        clearInfo.func = function()
            if selectedPlayer then
                notes[selectedPlayer] = nil
                RefreshRaidList()
                UIDropDownMenu_SetText(MSCDropdown, "Select Spec")
                Print(selectedPlayer .. " cleared.")
            else
                Print("No player selected.")
            end
        end
        UIDropDownMenu_AddButton(clearInfo)

        -- Regular specs
        for _, spec in ipairs(SPECS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spec
            info.value = spec
            info.func = function(self)
                if selectedPlayer then
                    notes[selectedPlayer] = self.value or self.text
                    RefreshRaidList()
                    UIDropDownMenu_SetText(MSCDropdown, notes[selectedPlayer])
                    Print(selectedPlayer .. " - " .. notes[selectedPlayer])
                else
                    Print("No player selected.")
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    if selectedPlayer and notes[selectedPlayer] then
        UIDropDownMenu_SetText(self, notes[selectedPlayer])
    else
        UIDropDownMenu_SetText(self, "Select Spec")
    end
end)

-- --------------------------------------------------------
-- Raid Export Button
-- --------------------------------------------------------
local raidExport = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
raidExport:SetSize(150, 30)
raidExport:SetPoint("BOTTOMRIGHT", -25, 15)
raidExport:SetFrameLevel(f:GetFrameLevel() + 5)
raidExport:SetText("Show MS Changes")
raidExport:SetScript("OnClick", function()
    local members = {}
    for name, spec in pairs(notes) do
        if spec and spec ~= "" then
            table.insert(members, name .. " - " .. spec)
        end
    end

    if #members == 0 then
        Print("No MS Changes to report!")
        return
    end

    local channel = "RAID_WARNING"

    local line = ""
    local count = 0
    for i, entry in ipairs(members) do
        if count > 0 then
            line = line .. " || "
        end
        line = line .. entry
        count = count + 1

        if count == 5 or i == #members then
            SendChatMessage(line, channel)
            line = ""
            count = 0
        end
    end
end)

-- --------------------------------------------------------
-- Minimap Button
-- --------------------------------------------------------
local mini = CreateFrame("Button", "MSCMinimapButton", Minimap)
mini:SetSize(32, 32)
mini:SetNormalTexture("Interface\\AddOns\\MSC\\MSC_icon")
mini:SetPoint("TOPLEFT", -4, 4)
mini:SetScript("OnClick", function()
    f:Show()
end)

-- OnEnter Script (NEW - Show Tooltip)
mini:SetScript("OnEnter", function(self)
    -- 1. Tell GameTooltip what frame it should be attached to
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    
    -- 2. Set the main title text (White/Normal color)
    GameTooltip:SetText("MSC - Main Spec Tracker", 1.0, 0.82, 0.0)
    
    -- 3. Add a line of secondary information (Gray/Light color)
    GameTooltip:AddLine("Click to open the Main Spec Changes window.", 1.0, 1.0, 0.6)
    
    -- 4. Display the tooltip
    GameTooltip:Show()
end)

-- OnLeave Script (NEW - Hide Tooltip)
mini:SetScript("OnLeave", function()
    -- Hide the tooltip immediately when the mouse leaves the button
    GameTooltip:Hide()
end)

local function UpdateMinimap()
    if MSCOptions.showMinimap then
        mini:Show()
    else
        mini:Hide()
    end
end

-- --------------------------------------------------------
-- Options Panel
-- --------------------------------------------------------
local opt = CreateFrame("Frame", "MSCOptionsPanel", InterfaceOptionsFramePanelContainer)
opt.name = "MSC"

local chk = CreateFrame("CheckButton", "MSCOptions_ShowMinimap", opt, "UICheckButtonTemplate")
chk:SetPoint("TOPLEFT", 20, -20)

-- *** CORRECTION HERE ***
-- Use the global table or getglobal to correctly set the text of the checkbox.
_G[chk:GetName() .. "Text"]:SetText("Show Minimap Button") 

chk:SetChecked(MSCOptions.showMinimap)
chk:SetScript("OnClick", function(self)
    MSCOptions.showMinimap = self:GetChecked()
    UpdateMinimap()
end)

InterfaceOptions_AddCategory(opt)

-- --------------------------------------------------------
-- Initialization
-- --------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("GROUP_ROSTER_UPDATE")
init:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        UpdateMinimap()
        Print("MSC loaded. type '/msc' to view the MS changes panel or click the button on the minimap.")
    elseif event == "GROUP_ROSTER_UPDATE" then
        if f:IsShown() then RefreshRaidList() end
    end
end)
