-- ========================================================
-- MSC - WotLK 3.3.5 Compatible (Final Consolidated Fix)
-- ========================================================

local MSC_VERSION = "0.1.3"
local MSG_PREFIX = "MSC_VER"
local notes
local selectedPlayer = nil
local verCheckActive = false
local verResults = {}
local mini -- Forward declare the minimap button variable

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[MSC]|r " .. tostring(msg))
end

-- --------------------------------------------------------
-- Helper: The "Deep Hide" Visibility Logic
-- --------------------------------------------------------
-- This function must be ABOVE the checkbox and slash commands
local function SetMiniVisibility(show)
    if not mini then return end
    if show then
        mini:SetAlpha(1)
        mini:EnableMouse(true)
    else
        mini:SetAlpha(0)
        mini:EnableMouse(false)
    end
end

-- --------------------------------------------------------
-- Data Tables
-- --------------------------------------------------------
local CLASS_SPECS = {
    ["PALADIN"]     = { "Prot", "Ret", "Holy", "PVP Ret", "PVP Holy" },
    ["WARRIOR"]     = { "Prot", "DPS", "PVP" },
    ["DEATHKNIGHT"] = { "Tank", "DPS", "Unholy", "Frost", "PVP DPS" },
    ["DRUID"]       = { "Feral", "Boomie", "Resto", "PVP Feral", "PVP Boomie", "PVP Resto" },
    ["PRIEST"]      = { "DPS", "Heal", "PVP DPS", "PVP Heal" },
    ["SHAMAN"]      = { "Ele", "Enh", "Resto", "PVP Ele", "PVP Enh", "PVP Resto" },
    ["MAGE"]        = { "DPS", "PVP" },
    ["WARLOCK"]     = { "DPS", "PVP" },
    ["HUNTER"]      = { "DPS", "MM", "Surv", "PVP" },
    ["ROGUE"]       = { "DPS", "Combat", "Assassin", "PVP" },
}

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
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetClampedToScreen(true)
f:Hide()

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if MSCOptions then
        MSCOptions.x = self:GetLeft()
        MSCOptions.y = self:GetBottom()
    end
end)

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(true)
bg:SetTexture(0, 0, 0, 0.8)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("MSC - Main Spec Changes v" .. MSC_VERSION)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

-- --------------------------------------------------------
-- Raid Logic
-- --------------------------------------------------------
local function RefreshRaidList()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid == 0 and numParty == 0 then
        for i = 1, 25 do
            local row = _G["MSCRow"..i]
            if row then row:Hide() end
        end
        return 
    end

    local currentGroup = {}
    if numRaid > 0 then
        for i = 1, 40 do
            local name = UnitName("raid"..i)
            if name then currentGroup[name] = true end
        end
    else
        currentGroup[UnitName("player")] = true
        for i = 1, 4 do
            local name = UnitName("party"..i)
            if name then currentGroup[name] = true end
        end
    end

    if notes then
        for name in pairs(notes) do
            if not currentGroup[name] then notes[name] = nil end
        end
    end

    for i = 1, 25 do
        local row = _G["MSCRow"..i]
        local unitID = nil
        if numRaid > 0 then unitID = "raid"..i
        elseif i <= (numParty + 1) then unitID = (i == 1) and "player" or "party"..(i-1) end

        local name = unitID and UnitName(unitID)
        if row then
            if name and name ~= "" then
                local _, englishClass = UnitClass(unitID)
                local r, g, b = GetClassColor(unitID)
                row.nameText:SetTextColor(r, g, b)
                row.nameText:SetText(name)
                row.specText:SetText((notes and notes[name]) or "--")
                row.unitClass = englishClass
                row:Show()
            else
                row:Hide()
            end
        end
    end
end

f:SetScript("OnShow", RefreshRaidList)

-- --------------------------------------------------------
-- UI Rows & Dropdown
-- --------------------------------------------------------
local MSCDropdown = CreateFrame("Frame", "MSCDropdownMenu", f, "UIDropDownMenuTemplate")

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
    row:Hide()
end

UIDropDownMenu_Initialize(MSCDropdown, function(self, level)
    if not selectedPlayer or not notes then return end
    local pClass = nil
    for i=1, 25 do
        local r = _G["MSCRow"..i]
        if r.nameText:GetText() == selectedPlayer then pClass = r.unitClass break end
    end

    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "|cffff0000Clear Selection|r"
    info.func = function() notes[selectedPlayer] = nil RefreshRaidList() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)

    if pClass and CLASS_SPECS[pClass] then
        for _, spec in ipairs(CLASS_SPECS[pClass]) do
            info.text = spec
            info.func = function() notes[selectedPlayer] = spec RefreshRaidList() CloseDropDownMenus() end
            UIDropDownMenu_AddButton(info)
        end
    end
