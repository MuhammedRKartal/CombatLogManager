local ADDON_NAME = "CombatLogManager"

local INSTANCE_LIST = {
    "Icecrown Citadel",
    "The Ruby Sanctum",
    "Trial of the Crusader",
    "Vault of Archavon",
    "Naxxramas",
    "Onyxia's Lair",
    "Ulduar",
    "The Obsidian Sanctum",
}

local uiFrame = nil
local checkButtons = {}
local uiTempEnabledInstances = nil
local uiHasPendingChanges = false

local minimapButton = nil
local MINIMAP_BUTTON_SIZE = 32

local StartCombatLog = nil
local StopCombatLog = nil
local ToggleUI = nil

local lastLoggingState = nil
local loggingWatchFrame = nil

local function EnsureDB()
    if CombatLogManagerDB == nil then
        CombatLogManagerDB = {}
    end

    if CombatLogManagerDB.enabledInstances == nil then
        CombatLogManagerDB.enabledInstances = {}
    end

    if CombatLogManagerDB._initialized ~= true then
        CombatLogManagerDB.enabledInstances["Icecrown Citadel"] = true
        CombatLogManagerDB._initialized = true
    end
end

local function EnsureMinimapDB()
    EnsureDB()

    if CombatLogManagerDB.minimap == nil then
        CombatLogManagerDB.minimap = {}
    end

    if CombatLogManagerDB.minimap.angle == nil then
        CombatLogManagerDB.minimap.angle = 225
    end

    if CombatLogManagerDB.minimap.hide == nil then
        CombatLogManagerDB.minimap.hide = false
    end
end

local function SetMinimapButtonPosition()
    if minimapButton == nil then
        return
    end

    EnsureMinimapDB()

    local angle = CombatLogManagerDB.minimap.angle or 225
    local rad = angle * math.pi / 180

    local radius = 80
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function ShowOrHideMinimapButton()
    if minimapButton == nil then
        return
    end

    EnsureMinimapDB()

    if CombatLogManagerDB.minimap.hide == true then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

local function UpdateMinimapIconState()
    if minimapButton == nil or minimapButton.icon == nil then
        return
    end

    if LoggingCombat() then
        minimapButton.icon:SetVertexColor(0, 1, 0)
    else
        minimapButton.icon:SetVertexColor(1, 0.2, 0.2)
    end
end

local function UpdateLoggingStatus()
    if uiFrame == nil or uiFrame.statusText == nil then
        return
    end

    if LoggingCombat() then
        uiFrame.statusText:SetText("|cff00ff00Logging Enabled|r")
    else
        uiFrame.statusText:SetText("|cffff0000Logging Disabled|r")
    end
end

local function SyncLoggingUIIfChanged(force)
    local current = (LoggingCombat() == true)

    if force == true or lastLoggingState == nil or lastLoggingState ~= current then
        lastLoggingState = current

        if uiFrame ~= nil and uiFrame.statusText ~= nil then
            UpdateLoggingStatus()
        end

        if minimapButton ~= nil and minimapButton.icon ~= nil then
            UpdateMinimapIconState()
        end
    end
end

local function EnsureLoggingWatcher()
    if loggingWatchFrame ~= nil then
        return
    end

    loggingWatchFrame = CreateFrame("Frame")
    loggingWatchFrame.elapsed = 0
    loggingWatchFrame:Show()

    loggingWatchFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 2.5 then
            return
        end
        self.elapsed = 0
        SyncLoggingUIIfChanged(false)
    end)
end


