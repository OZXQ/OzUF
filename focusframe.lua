--[[
    OzUF - Focus Frame & Focus Target Module (focusframe.lua)
    Clones features from TargetFrame (targetframe.lua) line by line:
    - Identical dimensions (256x128, scale 0.8), textures, positions, and offsets
    - TextureFrame layering so frame border & classification sit ABOVE health/mana bars
    - StatusTexts overlay with status_text_font outline numbers
    - Class circular portrait for player units, UnitClassification textures
    - Focus Target positioned at BOTTOM(30, 10) matching TargetofTargetFrame
    - Up to 64 buffs & 128 debuffs with smart adaptive sorting matching TargetFrame
    - Single-option Right-Click dropdown: "Cancel Focus"
    - Shift-drag movable with saved position in OzUF_DB
]] --

local _G = getfenv(0)

OzUF.Focus = {}
local Focus = OzUF.Focus
Focus.unit = nil
Focus.name = nil
Focus.guid = nil
Focus.targetUnit = nil
Focus.targetName = nil
Focus.cache = {}

local POWER_COLORS = {
    [0] = { 0.2, 0.4, 0.9 },
    [1] = { 0.9, 0.2, 0.2 },
    [2] = { 0.9, 0.5, 0.0 },
    [3] = { 0.9, 0.8, 0.1 },
}


-------------------------------------------------------------------------------
-- Focus Unit Resolver (SuperWoW GUID/Marks + Vanilla Scanner + Cache)
-------------------------------------------------------------------------------
local SCAN_UNITS = {
    "target", "mouseover", "targettarget", "pettarget",
    "party1", "party2", "party3", "party4",
    "party1target", "party2target", "party3target", "party4target",
    "player", "pet",
}
for i = 1, 8 do table.insert(SCAN_UNITS, "mark" .. i) end
for i = 1, 40 do
    table.insert(SCAN_UNITS, "raid" .. i)
    table.insert(SCAN_UNITS, "raid" .. i .. "target")
end

local function ResolveFocusUnit()
    if not Focus.name and not Focus.guid then return nil end

    -- 0. Fast-path: check if currently resolved unit is still valid
    if Focus.unit and UnitExists(Focus.unit) then
        if Focus.guid and type(UnitGUID) == "function" then
            if UnitGUID(Focus.unit) == Focus.guid then
                return Focus.unit
            end
        elseif Focus.name and UnitName(Focus.unit) == Focus.name then
            return Focus.unit
        end
    end

    -- 1. Check native "focus" unit token if supported by environment (e.g. ClassicAPI)
    local pcall_ok, exists = pcall(UnitExists, "focus")
    if pcall_ok and exists then
        if Focus.guid and type(UnitGUID) == "function" then
            if UnitGUID("focus") == Focus.guid then
                return "focus"
            end
        elseif Focus.name and UnitName("focus") == Focus.name then
            return "focus"
        end
    end

    -- 2. Fast check SuperWoW raid marker unit if icon was assigned
    if Focus.cache and Focus.cache.raidIcon then
        local markUnit = "mark" .. Focus.cache.raidIcon
        if UnitExists(markUnit) then
            if Focus.guid and type(UnitGUID) == "function" then
                if UnitGUID(markUnit) == Focus.guid then return markUnit end
            elseif Focus.name and UnitName(markUnit) == Focus.name then
                return markUnit
            end
        end
    end

    -- 3. SuperWoW GUID-based scan (exact GUID match)
    if Focus.guid and type(UnitGUID) == "function" then
        for _, u in ipairs(SCAN_UNITS) do
            if UnitExists(u) and UnitGUID(u) == Focus.guid then
                return u
            end
        end
    end

    -- 4. Vanilla unit scan by name
    if Focus.name then
        for _, u in ipairs(SCAN_UNITS) do
            if UnitExists(u) and UnitName(u) == Focus.name then
                return u
            end
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Main Focus Frame Creation (Mirroring TargetFrame)
-------------------------------------------------------------------------------
local f = CreateFrame("Button", "OzUFFocusFrame", UIParent)
f:SetWidth(256)
f:SetHeight(128)
f:SetScale(OzUF.GetFocusScale and OzUF.GetFocusScale() or 0.6)
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -220)
f:SetFrameStrata("LOW")
f:SetToplevel(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
f:RegisterForDrag("LeftButton")
f:Hide()
OzUF.FocusFrame = f
f.unit = "focus"

-- Dragging support
f:SetScript("OnDragStart", function()
    if not f.isLocked or IsShiftKeyDown() then
        this:StartMoving()
    end
end)
f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    OzUF_DB = OzUF_DB or {}
    local point, _, relPoint, x, y = this:GetPoint()
    OzUF_DB["focus_pos"] = { point = point, relPoint = relPoint, x = x, y = y }
end)