end)

-- --------------------------------------------------------
-- Bottom Buttons
-- --------------------------------------------------------
StaticPopupDialogs["MSC_CONFIRM_RESET"] = {
    text = "Are you sure you want to clear ALL Main Spec changes?",
    button1 = "Yes", button2 = "No",
    OnAccept = function()
        if notes then for k in pairs(notes) do notes[k] = nil end end
        RefreshRaidList()
        Print("All main spec changes have been cleared.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
resetBtn:SetSize(110, 30)
resetBtn:SetPoint("BOTTOMLEFT", 15, 15)
resetBtn:SetText("Reset All")
resetBtn:SetScript("OnClick", function() StaticPopup_Show("MSC_CONFIRM_RESET") end)

local verBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
verBtn:SetSize(110, 30)
verBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0) 
verBtn:SetText("Version Check")
verBtn:SetScript("OnClick", function()
    if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
        Print("Checking raid versions... (Waiting 2s)")
        verResults = {} 
        verCheckActive = true
        SendAddonMessage(MSG_PREFIX, "QUERY", "RAID")
        local timerFrame = CreateFrame("Frame")
        timerFrame:SetScript("OnUpdate", function(self, elapsed)
            self.time = (self.time or 0) + elapsed
            if self.time >= 2 then
                Print("--- Version Results ---")
                local hasReplies = false
                for name, v in pairs(verResults) do
                    hasReplies = true
                    local color = (v == MSC_VERSION) and "|cff00ff00" or "|cffff0000"
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s%s|r]: %s", color, v, name))
                end
                if not hasReplies then Print("No replies received.") end
                verCheckActive = false
                self:SetScript("OnUpdate", nil)
            end
        end)
    else Print("You must be in a group to check versions.") end
end)