local function CreateMinimapButton()
    if minimapButton ~= nil then
        return
    end

    EnsureMinimapDB()

    minimapButton = CreateFrame("Button", "CLM_MinimapButton", Minimap)
    minimapButton:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\CombatLogManager\\media\\logo")
    minimapButton.icon = icon

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if ToggleUI ~= nil then
                ToggleUI()
            end
        else
            if LoggingCombat() then
                if StopCombatLog ~= nil then
                    StopCombatLog()
                end
            else
                if StartCombatLog ~= nil then
                    StartCombatLog()
                end
            end
        end

        SyncLoggingUIIfChanged(true)
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Combat Log Manager", 1, 0.82, 0)
        GameTooltip:AddLine("by HirohitoW", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left Click:", 0, 1, 0)
        GameTooltip:AddLine("  Open / Close UI", 1, 1, 1)
        GameTooltip:AddLine("Right Click:", 0, 1, 0)
        GameTooltip:AddLine("  Toggle Combat Logging", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag:", 0, 1, 0)
        GameTooltip:AddLine("  Move minimap button", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    minimapButton:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)

    minimapButton:SetScript("OnUpdate", function(self)
        if self.isDragging ~= true then
            return
        end

        EnsureMinimapDB()

        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetScale()

        px = px / scale
        py = py / scale

        local dx = px - mx
        local dy = py - my

        local angle = math.deg(math.atan2(dy, dx))
        CombatLogManagerDB.minimap.angle = angle

        SetMinimapButtonPosition()
    end)

    SetMinimapButtonPosition()
    ShowOrHideMinimapButton()
    SyncLoggingUIIfChanged(true)
end

local function LoadTempFromDB()
    EnsureDB()
    uiTempEnabledInstances = {}

    local i = 1
    while i <= #INSTANCE_LIST do
        local instanceName = INSTANCE_LIST[i]
        uiTempEnabledInstances[instanceName] = (CombatLogManagerDB.enabledInstances[instanceName] == true)
        i = i + 1
    end
end

local function ComputeHasPendingChanges()
    EnsureDB()
    if uiTempEnabledInstances == nil then
        return false
    end

    local i = 1
    while i <= #INSTANCE_LIST do
        local instanceName = INSTANCE_LIST[i]
        local dbValue = (CombatLogManagerDB.enabledInstances[instanceName] == true)
        local tempValue = (uiTempEnabledInstances[instanceName] == true)
        if dbValue ~= tempValue then
            return true
        end
        i = i + 1
    end

    return false
end

local function SetButtonEnabled(button, enabled)
    if button == nil then
        return
    end

    if enabled then
        button:Enable()
        local t = button:GetNormalTexture()
        if t ~= nil then
            t:SetDesaturated(false)
        end
    else
        button:Disable()
        local t = button:GetNormalTexture()
        if t ~= nil then
            t:SetDesaturated(true)
        end
    end
end

local function UpdatePendingUI()
    if uiFrame == nil then
        return
    end

    uiHasPendingChanges = ComputeHasPendingChanges()

    if uiFrame.applyButton ~= nil then
        SetButtonEnabled(uiFrame.applyButton, uiHasPendingChanges)
    end
end

StartCombatLog = function()
    if not LoggingCombat() then
        LoggingCombat(true)
        print("Combat being logged to Logs/WoWCombatLog.txt")
    else
        print("Combat log is already active.")
    end

    SyncLoggingUIIfChanged(true)
end

StopCombatLog = function()
    if LoggingCombat() then
        LoggingCombat(false)
        print("Combat log stopped.")
    end

    SyncLoggingUIIfChanged(true)
end

local function IsInSelectedRaid()
    local instanceName = GetInstanceInfo()
    if instanceName == nil then
        return false
    end

    EnsureDB()

    if CombatLogManagerDB.enabledInstances == nil then
        return false
    end

    if CombatLogManagerDB.enabledInstances[instanceName] == true then
        return true
    end

    return false
end

local function CheckAndStartOrStopLogging()
    if IsInRaid() and IsInSelectedRaid() then
        StartCombatLog()
    else
        StopCombatLog()
    end
end

local function UpdateActiveRaidHighlight()
    if uiFrame == nil then
        return
    end

    local currentInstanceName, instanceType = GetInstanceInfo()

    local i = 1
    while i <= #INSTANCE_LIST do
        local instanceName = INSTANCE_LIST[i]
        local cb = checkButtons[instanceName]

        if cb ~= nil and cb.text ~= nil then
            if instanceType == "raid" and currentInstanceName ~= nil and currentInstanceName ~= "" and instanceName == currentInstanceName then
                cb.text:SetText("|cff00ff00--> " .. instanceName .. " <--|r")
            else
                cb.text:SetText(instanceName)
            end
        end

        i = i + 1
    end
end

local function CreateUI()
    if uiFrame ~= nil then
        return
    end

    EnsureDB()
    LoadTempFromDB()

    uiFrame = CreateFrame("Frame", "CLM_MainFrame", UIParent)
    tinsert(UISpecialFrames, "CLM_MainFrame")
    uiFrame:SetSize(360, 380)
    uiFrame:SetPoint("CENTER")
    uiFrame:SetMovable(true)
    uiFrame:EnableMouse(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    uiFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    uiFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    uiFrame:SetBackdropColor(0, 0, 0, 1)

    local title = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Combat Log Manager")

    local subTitle = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subTitle:SetPoint("TOP", 0, -40)
    subTitle:SetText("Select raids to auto-start combat logging")

    local statusText = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOP", 0, -62)
    statusText:SetText("")
    uiFrame.statusText = statusText

    local closeButton = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -6, -6)

    local scrollFrame = CreateFrame("ScrollFrame", "CLM_ScrollFrame", uiFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 18, -74)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 52)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(280)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    local yOffset = -8
    local i = 1

    while i <= #INSTANCE_LIST do
        local instanceName = INSTANCE_LIST[i]

        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, yOffset)
        cb:SetSize(24, 24)

        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        label:SetText(instanceName)

        cb.text = label
        cb:SetChecked(uiTempEnabledInstances ~= nil and uiTempEnabledInstances[instanceName] == true)

        cb:SetScript("OnClick", function(self)
            if uiTempEnabledInstances == nil then
                LoadTempFromDB()
            end

            uiTempEnabledInstances[instanceName] = (self:GetChecked() == 1)
            UpdatePendingUI()
        end)

        checkButtons[instanceName] = cb
        yOffset = yOffset - 26
        i = i + 1
    end

    content:SetHeight((-yOffset) + 20)

    local applyButton = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    applyButton:SetSize(120, 24)
    applyButton:SetPoint("BOTTOMLEFT", 18, 18)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", function()
        EnsureDB()
        if uiTempEnabledInstances == nil then
            LoadTempFromDB()
        end

        local i = 1
        while i <= #INSTANCE_LIST do
            local instanceName = INSTANCE_LIST[i]
            CombatLogManagerDB.enabledInstances[instanceName] = (uiTempEnabledInstances[instanceName] == true)
            i = i + 1
        end

        LoadTempFromDB()
        CheckAndStartOrStopLogging()
        UpdatePendingUI()
    end)

    uiFrame.applyButton = applyButton
    SetButtonEnabled(uiFrame.applyButton, false)

    local infoText = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    infoText:SetPoint("BOTTOMRIGHT", -18, 22)
    infoText:SetText("/clm by HirohitoW")

    uiFrame:Hide()

    CreateMinimapButton()
    SyncLoggingUIIfChanged(true)
