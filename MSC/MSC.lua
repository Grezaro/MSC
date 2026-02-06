-- ========================================================
-- MSC - WotLK 3.3.5 Compatible (Class-Specific Edition)
-- ========================================================

MSCDB = MSCDB or {}
MSCOptions = MSCOptions or { showMinimap = true }

local MSC_VERSION = "0.1.1" -- Update this one line to change it everywhere
local MSG_PREFIX = "MSC_VER"

local notes = MSCDB
local selectedPlayer = nil

-- --------------------------------------------------------
-- Data Tables
-- --------------------------------------------------------
local CLASS_SPECS = {
    ["PALADIN"]     = { "Prot", "Ret", "Holy", "PVP Ret", "PVP Holy" },
    ["WARRIOR"]     = { "Prot", "DPS", "PVP" },
    ["DEATHKNIGHT"] = { "Tank", "DPS", "PVP DPS" },
    ["DRUID"]       = { "Feral", "Boomie", "Resto", "PVP Feral", "PVP Boomie", "PVP Resto" },
    ["PRIEST"]      = { "DPS", "Heal", "PVP DPS", "PVP Heal" },
    ["SHAMAN"]      = { "Ele", "Enh", "Resto", "PVP Ele", "PVP Enh", "PVP Resto" },
    ["MAGE"]        = { "DPS", "PVP" },
    ["WARLOCK"]     = { "DPS", "PVP" },
    ["HUNTER"]      = { "DPS", "PVP" },
    ["ROGUE"]       = { "DPS", "PVP" },
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[MSC]|r " .. tostring(msg))
end

local function GetClassColor(unitID)
    local _, englishClass = UnitClass(unitID)
    if englishClass and RAID_CLASS_COLORS[englishClass] then
        local color = RAID_CLASS_COLORS[englishClass]
        return color.r, color.g, color.b
    end
    return 1.0, 1.0, 1.0 
end

-- --------------------------------------------------------
-- Main Frame Setup
-- --------------------------------------------------------
local f = CreateFrame("Frame", "MSCMainFrame", UIParent)
f:SetSize(400, 640)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetTexture(0, 0, 0, 0.8)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
-- Dynamic Title using the MSC_VERSION variable
title:SetText("MSC - Main Spec Changes v" .. MSC_VERSION)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

-- --------------------------------------------------------
-- Shared Dropdown Logic
-- --------------------------------------------------------
local MSCDropdown = CreateFrame("Frame", "MSCDropdownMenu", f, "UIDropDownMenuTemplate")

local function RefreshRaidList()
    for i = 1, 25 do
        local row = _G["MSCRow"..i]
        local unitID = "raid"..i
        local name = UnitName(unitID)
        
        if row then
            if name and name ~= "" then
                local _, englishClass = UnitClass(unitID)
                local r, g, b = GetClassColor(unitID)
                row.nameText:SetTextColor(r, g, b)
                row.nameText:SetText(name)
                row.specText:SetText(notes[name] or "--")
                row.unitClass = englishClass
                row:Show()
            else
                row.nameText:SetText("")
                row.specText:SetText("")
                row.unitClass = nil
                row:Hide()
            end
        end
    end
end

-- Confirmation Dialog (One consolidated definition)
StaticPopupDialogs["MSC_CONFIRM_RESET"] = {
    text = "Are you sure you want to clear ALL Main Spec changes?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        for k in pairs(notes) do notes[k] = nil end
        
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            Print("|cffff0000You are not in a raid group.|r")
        end

        RefreshRaidList()
        Print("All main spec changes have been cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

UIDropDownMenu_Initialize(MSCDropdown, function(self, level)
    if not selectedPlayer then return end
    
    local pClass = nil
    for i=1, 25 do
        if _G["MSCRow"..i].nameText:GetText() == selectedPlayer then
            pClass = _G["MSCRow"..i].unitClass
            break
        end
    end

    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true

    info.text = "|cffff0000Clear Selection|r"
    info.func = function()
        notes[selectedPlayer] = nil
        RefreshRaidList()
        CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    if pClass and CLASS_SPECS[pClass] then
        for _, spec in ipairs(CLASS_SPECS[pClass]) do
            info.text = spec
            info.func = function()
                notes[selectedPlayer] = spec
                RefreshRaidList()
                Print(selectedPlayer .. " set to " .. spec)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end
end)

-- --------------------------------------------------------
-- Raid Rows (25 Rows)
-- --------------------------------------------------------
local raidRows = {}
for i = 1, 25 do
    local row = CreateFrame("Frame", "MSCRow"..i, f)
    row:SetSize(380, 22)
    row:SetPoint("TOPLEFT", 10, -40 - (i - 1) * 22)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 5, 0)
    row.nameText:SetWidth(120)
    row.nameText:SetJustifyH("LEFT")

    row.specText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.specText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
    row.specText:SetWidth(100)
    row.specText:SetJustifyH("LEFT")

    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(60, 18)
    btn:SetPoint("RIGHT", -5, 0)
    btn:SetText("Set")
    btn:SetScript("OnClick", function(self)
        selectedPlayer = row.nameText:GetText()
        ToggleDropDownMenu(1, nil, MSCDropdown, self, 0, 0)
    end)

    raidRows[i] = row
end

f:SetScript("OnShow", RefreshRaidList)

-- --------------------------------------------------------
-- Bottom Buttons (Report & Reset)
-- --------------------------------------------------------

local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
resetBtn:SetSize(120, 30)
resetBtn:SetPoint("BOTTOMLEFT", 20, 15)
resetBtn:SetText("Reset All")
resetBtn:SetScript("OnClick", function()
    StaticPopup_Show("MSC_CONFIRM_RESET")
end)

local report = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
report:SetSize(140, 30)
report:SetPoint("BOTTOMRIGHT", -20, 15)
report:SetText("Report Changes")
report:SetScript("OnClick", function()
    local members = {}
    for name, spec in pairs(notes) do
        if spec then table.insert(members, name .. " (" .. spec .. ")") end
    end

    if #members == 0 then
        Print("No changes to report.")
        return
    end

    local line = "MSC Updates: "
    for i, msg in ipairs(members) do
        line = line .. msg .. (i == #members and "" or " || ")
        if i % 4 == 0 or i == #members then
            SendChatMessage(line, "RAID_WARNING")
            line = ""
        end
    end
end)

local verBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
verBtn:SetSize(100, 20)
verBtn:SetPoint("BOTTOMLEFT", resetBtn, "TOPLEFT", 0, 5) 
verBtn:SetText("Check Versions")
verBtn:SetScript("OnClick", function()
    if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
        Print("Checking raid versions...")
        SendAddonMessage(MSG_PREFIX, "QUERY", "RAID")
    else
        Print("You must be in a group to check versions.")
    end
end)

-- --------------------------------------------------------
-- Slash Command & Initialization
-- --------------------------------------------------------
SLASH_MSC1 = "/msc"
SlashCmdList["MSC"] = function() f:Show() end

local mini = CreateFrame("Button", "MSCMinimapButton", Minimap)
mini:SetSize(32, 32)
mini:SetNormalTexture("Interface\\AddOns\\MSC\\MSC_icon")
mini:SetPoint("TOPLEFT", -4, 4)
mini:SetScript("OnClick", function() f:Show() end)

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("GROUP_ROSTER_UPDATE")
init:RegisterEvent("CHAT_MSG_ADDON")

init:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        Print("MSC Loaded (v" .. MSC_VERSION .. "). Use /msc")
    elseif event == "CHAT_MSG_ADDON" and prefix == MSG_PREFIX then
        if message == "QUERY" then
            SendAddonMessage(MSG_PREFIX, "REPLY:" .. MSC_VERSION, "RAID")
        elseif message:find("REPLY:") then
            local version = message:gsub("REPLY:", "")
            Print("|cff00ff00" .. sender .. "|r is using MSC v" .. version)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if f:IsShown() then RefreshRaidList() end
    end
end)