-- 1. Base Layer (BACKGROUND): Background texture & Portrait
local bg = f:CreateTexture("OzUFFocusFrameBackground", "BACKGROUND")
bg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -108, -24)
bg:SetWidth(118)
bg:SetHeight(38)
bg:SetTexture(0, 0, 0, 0.5)
f.bg = bg

local portrait = f:CreateTexture("OzUFFocusPortrait", "BACKGROUND")
portrait:SetWidth(64)
portrait:SetHeight(64)
portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -43, -13)
f.portrait = portrait

-- 2. Status Bars (Child frames of f, drawn above BACKGROUND layer)
local hb = CreateFrame("StatusBar", "OzUFFocusFrameHealthBar", f)
hb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -108, -24)
hb:SetWidth(118)
hb:SetHeight(28)
hb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
hb:SetMinMaxValues(0, 100)
hb:SetValue(100)
hb.unit = "focus"
f.healthBar = hb

local mb = CreateFrame("StatusBar", "OzUFFocusFrameManaBar", f)
mb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -108, -55)
mb:SetWidth(118)
mb:SetHeight(11)
mb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
mb:SetMinMaxValues(0, 100)
mb:SetValue(100)
mb.unit = "focus"
f.manaBar = mb

-- 3. TextureFrame (Child frame matching TargetFrameTextureFrame, drawn above StatusBars)
local textureFrame = CreateFrame("Frame", "OzUFFocusFrameTextureFrame", f)
textureFrame:SetAllPoints(f)
f.textureFrame = textureFrame

local frameTexture = textureFrame:CreateTexture("OzUFFocusFrameTexture", "BORDER")
frameTexture:SetPoint("TOPLEFT", textureFrame, "TOPLEFT", 0, 0)
frameTexture:SetWidth(256)
frameTexture:SetHeight(128)
frameTexture:SetTexture(OzUF.TEX_NORMAL)
frameTexture:SetTexCoord(0, 1, 0, 1)
f.texture = frameTexture

local orig_FocusTexture_SetTexture = frameTexture.SetTexture
frameTexture.SetTexture = function(self, texPath)
    if texPath and (string.find(texPath, "UI-TargetingFrame_HC", 1, true) or string.find(texPath, "ui-targetingframe_hc", 1, true)) then
        orig_FocusTexture_SetTexture(self, OzUF.TEX_NORMAL)
    else
        orig_FocusTexture_SetTexture(self, texPath)
    end
end

-- Name (matching TargetName)
local nameText = textureFrame:CreateFontString("OzUFFocusName", "ARTWORK", "GameFontNormalSmall")
nameText:ClearAllPoints()
nameText:SetPoint("TOP", f, "TOP", -40, -28)
nameText:SetJustifyH("CENTER")
f.nameText = nameText

-- Level & High Level Skull (matching TargetLevelText & TargetHighLevelTexture)
local levelText = textureFrame:CreateFontString("OzUFFocusLevelText", "ARTWORK", "GameFontNormalSmall")
levelText:ClearAllPoints()
levelText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -46, 55)
f.levelText = levelText

local highLevelTexture = textureFrame:CreateTexture("OzUFFocusHighLevelTexture", "ARTWORK")
highLevelTexture:SetWidth(16)
highLevelTexture:SetHeight(16)
highLevelTexture:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -46, 55)
highLevelTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
highLevelTexture:Hide()
f.highLevelTexture = highLevelTexture

-- Dead text (matching TargetDeadText)
local deadText = textureFrame:CreateFontString("OzUFFocusDeadText", "ARTWORK", "GameFontNormalSmall")
deadText:SetPoint("CENTER", textureFrame, "CENTER", -40, 6)
deadText:SetText("DEAD")
deadText:Hide()
f.deadText = deadText

-- Icons (Raid mark, Leader, PVP)
local raidIcon = textureFrame:CreateTexture("OzUFFocusRaidTargetIcon", "OVERLAY")
raidIcon:SetWidth(26)
raidIcon:SetHeight(26)
raidIcon:SetPoint("CENTER", f, "TOPRIGHT", -73, -14)
raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
raidIcon:Hide()
f.raidIcon = raidIcon

local leaderIcon = textureFrame:CreateTexture("OzUFFocusLeaderIcon", "ARTWORK")
leaderIcon:SetWidth(16)
leaderIcon:SetHeight(16)
leaderIcon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -10)
leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
leaderIcon:Hide()
f.leaderIcon = leaderIcon

local pvpIcon = textureFrame:CreateTexture("OzUFFocusPVPIcon", "ARTWORK")
pvpIcon:SetWidth(48)
pvpIcon:SetHeight(48)
pvpIcon:SetPoint("TOPRIGHT", f, "TOPRIGHT", 3, -20)
pvpIcon:Hide()
f.pvpIcon = pvpIcon

