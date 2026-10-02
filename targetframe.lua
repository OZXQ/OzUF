--[[
    OzUF - Target & Target of Target Frame Module (targetframe.lua)
    Clones features from:
    - unitframes-bighealth-new.lua (Big health bar, normal/rare/elite textures, ToT position)
    - unitframes-classcolor.lua (Target class/reaction color on health bar & name background)
    - unitframes-classportrait.lua (Target and ToT class circular portraits)
    - health-numbers.lua (Target health & mana outline numbers with LibHealth estimation)
    - unitframes-morebuffs.lua (Up to 64 buffs & 128 debuffs with smart adaptive sorting)
]] --

local _G = getfenv(0)

-------------------------------------------------------------------------------
-- Background Texture & Classification Hook
-------------------------------------------------------------------------------
local origTargetFrame_CheckClassification = TargetFrame_CheckClassification
function TargetFrame_CheckClassification()
    local classification = UnitClassification("target")
    if classification == "worldboss" or classification == "elite" then
        TargetFrameTexture:SetTexture(OzUF.TEX_ELITE)
    elseif classification == "rare" then
        TargetFrameTexture:SetTexture(OzUF.TEX_RARE)
    elseif classification == "rareelite" then
        TargetFrameTexture:SetTexture(OzUF.TEX_RARE_ELITE)
    else
        TargetFrameTexture:SetTexture(OzUF.TEX_NORMAL)
    end
    TargetFrameTexture:SetTexCoord(0, 1, 0, 1)
end

local orig_TargetFrameTexture_SetTexture = TargetFrameTexture.SetTexture

TargetFrameTexture.SetTexture = function(self, texPath)
    if texPath and (string.find(texPath, "UI-TargetingFrame_HC", 1, true) or string.find(texPath, "ui-targetingframe_hc", 1, true)) then
        -- Intercept Turtle WoW's HC texture call and redirect it
        orig_TargetFrameTexture_SetTexture(self, OzUF.TEX_NORMAL)
    else
        orig_TargetFrameTexture_SetTexture(self, texPath)
    end
end


-------------------------------------------------------------------------------
-- Class Portrait for Target & Target of Target
-------------------------------------------------------------------------------
local function UpdateTargetPortrait(frame)
    local portrait, unit
    if frame == TargetFrame then
        portrait = TargetPortrait or TargetFramePortrait
        unit = "target"
    elseif frame == TargetofTargetFrame then
        portrait = TargetofTargetPortrait or TargetofTargetFramePortrait
        unit = "targettarget"
    else
        portrait = TargetPortrait or TargetFramePortrait
        unit = "target"
    end

    if not portrait or not unit or not UnitExists(unit) then return end
    local _, class = UnitClass(unit)
    if UnitIsPlayer(unit) and class and OzUF.CLASS_ICON[class] then
        portrait:SetTexture(OzUF.CLASS_ICON[class])
        portrait:SetTexCoord(0, 1, 0, 1)
    else
        portrait:SetTexCoord(0, 1, 0, 1)
        SetPortraitTexture(portrait, unit)
    end
    if frame == TargetFrame or portrait == (TargetPortrait or TargetFramePortrait) then
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -43, -13)
    end
end

local orig_TargetFrame_Update = TargetFrame_Update
TargetFrame_Update = function()
    orig_TargetFrame_Update()
    if UnitExists("target") then
        UpdateTargetPortrait(TargetFrame)
    end
end

local lastToTName = nil
local lastToTIsPlayer = nil
local orig_TargetofTarget_Update = TargetofTarget_Update
if orig_TargetofTarget_Update then
    TargetofTarget_Update = function(elapsed)
        orig_TargetofTarget_Update(elapsed)
        if UnitExists("targettarget") then
            local name = UnitName("targettarget")
            local isPlayer = UnitIsPlayer("targettarget")
            if name ~= lastToTName or isPlayer ~= lastToTIsPlayer then
                lastToTName = name
                lastToTIsPlayer = isPlayer
                UpdateTargetPortrait(TargetofTargetFrame)
            end
        else
            lastToTName = nil
            lastToTIsPlayer = nil
        end
    end
end