local report = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
report:SetSize(130, 30)
report:SetPoint("BOTTOMRIGHT", -15, 15)
report:SetText("Changes Report")
report:SetScript("OnClick", function()
    if not notes then return end
    local members = {}
    local function IsInGroup(targetName)
        if GetNumRaidMembers() > 0 then
            for i = 1, 40 do if UnitName("raid"..i) == targetName then return true end end
        elseif GetNumPartyMembers() > 0 then
            if UnitName("player") == targetName then return true end
            for i = 1, 4 do if UnitName("party"..i) == targetName then return true end end
        end
        return false
    end
    for name, spec in pairs(notes) do if IsInGroup(name) then table.insert(members, name .. " (" .. spec .. ")") end end
    if #members == 0 then Print("No current group members to report.") return end
    local line = "MS Changes: "
    for i, msg in ipairs(members) do
        line = line .. msg .. (i == #members and "" or " || ")
        if i % 4 == 0 or i == #members then 
            SendChatMessage(line, "RAID_WARNING") 
            line = (i < #members) and "MS Changes (cont): " or ""
        end
    end
end)

-- --------------------------------------------------------
-- Options Window
-- --------------------------------------------------------
local opt = CreateFrame("Frame", "MSCOptionsFrame", UIParent)
opt:SetSize(300, 280)
opt:SetPoint("CENTER")
opt:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
opt:SetBackdropColor(0, 0, 0, 0.9)
opt:SetMovable(true)
opt:EnableMouse(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
opt:Hide()

local optTitle = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optTitle:SetPoint("TOP", 0, -15)
optTitle:SetText("MSC Options & Commands")

local optText = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
optText:SetPoint("TOPLEFT", 20, -45)
optText:SetJustifyH("LEFT")
optText:SetText(
    "Slash Commands:\n\n"..
    "|cff33ccff/msc|r - Display Main Window\n"..
    "|cff33ccff/msc reset|r - Reset Window Position\n"..
    "|cff33ccff/msc show/hide|r - Show/Hide Minimap Icon\n"..
    "|cff33ccff/msc options (or /msc opt)|r - Display This Menu"
)

local hideCheck = CreateFrame("CheckButton", "MSCHideCheck", opt, "InterfaceOptionsCheckButtonTemplate")
hideCheck:SetPoint("TOPLEFT", 15, -160)
_G[hideCheck:GetName().."Text"]:SetText("Show Minimap Icon")
hideCheck:SetScript("OnClick", function(self)
    MSCOptions.showMinimap = self:GetChecked()
    SetMiniVisibility(MSCOptions.showMinimap)
end)

local testBtn = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
testBtn:SetSize(120, 25)
testBtn:SetPoint("BOTTOM", 0, 25)
testBtn:SetText("Test Report")
testBtn:SetScript("OnClick", function()
    Print("Sending test report to Raid Warning...")
    SendChatMessage("MSC Test: System is working correctly.", "RAID_WARNING")
end)

local optClose = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
optClose:SetPoint("TOPRIGHT", -5, -5)

-- --------------------------------------------------------
-- Minimap Button Creation
-- --------------------------------------------------------
local function UpdateMinimapPosition()
    if not MSCOptions or not mini then return end
    local angle = MSCOptions.minimapPos or 45
    mini:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(angle)), (80 * sin(angle)) - 52)
end

local function CreateMinimapButton()
    if mini then return end
    mini = CreateFrame("Button", "MSCMinimapButton", Minimap)
    mini:SetSize(32, 32)
    mini:SetFrameStrata("MEDIUM")
    mini:SetNormalTexture("Interface\\AddOns\\MSC\\MSC_icon")
    mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    mini:RegisterForDrag("LeftButton")

    mini:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local scale = Minimap:GetEffectiveScale()
            local x = xmin - (xpos/scale) + 70
            local y = (ypos/scale) - ymin - 70
            MSCOptions.minimapPos = math.deg(math.atan2(y, x))
            UpdateMinimapPosition()
        end)
    end)
    mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mini:SetScript("OnClick", function(self, button) 
        if button == "RightButton" then f:Hide() 
        elseif button == "MiddleButton" then if opt:IsShown() then opt:Hide() else opt:Show() end
        else if f:IsShown() then f:Hide() else f:Show() end end 
    end)
    mini:SetScript("OnEnter", function(self)
        if self:GetAlpha() == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffffffffMSC - Main Spec Changes|r")
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    UpdateMinimapPosition()
end

-- --------------------------------------------------------
-- Initialization & Events
-- --------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:RegisterEvent("GROUP_ROSTER_UPDATE")
init:RegisterEvent("CHAT_MSG_ADDON")
init:RegisterEvent("PARTY_MEMBERS_CHANGED") 
init:RegisterEvent("RAID_ROSTER_UPDATE")

init:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    
    if (event == "ADDON_LOADED" and arg1 == "MSC") then
        if not MSCOptions then MSCOptions = { showMinimap = true, minimapPos = 45 } end
        if not MSCDB then MSCDB = {} end
        notes = MSCDB 

        if MSCOptions.x and MSCOptions.y then
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", MSCOptions.x, MSCOptions.y)
        else f:SetPoint("CENTER") end

        CreateMinimapButton()

    elseif event == "PLAYER_ENTERING_WORLD" then
        local timer = 0
        self:SetScript("OnUpdate", function(this, elapsed)
            timer = timer + elapsed
            if timer > 1.0 then
                SetMiniVisibility(MSCOptions.showMinimap)
                if MSCHideCheck then MSCHideCheck:SetChecked(MSCOptions.showMinimap) end
                this:SetScript("OnUpdate", nil)
            end
        end)
        Print("MSC Loaded (v" .. MSC_VERSION .. ")")

    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            if MSCDB and next(MSCDB) ~= nil then
                for k in pairs(MSCDB) do MSCDB[k] = nil end
                RefreshRaidList()
                Print("Group disbanded. Data cleared.")
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == MSG_PREFIX then
            if message == "QUERY" then SendAddonMessage(MSG_PREFIX, "REPLY:" .. MSC_VERSION, "RAID")
            elseif message:find("REPLY:") and verCheckActive then verResults[sender] = message:gsub("REPLY:", "") end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if f:IsShown() then RefreshRaidList() end
    end
end)

-- --------------------------------------------------------
-- Slash Commands
-- --------------------------------------------------------
SlashCmdList["MSC"] = function(msg)
    msg = msg:lower()
    if msg == "reset" then
        if MSCOptions then MSCOptions.x, MSCOptions.y = nil, nil end
        f:ClearAllPoints() f:SetPoint("CENTER")
        Print("Window position reset.")
    elseif msg == "show" then
        MSCOptions.showMinimap = true
        SetMiniVisibility(true)
        if MSCHideCheck then MSCHideCheck:SetChecked(true) end
    elseif msg == "hide" then
        MSCOptions.showMinimap = false
        SetMiniVisibility(false)
        if MSCHideCheck then MSCHideCheck:SetChecked(false) end
    elseif msg == "options" or msg == "opt" then
        if opt:IsShown() then opt:Hide() else opt:Show() end
    else
        if f:IsShown() then f:Hide() else f:Show() end
    end
end

SLASH_MSC1 = "/msc"