-- 4. Status Texts Container (matching TargetFrame.StatusTexts)
local statusTexts = CreateFrame("Frame", "OzUFFocusFrameStatusTexts", f)
statusTexts:SetAllPoints(f)
f.StatusTexts = statusTexts

hb.TextString = statusTexts:CreateFontString("OzUFFocusFrameHealthBarText", "OVERLAY")
hb.TextString:SetFontObject(OzUF.status_text_font)
hb.TextString:SetPoint("RIGHT", hb, "RIGHT", -5, -9)
hb.TextString:SetJustifyH("RIGHT")

mb.TextString = statusTexts:CreateFontString("OzUFFocusFrameManaBarText", "OVERLAY")
mb.TextString:SetFontObject(OzUF.status_text_font)
mb.TextString:SetPoint("RIGHT", mb, "RIGHT", -4, 2)
mb.TextString:SetJustifyH("RIGHT")

-------------------------------------------------------------------------------
-- Focus Target (Target of Focus / FocusTarget Frame, matching TargetofTargetFrame)
-------------------------------------------------------------------------------
local ft = CreateFrame("Button", "OzUFFocusTargetFrame", f)
ft:SetWidth(93)
ft:SetHeight(45)
ft:ClearAllPoints()
ft:SetPoint("BOTTOM", f, "BOTTOM", 30, 10)
ft:SetFrameStrata("LOW")
ft:SetToplevel(true)
ft:EnableMouse(true)
ft:RegisterForClicks("LeftButtonUp")
ft:Hide()
f.targetFrame = ft

local ftBg = ft:CreateTexture("OzUFFocusTargetBackground", "BACKGROUND")
ftBg:SetWidth(46)
ftBg:SetHeight(15)
ftBg:SetPoint("BOTTOMLEFT", ft, "BOTTOMLEFT", 42, 13)
ftBg:SetTexture(0, 0, 0, 0.5)

local ftPortrait = ft:CreateTexture("OzUFFocusTargetPortrait", "BORDER")
ftPortrait:SetWidth(35)
ftPortrait:SetHeight(35)
ftPortrait:SetPoint("TOPLEFT", ft, "TOPLEFT", 6, -6)
ft.portrait = ftPortrait
ft.unit = "focustarget"

local ftHb = CreateFrame("StatusBar", "OzUFFocusTargetHealthBar", ft)
ftHb:SetWidth(46)
ftHb:SetHeight(7)
ftHb:SetPoint("TOPRIGHT", ft, "TOPRIGHT", -2, -15)
ftHb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
ftHb:SetMinMaxValues(0, 100)
ftHb:SetValue(100)
ftHb:SetStatusBarColor(0, 1, 0)
ft.healthBar = ftHb

local ftMb = CreateFrame("StatusBar", "OzUFFocusTargetManaBar", ft)
ftMb:SetWidth(46)
ftMb:SetHeight(7)
ftMb:SetPoint("TOPRIGHT", ft, "TOPRIGHT", -2, -23)
ftMb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
ftMb:SetMinMaxValues(0, 100)
ftMb:SetValue(100)
ft.manaBar = ftMb

local ftTextureFrame = CreateFrame("Frame", "OzUFFocusTargetTextureFrame", ft)
ftTextureFrame:SetAllPoints(ft)

local ftTexture = ftTextureFrame:CreateTexture("OzUFFocusTargetTexture", "BORDER")
ftTexture:SetAllPoints(ftTextureFrame)
ftTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetofTargetFrame")
ftTexture:SetTexCoord(0.015625, 0.7265625, 0, 0.703125)

local ftName = ftTextureFrame:CreateFontString("OzUFFocusTargetName", "ARTWORK", "GameFontNormalSmall")
ftName:SetWidth(100)
ftName:SetHeight(10)
ftName:SetPoint("BOTTOMLEFT", ft, "BOTTOMLEFT", 42, 2)
ftName:SetJustifyH("LEFT")
ft.name = ftName

local ftDeadText = ftTextureFrame:CreateFontString("OzUFFocusTargetDeadText", "ARTWORK", "GameFontNormalSmall")
ftDeadText:SetPoint("CENTER", ftTextureFrame, "CENTER", 15, 1)
ftDeadText:SetText("DEAD")
ftDeadText:Hide()
ft.deadText = ftDeadText

ft:SetScript("OnClick", function()
    if Focus.targetUnit and UnitExists(Focus.targetUnit) then
        TargetUnit(Focus.targetUnit)
    elseif Focus.targetName then
        TargetByName(Focus.targetName)
    end
end)