-------------------------------------------------------------------------------
-- Big Health Bar Dimensions & Positions
-------------------------------------------------------------------------------
local function SetupTargetLayout()
    TargetFrame:SetWidth(256)
    TargetFrame:SetHeight(128)
    TargetFrame:SetScale(OzUF.GetTargetScale and OzUF.GetTargetScale() or 0.8)
    TargetFrameHealthBar:SetPoint("TOPRIGHT", -108, -24)
    TargetFrameHealthBar:SetHeight(28)
    TargetFrameHealthBar:SetWidth(118)
    TargetFrameManaBar:SetPoint("TOPRIGHT", -108, -55)
    TargetFrameManaBar:SetWidth(118)
    TargetFrameManaBar:SetHeight(11)

    TargetFrameBackground:SetPoint("TOPRIGHT", -103, -22)
    TargetFrameBackground:SetWidth(118)
    TargetFrameBackground:SetHeight(39)

    -- Target of Target repositioning
    TargetofTargetFrame:ClearAllPoints()
    TargetofTargetFrame:SetPoint("BOTTOM", TargetFrame, 30, 10)

    -- Status texts container & strings
    if not TargetFrame.StatusTexts then
        TargetFrame.StatusTexts = CreateFrame("Frame", nil, TargetFrame)
        TargetFrame.StatusTexts:SetAllPoints(TargetFrame)
    end

    -- Name font
    TargetName:ClearAllPoints()
    TargetName:SetPoint("TOP", TargetFrame, "TOP", -40, -28)
    TargetName:SetJustifyH("CENTER")

    -- Lock health bar color to name background color
    if not TargetFrameHealthBar.orig_SetStatusBarColor then
        TargetFrameHealthBar.orig_SetStatusBarColor = TargetFrameHealthBar.SetStatusBarColor
        TargetFrameHealthBar.SetStatusBarColor = function() end
        TargetFrameNameBackground.Show = function() end
        TargetFrameNameBackground:Hide()
    end

    TargetLevelText:ClearAllPoints()
    TargetLevelText:SetPoint("BOTTOMRIGHT", TargetFrame, "BOTTOMRIGHT", -46, 55)
    TargetLevelText:SetJustifyH("CENTER")
    TargetLevelText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")

    TargetHighLevelTexture:SetPoint("BOTTOMRIGHT", TargetFrame, "BOTTOMRIGHT", -46, 55)
    TargetHPPercText:SetPoint("LEFT", TargetFrameTextureFrame, "LEFT", 30, 16)
    TargetHPPercText:SetFontObject(OzUF.status_text_font)

    TargetHPText:SetPoint("RIGHT", -112, 16)
    TargetHPText:SetFontObject(OzUF.status_text_font)
    TargetFrameHealthBar.unit = "target"
    TargetFrameHealthBar.TextString = TargetHPText
    TargetFrameManaBar.unit = "target"

    TargetDeadText:SetPoint("CENTER", TargetFrameTextureFrame, "CENTER", -40, 6)

    TargetFrameBackground:SetPoint("TOPRIGHT", -108, -24)
    TargetFrameBackground:SetWidth(118)
    TargetFrameBackground:SetHeight(38)
end

-------------------------------------------------------------------------------
-- Faction & Class Color Check Hook
-------------------------------------------------------------------------------
local origTargetFrame_CheckFaction = TargetFrame_CheckFaction
function TargetFrame_CheckFaction(self)
    origTargetFrame_CheckFaction(self)

    local reaction = UnitReaction("target", "player")
    if UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        local classColor = RAID_CLASS_COLORS[class] or { r = 0.5, g = 0.5, b = 0.5 }
        TargetFrameNameBackground:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
        TargetFrameNameBackground:Show()
    elseif reaction and reaction > 4 then
        TargetFrameNameBackground:Hide()
    else
        TargetFrameNameBackground:Show()
    end

    if TargetFrameHealthBar.orig_SetStatusBarColor then
        local r, g, b, a = TargetFrameNameBackground:GetVertexColor()
        TargetFrameHealthBar:orig_SetStatusBarColor(r, g, b, a)
    end
end

local function UpdateTargetManaText()
    local bar = TargetFrameManaBar
    if not bar or not bar.TextString then
        local fs = bar:CreateFontString("TargetFrameManaBarText", "OVERLAY")
        fs:SetFontObject(OzUF.status_text_font)
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", TargetFrameManaBar, "RIGHT", -4, 2)
        bar.TextString = fs
    end
    if not UnitExists("target") then
        bar.TextString:SetText("")
        return
    end
    local cur = UnitMana("target")
    local max = UnitManaMax("target")
    if max <= 0 then
        bar.TextString:SetText("")
    else
        bar.TextString:SetText(OzUF.Abbreviate(cur) .. "/" .. OzUF.Abbreviate(max))
    end
end