end

local function SyncUIFromDB()
    LoadTempFromDB()

    local i = 1
    while i <= #INSTANCE_LIST do
        local instanceName = INSTANCE_LIST[i]
        local cb = checkButtons[instanceName]
        if cb ~= nil then
            cb:SetChecked(uiTempEnabledInstances[instanceName] == true)
        end
        i = i + 1
    end

    UpdateActiveRaidHighlight()
    UpdatePendingUI()
end

local function HookCombatLogSlash()
    if SlashCmdList == nil or SlashCmdList["COMBATLOG"] == nil then
        return
    end

    if CombatLogManagerDB ~= nil and CombatLogManagerDB._clmCombatLogHooked == true then
        return
    end

    local original = SlashCmdList["COMBATLOG"]

    SlashCmdList["COMBATLOG"] = function(msg)
        original(msg)
        SyncLoggingUIIfChanged(true)
    end

    EnsureDB()
    CombatLogManagerDB._clmCombatLogHooked = true
end


ToggleUI = function()
    CreateUI()

    if uiFrame:IsShown() then
        uiFrame:Hide()
    else
        SyncUIFromDB()
        SyncLoggingUIIfChanged(true)
        UpdateActiveRaidHighlight()
        UpdatePendingUI()
        uiFrame:Show()
    end
end

SLASH_CLM1 = "/clm"
SlashCmdList["CLM"] = function()
    if ToggleUI ~= nil then
        ToggleUI()
    end
end

SLASH_CLMMINIMAP1 = "/clmminimap"
SlashCmdList["CLMMINIMAP"] = function()
    EnsureMinimapDB()
    CombatLogManagerDB.minimap.hide = not (CombatLogManagerDB.minimap.hide == true)
    ShowOrHideMinimapButton()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            HookCombatLogSlash()
            EnsureDB()
            CreateUI()
            CreateMinimapButton()
            EnsureLoggingWatcher()
            SyncLoggingUIIfChanged(true)
            UpdateActiveRaidHighlight()
            UpdatePendingUI()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        EnsureDB()
        UpdateActiveRaidHighlight()
        CheckAndStartOrStopLogging()
        SyncLoggingUIIfChanged(true)
    end
end)