-------------------------------------------------------------------------------
-- Focus Buffs and Debuffs (Matching TargetFrame layout)
-------------------------------------------------------------------------------
local FOCUS_MAX_BUFFS = 32
local FOCUS_MAX_DEBUFFS = 32

for i = 1, FOCUS_MAX_BUFFS do
    local b = CreateFrame("Button", "OzUFFocusFrameBuff" .. i, f)
    b:SetWidth(21)
    b:SetHeight(21)
    b:SetID(i)
    local icon = b:CreateTexture("OzUFFocusFrameBuff" .. i .. "Icon", "ARTWORK")
    icon:SetAllPoints(b)
    b:SetScript("OnEnter", function()
        local u = Focus.unit or ResolveFocusUnit()
        if u and UnitExists(u) then
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 15, -25)
            GameTooltip:SetUnitBuff(u, this:GetID())
        end
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    b:Hide()
end

for i = 1, FOCUS_MAX_DEBUFFS do
    local b = CreateFrame("Button", "OzUFFocusFrameDebuff" .. i, f)
    b:SetWidth(21)
    b:SetHeight(21)
    b:SetID(i)
    local icon = b:CreateTexture("OzUFFocusFrameDebuff" .. i .. "Icon", "ARTWORK")
    icon:SetAllPoints(b)
    local border = b:CreateTexture("OzUFFocusFrameDebuff" .. i .. "Border", "OVERLAY")
    border:SetWidth(21)
    border:SetHeight(21)
    border:SetPoint("CENTER", b, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    local count = b:CreateFontString("OzUFFocusFrameDebuff" .. i .. "Count", "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 0)
    b:SetScript("OnEnter", function()
        local u = Focus.unit or ResolveFocusUnit()
        if u and UnitExists(u) then
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 15, -25)
            GameTooltip:SetUnitDebuff(u, this:GetID())
        end
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    b:Hide()
end

-- Last rendered counts, used to skip the expensive re-anchor sweep
local focusAuraState = { nb = -1, nd = -1, friend = nil }

local function RenderFocusAuras()
    -- Focus unit not resolvable: Focus.cache holds stale data, and re-rendering
    -- it several times a second is pure waste. Freeze the last state instead.
    if not Focus.unit or not UnitExists(Focus.unit) then return end

    local cache = Focus.cache
    local buffs = cache.buffs or {}
    local debuffs = cache.debuffs or {}

    local num_buff = table.getn(buffs)
    local num_debuff = table.getn(debuffs)

    local buffKey = "OzUFFocusFrameBuff"
    local debuffKey = "OzUFFocusFrameDebuff"
    local buffArr = OzUF.GetAuraGroup(buffKey, FOCUS_MAX_BUFFS, false)
    local debArr = OzUF.GetAuraGroup(debuffKey, FOCUS_MAX_DEBUFFS, true)

    -- Icons / counts / borders for the slots actually in use
    for i = 1, num_buff do
        local e = buffArr[i]
        if e then
            if e.icon and e.icon:GetTexture() ~= buffs[i] then
                e.icon:SetTexture(buffs[i])
            end
            -- Client / focus tooltip scripts read this.id
            if e.button then e.button.id = i end
        end
    end

    for i = 1, num_debuff do
        local item = debuffs[i]
        local e = debArr[i]
        if e then
            if e.icon and e.icon:GetTexture() ~= item.texture then
                e.icon:SetTexture(item.texture)
            end
            if e.count then
                if item.count and item.count > 1 then
                    e.count:SetText(item.count)
                    e.count:Show()
                else
                    e.count:Hide()
                end
            end
            if e.border and DebuffTypeColor then
                local color = DebuffTypeColor[item.debuffType or "none"] or DebuffTypeColor["none"]
                e.border:SetVertexColor(color.r, color.g, color.b)
            end
            if e.button then e.button.id = i end
        end
    end

    -- Hide only the tail that shrank (full sweep on the very first call only)
    local hideFromBuff = (focusAuraState.nb < 0) and 1 or (num_buff + 1)
    local hideToBuff = (focusAuraState.nb < 0) and FOCUS_MAX_BUFFS or focusAuraState.nb
    for i = hideFromBuff, hideToBuff do
        local b = buffArr[i].button
        if b then
            b:ClearAllPoints()
            b:Hide()
        end
    end

    local hideFromDebuff = (focusAuraState.nd < 0) and 1 or (num_debuff + 1)
    local hideToDebuff = (focusAuraState.nd < 0) and FOCUS_MAX_DEBUFFS or focusAuraState.nd
    for i = hideFromDebuff, hideToDebuff do
        local b = debArr[i].button
        if b then
            b:ClearAllPoints()
            b:Hide()
        end
    end

    local isFriend = false
    if UnitIsFriend("player", Focus.unit) then
        isFriend = true
    elseif cache.canAttack == nil or cache.canAttack == false then
        isFriend = true
    end

    -- Dirty check: re-anchoring is the expensive part, skip when nothing changed
    if num_buff == focusAuraState.nb and num_debuff == focusAuraState.nd and isFriend == focusAuraState.friend then
        return
    end
    focusAuraState.nb, focusAuraState.nd, focusAuraState.friend = num_buff, num_debuff, isFriend

    -- ArrangeButtonGroup already performs ClearAllPoints + Show per button, so an
    -- extra preparatory pass here would redo the exact same work a second time.

    if isFriend then
        local lastBuffRowStart = OzUF.ArrangeButtonGroup(buffKey, num_buff, "OzUFFocusFrame", true, 8, 8, 8, 8, 8)
        if num_debuff > 0 then
            OzUF.ArrangeButtonGroup(debuffKey, num_debuff, lastBuffRowStart or "OzUFFocusFrame",
                lastBuffRowStart == nil, 12, 12, 12, 12, 8)
        end
    else
        local lastDebuffRowStart = OzUF.ArrangeButtonGroup(debuffKey, num_debuff, "OzUFFocusFrame", true, 4, 4, 4, 12, 8)
        if num_buff > 0 then
            OzUF.ArrangeButtonGroup(buffKey, num_buff, lastDebuffRowStart or "OzUFFocusFrame",
                lastDebuffRowStart == nil, 8, 8, 8, 8, 8)
        end
    end
end

-------------------------------------------------------------------------------
-- Click Handlers & Dropdown Menu (Single option: "Cancel Focus")
-------------------------------------------------------------------------------
local focusDropDown = CreateFrame("Frame", "OzUFFocusFrameDropDown", UIParent, "UIDropDownMenuTemplate")
focusDropDown:SetID(1)
focusDropDown:Hide()

UIDropDownMenu_Initialize(focusDropDown, function()
    local info = {}
    info.text = OzUF.L["CANCEL_FOCUS"]
    info.func = function()
        CloseDropDownMenus()
        Focus.pendingClear = true
    end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)

    local lockInfo = {}
    lockInfo.text = f.isLocked and OzUF.L["UNLOCK_FOCUS"] or OzUF.L["LOCK_FOCUS"]
    lockInfo.func = function()
        f.isLocked = not f.isLocked
        OzUF_DB = OzUF_DB or {}
        OzUF_DB["focus_locked"] = f.isLocked
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " ..
            (f.isLocked and OzUF.L["FOCUS_LOCKED"] or OzUF.L["FOCUS_UNLOCKED"]))
    end
    lockInfo.notCheckable = 1
    UIDropDownMenu_AddButton(lockInfo)
end, "MENU")