local orig = UnitFrameManaBar_Update
UnitFrameManaBar_Update = function(bar, unit)
    orig(bar, unit)
    if bar == TargetFrameManaBar and unit == "target" then
        UpdateTargetManaText()
    end
end

local orig_TargetHealthCheck = TargetHealthCheck
TargetHealthCheck = function()
    orig_TargetHealthCheck()
    if not UnitExists("target") then return end
    TextStatusBar_UpdateTextString(TargetFrameHealthBar)
    TargetHPPercText:SetText("")
end
-------------------------------------------------------------------------------
-- More Buffs & Debuffs (unitframes-morebuffs.lua clone)
-------------------------------------------------------------------------------
local TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS = 32
local TARGETFRAMEBUFF_MAX_TARGET_BUFFS = 32

-- Create extra buttons
for i = 6, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
    local button = CreateFrame("Button", "TargetFrameBuff" .. i, TargetFrame, "TargetBuffButtonTemplate")
    button:SetID(i)
    button:SetWidth(21)
    button:SetHeight(21)
end

-- Client XML already defines TargetFrameDebuff1..16, so only 17..N are created
-- here. Creating 6..16 again would replace those globals and orphan the
-- XML-created frames (leaking them as always-present children of TargetFrame).
for i = 17, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
    local button = CreateFrame("Button", "TargetFrameDebuff" .. i, TargetFrame, "TargetDebuffButtonTemplate")
    button:SetID(i)
    button:SetWidth(21)
    button:SetHeight(21)
    local border = _G["TargetFrameDebuff" .. i .. "Border"]
    if border then
        border:SetWidth(21)
        border:SetHeight(21)
    end
end

-- Normalize the client-provided 1..16 to the same 21x21 size as 17..N
for i = 1, 16 do
    local button = _G["TargetFrameDebuff" .. i]
    if button then
        button:SetWidth(21)
        button:SetHeight(21)
    end
    local border = _G["TargetFrameDebuff" .. i .. "Border"]
    if border then
        border:SetWidth(21)
        border:SetHeight(21)
    end
end

local function TargetFrameBuff_Update()
    OzUF.UpdateAuras("target", "TargetFrame", TARGETFRAMEBUFF_MAX_TARGET_BUFFS, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS)
end


-- Hook into TargetDebuffButton_Update to let OzUF handle all buff and debuff layouts
TargetDebuffButton_Update = function()
    TargetFrameBuff_Update()
end


-------------------------------------------------------------------------------
-- Target Event Handling
-------------------------------------------------------------------------------
local targetEventFrame = CreateFrame("Frame")
targetEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
targetEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
targetEventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
targetEventFrame:RegisterEvent("UNIT_AURA")

targetEventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        OzUF.ResetAuraCache("TargetFrame")
        SetupTargetLayout()
        TargetFrame_CheckClassification()
        TargetFrame_CheckFaction(TargetFrame)
        UpdateTargetPortrait(TargetFrame)
        UpdateTargetPortrait(TargetofTargetFrame)
        TargetFrameBuff_Update()
    elseif event == "PLAYER_TARGET_CHANGED" then
        TargetFrame_CheckClassification()
        TargetFrame_CheckFaction(TargetFrame)
        UpdateTargetPortrait(TargetFrame)
        UpdateTargetPortrait(TargetofTargetFrame)
        TargetFrameBuff_Update()
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        if arg1 == "target" then
            UpdateTargetPortrait(TargetFrame)
        elseif arg1 == "targettarget" then
            UpdateTargetPortrait(TargetofTargetFrame)
        end
    elseif event == "UNIT_AURA" and arg1 == "target" then
        TargetFrameBuff_Update()
    end
end)

-- Delayed refresh on login to ensure target frame textures bind cleanly
local targetLoginDelay = CreateFrame("Frame")
targetLoginDelay:Hide()
targetLoginDelay:RegisterEvent("PLAYER_ENTERING_WORLD")
targetLoginDelay:SetScript("OnEvent", function()
    this.timer = 0
    this:Show()
end)
targetLoginDelay:SetScript("OnUpdate", function()
    if not this.timer then return end
    this.timer = this.timer + arg1
    if this.timer >= 0.2 then
        this:Hide()
        this.timer = nil
        if UnitExists("target") then
            TargetFrame_CheckClassification()
            UpdateTargetPortrait(TargetFrame)
        end
    end
end)


-------------------------------------------------------------------------------
-- TargetFrame: Set Focus Option & Alt-Click Shortcut
-------------------------------------------------------------------------------
UnitPopupButtons["SET_FOCUS"] = { text = OzUF.L["SET_FOCUS"] or "Set Focus", dist = 0 }