f:SetScript("OnClick", function()
    local unit = Focus.unit or ResolveFocusUnit()
    if arg1 == "LeftButton" then
        if unit and UnitExists(unit) then
            TargetUnit(unit)
        elseif Focus.guid and type(TargetByGUID) == "function" then
            TargetByGUID(Focus.guid)
        elseif Focus.name then
            TargetByName(Focus.name)
        end
    elseif arg1 == "RightButton" then
        if IsAltKeyDown() then
            Focus.pendingClear = true
            return
        end
        ToggleDropDownMenu(1, nil, focusDropDown, "cursor", 0, 0)
    end
end)

-------------------------------------------------------------------------------
-- Update & Cache Functions
-------------------------------------------------------------------------------
function Focus:GetHealth()
    local unit = ResolveFocusUnit()
    if unit and UnitExists(unit) then
        if UnitIsPlayer(unit) then
            return UnitHealth(unit) or 0, UnitHealthMax(unit) or 0, true
        else
            return OzUF.libhealth:GetUnitHealth(unit)
        end
    end
    if Focus.cache and Focus.cache.curHp and Focus.cache.maxHp then
        return Focus.cache.curHp, Focus.cache.maxHp, true
    end
    return 100, 100, true
end

local cache_unit = nil      -- unit token the identity fields were resolved for
local cache_full_time = 0   -- GetTime() of the last full identity refresh

local function UpdateFocusCache(unit)
    if not unit or not UnitExists(unit) then return end

    local cache = Focus.cache
    cache.name = UnitName(unit) or Focus.name
    Focus.name = cache.name

    if type(UnitGUID) == "function" then
        Focus.guid = UnitGUID(unit)
    end

    -- Identity fields only change when the focus target itself changes. Resolving
    -- them on every poll tick burned ~12 unit API calls per tick for nothing.
    local now = GetTime()
    local full_refresh = (unit ~= cache_unit) or (now - cache_full_time >= 2.0)
    if full_refresh then
        cache_unit = unit
        cache_full_time = now

        cache.level = UnitLevel(unit)
        cache.isCorpse = UnitIsCorpse(unit)
        cache.canAttack = UnitCanAttack("player", unit)
        cache.classification = UnitClassification(unit) or "normal"

        cache.isPlayer = UnitIsPlayer(unit)
        cache.reactionColor = cache.reactionColor or { r = 1, g = 1, b = 1 }
        if cache.isPlayer then
            local _, class = UnitClass(unit)
            cache.class = class
            local c = RAID_CLASS_COLORS[class] or { r = 0.5, g = 0.5, b = 0.5 }
            cache.reactionColor.r = c.r
            cache.reactionColor.g = c.g
            cache.reactionColor.b = c.b
        else
            cache.class = nil
            local r, g, b = OzUF.GetUnitReactionColor(unit)
            cache.reactionColor.r = r
            cache.reactionColor.g = g
            cache.reactionColor.b = b
        end

        if cache.isPlayer and cache.class and OzUF.CLASS_ICON[cache.class] then
            portrait:SetTexture(OzUF.CLASS_ICON[cache.class])
            portrait:SetTexCoord(0, 1, 0, 1)
        else
            portrait:SetTexCoord(0, 1, 0, 1)
            SetPortraitTexture(portrait, unit)
        end

        cache.leader = UnitIsPartyLeader(unit)
        local factionGroup = UnitFactionGroup(unit)
        if UnitIsPVPFreeForAll(unit) then
            cache.pvp = "FFA"
        elseif factionGroup and UnitIsPVP(unit) then
            cache.pvp = factionGroup
        else
            cache.pvp = nil
        end
    end

    -- Volatile fields: refreshed on every tick
    local curHp, maxHp
    if cache.isPlayer then
        curHp = UnitHealth(unit) or 0
        maxHp = UnitHealthMax(unit) or 0
    else
        curHp, maxHp = OzUF.libhealth:GetUnitHealth(unit)
        curHp = curHp or 100
        maxHp = maxHp or 100
    end
    cache.curHp = curHp
    cache.maxHp = maxHp

    cache.curMp = UnitMana(unit) or 0
    cache.maxMp = UnitManaMax(unit) or 0
    cache.powerType = UnitPowerType(unit) or 0

    cache.isDead = (UnitIsDead(unit) or UnitIsGhost(unit)) and true or false
    cache.raidIcon = GetRaidTargetIndex(unit)

    cache.buffs = cache.buffs or {}
    local numBuffs = 0
    for i = 1, FOCUS_MAX_BUFFS do
        local buff = UnitBuff(unit, i)
        if buff then
            numBuffs = i
            cache.buffs[i] = buff
        else
            break
        end
    end
    for i = numBuffs + 1, table.getn(cache.buffs) do
        cache.buffs[i] = nil
    end

    cache.debuffs = cache.debuffs or {}
    local numDebuffs = 0
    for i = 1, FOCUS_MAX_DEBUFFS do
        local debuff, debuffApps, debuffType = UnitDebuff(unit, i)
        if debuff then
            numDebuffs = i
            local entry = cache.debuffs[i] or {}
            entry.texture = debuff
            entry.count = debuffApps
            entry.debuffType = debuffType or "none"
            cache.debuffs[i] = entry
        else
            break
        end
    end
    for i = numDebuffs + 1, table.getn(cache.debuffs) do
        cache.debuffs[i] = nil
    end
end


local function UpdateFocusTarget(unit)
    if not unit or not UnitExists(unit) then
        ft:Hide()
        Focus.targetUnit = nil
        Focus.targetName = nil
        return
    end

    local tot
    if unit == "focus" then
        tot = "focustarget"
    elseif unit == "player" then
        tot = "target"
    else
        tot = unit .. "target"
    end
    if UnitExists(tot) then
        Focus.targetUnit = tot
        Focus.targetName = UnitName(tot)

        ftName:SetText(Focus.targetName)

        local curHp = UnitHealth(tot)
        local maxHp = UnitHealthMax(tot)
        ftHb:SetMinMaxValues(0, maxHp)
        ftHb:SetValue(curHp)

        local curMp = UnitMana(tot)
        local maxMp = UnitManaMax(tot)
        ftMb:SetMinMaxValues(0, maxMp)
        ftMb:SetValue(curMp)

        local pc = POWER_COLORS[UnitPowerType(tot)] or POWER_COLORS[0]
        ftMb:SetStatusBarColor(pc[1], pc[2], pc[3])


        if UnitIsDead(tot) or UnitIsGhost(tot) then
            ftDeadText:Show()
        else
            ftDeadText:Hide()
        end

        if UnitIsPlayer(tot) then
            local _, class = UnitClass(tot)
            local c = RAID_CLASS_COLORS[class] or { r = 0.5, g = 0.5, b = 0.5 }
            ftName:SetTextColor(c.r, c.g, c.b, 1)
            if class and OzUF.CLASS_ICON[class] then
                ftPortrait:SetTexture(OzUF.CLASS_ICON[class])
                ftPortrait:SetTexCoord(0, 1, 0, 1)
            else
                ftPortrait:SetTexCoord(0, 1, 0, 1)
                SetPortraitTexture(ftPortrait, tot)
            end
        else
            local r, g, b = OzUF.GetUnitReactionColor(tot)
            ftName:SetTextColor(r, g, b, 1)
            ftPortrait:SetTexCoord(0, 1, 0, 1)
            SetPortraitTexture(ftPortrait, tot)
        end

        ft:Show()
    else
        ft:Hide()
        Focus.targetUnit = nil
        Focus.targetName = nil
    end