-- Ensure custom TARGET menu exists for enemy / NPC targets
UnitPopupMenus["TARGET"] = { "SET_FOCUS", "RAID_TARGET_ICON", "CANCEL" }

-- Add SET_FOCUS to SELF, PLAYER, PARTY, RAID popup menus
for _, menu in ipairs({ "SELF", "PLAYER", "PARTY", "RAID" }) do
    if UnitPopupMenus[menu] then
        local found = false
        for _, btn in ipairs(UnitPopupMenus[menu]) do
            if btn == "SET_FOCUS" then
                found = true
                break
            end
        end
        if not found then
            local pos = table.getn(UnitPopupMenus[menu])
            if UnitPopupMenus[menu][pos] == "CANCEL" then
                table.insert(UnitPopupMenus[menu], pos, "SET_FOCUS")
            else
                table.insert(UnitPopupMenus[menu], "SET_FOCUS")
            end
        end
    end
end

-- Custom TargetFrame dropdown initializer supporting all target types (mobs, enemies, self, friends)
local function OzUF_TargetFrameDropDown_Initialize()
    local menu
    if UnitIsUnit("target", "player") then
        menu = "SELF"
    elseif UnitIsUnit("target", "pet") then
        menu = "PET"
    elseif UnitIsEnemy("target", "player") or not UnitIsPlayer("target") then
        menu = "TARGET"
    elseif UnitInParty("target") then
        menu = "PARTY"
    else
        menu = "PLAYER"
    end
    if menu then
        UnitPopup_ShowMenu(TargetFrameDropDown, menu, "target")
    end
end

TargetFrameDropDown_Initialize = OzUF_TargetFrameDropDown_Initialize
if TargetFrameDropDown then
    TargetFrameDropDown.initialize = OzUF_TargetFrameDropDown_Initialize
    UIDropDownMenu_Initialize(TargetFrameDropDown, OzUF_TargetFrameDropDown_Initialize, "MENU")
end
if PlayerFrameDropDown then
    UIDropDownMenu_Initialize(PlayerFrameDropDown, PlayerFrameDropDown_Initialize, "MENU")
end

-- Re-verify dropdown initialization on login
local ddInit = CreateFrame("Frame")
ddInit:RegisterEvent("PLAYER_ENTERING_WORLD")
ddInit:SetScript("OnEvent", function()
    if TargetFrameDropDown then
        TargetFrameDropDown.initialize = OzUF_TargetFrameDropDown_Initialize
        UIDropDownMenu_Initialize(TargetFrameDropDown, OzUF_TargetFrameDropDown_Initialize, "MENU")
    end
    if PlayerFrameDropDown then
        UIDropDownMenu_Initialize(PlayerFrameDropDown, PlayerFrameDropDown_Initialize, "MENU")
    end
end)

-- Handle SET_FOCUS click from UnitPopup
local orig_UnitPopup_OnClick = UnitPopup_OnClick
UnitPopup_OnClick = function(index)
    local dropdownMenu = UIDROPDOWNMENU_INIT_MENU and getglobal(UIDROPDOWNMENU_INIT_MENU)
    local which = dropdownMenu and dropdownMenu.which
    local id = index or (this and this:GetID())
    local button = (this and this.value) or (which and id and UnitPopupMenus[which] and UnitPopupMenus[which][id])
    if button == "SET_FOCUS" then
        local unit = (dropdownMenu and dropdownMenu.unit) or (which == "SELF" and "player") or "target"
        if OzUF.SetFocus then
            OzUF.SetFocus(unit)
        end
        return
    end
    if orig_UnitPopup_OnClick then
        orig_UnitPopup_OnClick(index)
    end
end

-- Alt-LeftClick shortcut on TargetFrame to set focus
local orig_TargetFrame_OnClick = TargetFrame_OnClick
TargetFrame_OnClick = function(button)
    if IsAltKeyDown() and button == "LeftButton" then
        if OzUF.SetFocus then
            OzUF.SetFocus("target")
        end
        return
    end
    if orig_TargetFrame_OnClick then
        orig_TargetFrame_OnClick(button)
    end
end

local orig_TargetFrame_OnMouseUp = TargetFrame_OnMouseUp
TargetFrame_OnMouseUp = function(button)
    if IsAltKeyDown() and button == "LeftButton" then
        if OzUF.SetFocus then
            OzUF.SetFocus("target")
        end
        return
    end
    if orig_TargetFrame_OnMouseUp then
        orig_TargetFrame_OnMouseUp(button)
    end
end