end

local function UpdateFocusFrame()
    if not Focus.name then
        f:Hide()
        ft:Hide()
        return
    end

    local unit = ResolveFocusUnit()
    Focus.unit = unit

    -- ResolveFocusUnit already verifies UnitExists on every return path
    if unit then
        UpdateFocusCache(unit)
        UpdateFocusTarget(unit)
    else
        ft:Hide()
        Focus.targetUnit = nil
        Focus.targetName = nil
    end

    local cache = Focus.cache
    f:Show()
    nameText:SetText(cache.name or Focus.name)

    -- Classification Border Texture
    local classification = cache.classification or "normal"
    if classification == "worldboss" or classification == "elite" then
        frameTexture:SetTexture(OzUF.TEX_ELITE)
    elseif classification == "rare" then
        frameTexture:SetTexture(OzUF.TEX_RARE)
    elseif classification == "rareelite" then
        frameTexture:SetTexture(OzUF.TEX_RARE_ELITE)
    else
        frameTexture:SetTexture(OzUF.TEX_NORMAL)
    end
    frameTexture:SetTexCoord(0, 1, 0, 1)

    -- Health Bar Color
    if cache.reactionColor then
        hb:SetStatusBarColor(cache.reactionColor.r, cache.reactionColor.g, cache.reactionColor.b)
    end

    -- Health & Mana Bars
    local curHp = cache.curHp or 100
    local maxHp = cache.maxHp or 100
    hb:SetMinMaxValues(0, maxHp)
    hb:SetValue(curHp)

    local curMp = cache.curMp or 0
    local maxMp = cache.maxMp or 0
    mb:SetMinMaxValues(0, maxMp)
    mb:SetValue(curMp)

        local pc = POWER_COLORS[cache.powerType or 0] or POWER_COLORS[0]
        mb:SetStatusBarColor(pc[1], pc[2], pc[3])


    -- Dead Text & Numbers
    if cache.isDead then
        deadText:Show()
        hb.TextString:Hide()
        mb.TextString:Hide()
    else
        deadText:Hide()
        if maxHp > 0 then
            hb.TextString:SetText(OzUF.Abbreviate(curHp) .. "/" .. OzUF.Abbreviate(maxHp))
            hb.TextString:Show()
        else
            hb.TextString:Hide()
        end
        if maxMp > 0 then
            mb.TextString:SetText(OzUF.Abbreviate(curMp) .. "/" .. OzUF.Abbreviate(maxMp))
            mb.TextString:Show()
        else
            mb.TextString:Hide()
        end
    end

    -- Level & High Level Skull
    local level = cache.level
    if cache.isCorpse then
        levelText:Hide()
        highLevelTexture:Show()
    elseif level and level > 0 then
        levelText:SetText(level)
        if cache.canAttack then
            local color = GetDifficultyColor(level)
            levelText:SetVertexColor(color.r, color.g, color.b)
        else
            levelText:SetVertexColor(1.0, 0.82, 0.0)
        end
        levelText:Show()
        highLevelTexture:Hide()
    else
        levelText:Hide()
        highLevelTexture:Show()
    end

    -- Icons
    if cache.raidIcon then
        SetRaidTargetIconTexture(raidIcon, cache.raidIcon)
        raidIcon:Show()
    else
        raidIcon:Hide()
    end

    if cache.leader then
        leaderIcon:Show()
    else
        leaderIcon:Hide()
    end

    if cache.pvp == "FFA" then
        pvpIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
        pvpIcon:Show()
    elseif cache.pvp then
        pvpIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. cache.pvp)
        pvpIcon:Show()
    else
        pvpIcon:Hide()
    end

    -- Auras
    RenderFocusAuras()
end

Focus.Update = UpdateFocusFrame

-------------------------------------------------------------------------------
-- Focus Control Functions & Slash Commands
-------------------------------------------------------------------------------
function OzUF.SetFocus(unit)
    unit = unit or "target"
    if UnitExists(unit) then
        Focus.name = UnitName(unit)
        Focus.unit = unit
        if type(UnitGUID) == "function" then
            Focus.guid = UnitGUID(unit)
        else
            Focus.guid = nil
        end

        focusAuraState.nb, focusAuraState.nd, focusAuraState.friend = -1, -1, nil
        cache_unit = nil
        UpdateFocusCache(unit)

        f:Show()
        if UnitIsEnemy(unit, "player") then
            PlaySound("igCreatureAggroSelect")
        elseif UnitIsFriend("player", unit) then
            PlaySound("igCharacterNPCSelect")
        else
            PlaySound("igCreatureNeutralSelect")
        end
        UpdateFocusFrame()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. OzUF.L["FOCUS_SET"] .. (Focus.name or ""))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. OzUF.L["NO_TARGET_FOCUS"])
    end
end

function OzUF.ClearFocus()
    Focus.name = nil
    Focus.unit = nil
    Focus.guid = nil
    Focus.cache = {}
    Focus.pendingClear = nil
    focusAuraState.nb, focusAuraState.nd, focusAuraState.friend = -1, -1, nil
    cache_unit = nil

    if UIDROPDOWNMENU_OPEN_MENU == focusDropDown then
        CloseDropDownMenus()
    end

    f:Hide()
    ft:Hide()
    PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
end

SLASH_OZUFFOCUS1 = "/focus"
SlashCmdList["OZUFFOCUS"] = function(msg)
    msg = msg or ""
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    if msg == "lock" or msg == "LOCK" then
        f.isLocked = true
        OzUF_DB = OzUF_DB or {}
        OzUF_DB["focus_locked"] = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. OzUF.L["FOCUS_LOCKED"])
    elseif msg == "unlock" or msg == "UNLOCK" then
        f.isLocked = false
        OzUF_DB = OzUF_DB or {}
        OzUF_DB["focus_locked"] = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. OzUF.L["FOCUS_UNLOCKED"])
    elseif msg == "clear" or msg == "CLEAR" then
        OzUF.ClearFocus()
    else
        OzUF.SetFocus("target")
    end
end

SLASH_OZUCLEARFOCUS1 = "/clearfocus"
SlashCmdList["OZUCLEARFOCUS"] = function()
    OzUF.ClearFocus()
end

-------------------------------------------------------------------------------
-- Periodic and Event Updating (Throttled & Unit-Filtered)
-------------------------------------------------------------------------------
local lastFocusUpdate = 0
local focusUpdateScheduled = false

local function RequestFocusUpdate(force)
    if not Focus.name then return end
    local now = GetTime()
    if force or (now - lastFocusUpdate >= 0.1) then
        UpdateFocusFrame()
        lastFocusUpdate = now
        focusUpdateScheduled = false
    else
        focusUpdateScheduled = true
    end
end

f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MANA")
f:RegisterEvent("UNIT_PORTRAIT_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PARTY_LEADER_CHANGED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
f:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")

f:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        OzUF.ResetAuraCache("OzUFFocusFrame")
        focusAuraState.nb, focusAuraState.nd, focusAuraState.friend = -1, -1, nil
        cache_unit = nil
        if OzUF_DB then
            if OzUF_DB["focus_pos"] then
                local pos = OzUF_DB["focus_pos"]
                f:ClearAllPoints()
                f:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT", pos.x or 250, pos.y or -220)
            end
            if OzUF_DB["focus_locked"] ~= nil then
                f.isLocked = OzUF_DB["focus_locked"]
            end
        end
        if Focus.name then
            RequestFocusUpdate(true)
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        RequestFocusUpdate(true)
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" or event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
        if Focus.name and arg1 and string.find(arg1, Focus.name, 1, true) then
            if Focus.cache then
                Focus.cache.isDead = true
                Focus.cache.curHp = 0
            end
            RequestFocusUpdate(true)
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_AURA" or event == "UNIT_PORTRAIT_UPDATE" then
        if arg1 and Focus.unit and (arg1 == Focus.unit or arg1 == Focus.targetUnit) then
            RequestFocusUpdate(false)
        end
    end
end)

-- Polling scanner for vanilla unit updates and focus target tracking
local focusTimer = 0
f:SetScript("OnUpdate", function()
    if Focus.pendingClear then
        Focus.pendingClear = nil
        OzUF.ClearFocus()
        return
    end

    if not Focus.name or not f:IsShown() then return end

    focusTimer = focusTimer + arg1
    if focusTimer >= 0.5 or (focusUpdateScheduled and (GetTime() - lastFocusUpdate >= 0.1)) then
        focusTimer = 0
        UpdateFocusFrame()
        lastFocusUpdate = GetTime()
        focusUpdateScheduled = false
    end
end)
