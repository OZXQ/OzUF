--[[
    OzUF (Oz Unit Frames)
    WoW 1.12.1 / Turtle WoW / SuperWoW Unit Frame Addon
    Core Module & Engine Coordinator
]]--

OzUF = {}
local _G = getfenv(0)

-- Default Configuration
local DEFAULT_CONFIG = {
    locked = true,
    double_health = true,
    hide_rest_icon = true,
    mob_health_numeric_only = true,
    hide_portraits = false,
    scales = {
        player = 1.0,
        target = 1.0,
        focus  = 0.9,
        party  = 1.0,
        pet    = 0.85,
    },
    positions = {}
}
OzUF.DEFAULT_CONFIG = DEFAULT_CONFIG

-- List of movable frames
local MOVABLE_FRAMES = {
    "PlayerFrame",
    "TargetFrame",
    "TargetofTargetFrame",
    "PetFrame",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "OzUFFocusFrame",
}
OzUF.MOVABLE_FRAMES = MOVABLE_FRAMES

-- Frame user-friendly labels
local FRAME_LABELS = {
    ["PlayerFrame"] = "Player Frame",
    ["TargetFrame"] = "Target Frame",
    ["TargetofTargetFrame"] = "ToT Frame",
    ["PetFrame"] = "Pet Frame",
    ["PartyMemberFrame1"] = "Party 1",
    ["PartyMemberFrame2"] = "Party 2",
    ["PartyMemberFrame3"] = "Party 3",
    ["PartyMemberFrame4"] = "Party 4",
    ["OzUFFocusFrame"] = "Focus Frame",
}
OzUF.FRAME_LABELS = FRAME_LABELS

-- Class colors
local CLASS_COLORS = {
    ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43 },
    ["MAGE"]    = { r = 0.41, g = 0.80, b = 0.94 },
    ["ROGUE"]   = { r = 1.00, g = 0.96, b = 0.41 },
    ["DRUID"]   = { r = 1.00, g = 0.49, b = 0.04 },
    ["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45 },
    ["SHAMAN"]  = { r = 0.00, g = 0.44, b = 0.87 },
    ["PRIEST"]  = { r = 1.00, g = 1.00, b = 1.00 },
    ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79 },
    ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73 },
}
OzUF.CLASS_COLORS = CLASS_COLORS

--------------------------------------------------------------------------------
-- Utilities & Formatting
--------------------------------------------------------------------------------

local function format_number(val)
    if not val then return "0" end
    local num = math.floor(val)
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 10000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end
OzUF.format_number = function(self, val)
    if self ~= OzUF then return format_number(self) end
    return format_number(val)
end

local function get_unit_health_data(unit)
    if not unit or not UnitExists(unit) then
        return 0, 0
    end

    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)

    -- Support MobHealth addons or Turtle WoW mob health
    if unit == "target" then
        if _G.MobHealth_GetTargetCurMaxHP then
            local mh_cur, mh_max = _G.MobHealth_GetTargetCurMaxHP()
            if mh_cur and mh_max and mh_max > 0 then
                cur = mh_cur
                max = mh_max
            end
        elseif _G.MobHealth3 and _G.MobHealth3.GetUnitHealth then
            local mh_cur, mh_max = _G.MobHealth3:GetUnitHealth(unit)
            if mh_cur and mh_max and mh_max > 0 then
                cur = mh_cur
                max = mh_max
            end
        end
    end

    return cur, max
end
OzUF.get_unit_health_data = function(self, unit)
    if self ~= OzUF then return get_unit_health_data(self) end
    return get_unit_health_data(unit)
end

local function format_health_parts(unit, cur, max)
    if UnitIsDead(unit) or ((not cur or cur <= 0) and UnitIsConnected(unit) and UnitExists(unit)) then
        return "", "Dead"
    elseif UnitIsGhost(unit) then
        return "", "Ghost"
    elseif not UnitIsConnected(unit) then
        return "", "Offline"
    end

    if not cur then cur = 0 end
    if not max or max <= 0 then
        return "", tostring(cur)
    end

    local pct = math.floor((cur / max) * 100 + 0.5)
    local pct_str = pct .. "%"

    local val_str
    if cur >= 1000000 or max >= 1000000 then
        val_str = format_number(cur) .. " / " .. format_number(max)
    else
        val_str = tostring(cur) .. " / " .. tostring(max)
    end

    return pct_str, val_str
end
OzUF.format_health_parts = function(self, unit, cur, max)
    if self ~= OzUF then return format_health_parts(self, unit, cur) end
    return format_health_parts(unit, cur, max)
end

local function format_health_string(unit, cur, max)
    local pct_str, val_str = format_health_parts(unit, cur, max)
    if pct_str and pct_str ~= "" then
        return val_str .. " (" .. pct_str .. ")"
    end
    return val_str
end
OzUF.format_health_string = function(self, unit, cur, max)
    if self ~= OzUF then return format_health_string(self, unit, cur) end
    return format_health_string(unit, cur, max)
end

local function get_level_color(unit)
    if not UnitExists(unit) then
        return 1, 1, 1
    end
    local level = UnitLevel(unit)
    if level <= 0 then
        return 1.0, 0.0, 0.0 -- World boss / skull
    end
    local diff = GetDifficultyColor(level)
    if diff then
        return diff.r, diff.g, diff.b
    end
    return 1, 1, 0
end
OzUF.get_level_color = function(self, unit)
    if self ~= OzUF then return get_level_color(self) end
    return get_level_color(unit)
end

local function get_unit_level_text(unit)
    if not UnitExists(unit) then
        return ""
    end
    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)
    local suffix = ""
    if classification == "elite" or classification == "rareelite" then
        suffix = "+"
    elseif classification == "worldboss" then
        suffix = "B"
    end

    if level <= 0 then
        return "??" .. suffix
    end
    return tostring(level) .. suffix
end
OzUF.get_unit_level_text = function(self, unit)
    if self ~= OzUF then return get_unit_level_text(self) end
    return get_unit_level_text(unit)
end

local function merge_defaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            merge_defaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end
OzUF.merge_defaults = function(self, target, source)
    if self ~= OzUF then return merge_defaults(self, target) end
    return merge_defaults(target, source)
end

--------------------------------------------------------------------------------
-- Database & Initialization
--------------------------------------------------------------------------------

local function init_database()
    if not OzUF_DB then
        OzUF_DB = {}
    end
    merge_defaults(OzUF_DB, DEFAULT_CONFIG)
end
OzUF.init_database = init_database

--------------------------------------------------------------------------------
-- Dual-Line Health Bar Text System
-- Line 1: Unit Name & Level
-- Line 2: Health value (No divider dash or border)
--------------------------------------------------------------------------------

local function create_health_bar_texts(frame, health_bar, unit)
    if not health_bar or health_bar.ozuf_texts then return end

    local text_overlay = CreateFrame("Frame", nil, health_bar)
    text_overlay:SetAllPoints(health_bar)
    text_overlay:SetFrameLevel(health_bar:GetFrameLevel() + 2)

    -- Line 1: Name (Horizontally centered for focus)
    local name_text = text_overlay:CreateFontString(nil, "OVERLAY")
    name_text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    if unit == "focus" then
        name_text:SetPoint("TOP", text_overlay, "TOP", 0, -2)
        name_text:SetWidth(120)
        name_text:SetHeight(12)
        name_text:SetJustifyH("CENTER")
    else
        name_text:SetPoint("TOPLEFT", text_overlay, "TOPLEFT", 4, -1)
        name_text:SetJustifyH("LEFT")
    end
    name_text:SetTextColor(1, 1, 1)

    -- Line 1: Right-aligned Level
    local level_text = text_overlay:CreateFontString(nil, "OVERLAY")
    level_text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    level_text:SetPoint("TOPRIGHT", text_overlay, "TOPRIGHT", -4, -1)
    level_text:SetJustifyH("RIGHT")

    -- Line 2: Percentage (Bottom left)
    local percent_text = text_overlay:CreateFontString(nil, "OVERLAY")
    percent_text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    if unit == "focus" then
        percent_text:SetPoint("BOTTOMLEFT", text_overlay, "BOTTOMLEFT", 4, 7)
    else
        percent_text:SetPoint("BOTTOMLEFT", text_overlay, "BOTTOMLEFT", 4, 2)
    end
    percent_text:SetJustifyH("LEFT")
    percent_text:SetTextColor(1, 1, 1)

    -- Line 2: Health value (Bottom right, current / max)
    local health_text = text_overlay:CreateFontString(nil, "OVERLAY")
    health_text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    if unit == "focus" then
        health_text:SetPoint("BOTTOMRIGHT", text_overlay, "BOTTOMRIGHT", -4, 7)
    else
        health_text:SetPoint("BOTTOMRIGHT", text_overlay, "BOTTOMRIGHT", -4, 2)
    end
    health_text:SetJustifyH("RIGHT")
    health_text:SetTextColor(1, 1, 1)

    health_bar.ozuf_texts = {
        overlay = text_overlay,
        name = name_text,
        level = level_text,
        percent = percent_text,
        health = health_text,
        unit = unit,
    }
end
OzUF.create_health_bar_texts = function(self, frame, health_bar, unit)
    if self ~= OzUF then return create_health_bar_texts(self, frame, health_bar) end
    return create_health_bar_texts(frame, health_bar, unit)
end

local function update_health_bar_texts(health_bar, custom_unit)
    if not health_bar then return end
    if health_bar == PlayerFrameHealthBar and OzUF.Player and OzUF.Player.update_health_text then
        OzUF.Player:update_health_text()
        return
    elseif health_bar == TargetFrameHealthBar and OzUF.Target and OzUF.Target.update_health_text then
        OzUF.Target:update_health_text()
        return
    end

    if not health_bar.ozuf_texts then return end
    local texts = health_bar.ozuf_texts
    local unit = custom_unit or texts.unit
    if not unit or not UnitExists(unit) then
        texts.overlay:Hide()
        return
    end

    texts.overlay:Show()

    -- Line 1: Name
    local name = UnitName(unit) or ""
    texts.name:SetText(name)
    if unit == "focus" then
        texts.name:ClearAllPoints()
        texts.name:SetPoint("TOP", health_bar, "TOP", 0, -2)
        texts.name:SetWidth(120)
        texts.name:SetHeight(12)
        texts.name:SetJustifyH("CENTER")
        texts.name:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    end

    -- Color name by class if player, or reaction if NPC
    if UnitIsPlayer(unit) then
        local _, class_token = UnitClass(unit)
        local color = CLASS_COLORS[class_token]
        if color then
            texts.name:SetTextColor(color.r, color.g, color.b)
        else
            texts.name:SetTextColor(1, 1, 1)
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction and reaction <= 2 then
            texts.name:SetTextColor(1, 0.2, 0.2) -- Hostile (Red)
        elseif reaction and reaction <= 4 then
            texts.name:SetTextColor(1, 1, 0.2)   -- Neutral (Yellow)
        else
            texts.name:SetTextColor(0.2, 1, 0.2) -- Friendly (Green)
        end
    end

    -- Line 1: Level (Focus level is displayed on OzUFFocusFrameTextureFrameLevelText portrait badge)
    if unit == "focus" then
        texts.level:SetText("")
        texts.level:Hide()
    else
        local lvl_str = get_unit_level_text(unit)
        local lr, lg, lb = get_level_color(unit)
        texts.level:SetText(lvl_str)
        texts.level:SetTextColor(lr, lg, lb)
        texts.level:Show()
    end

    -- Line 2: Health (Percentage left-aligned, current / max right-aligned)
    local cur, max = get_unit_health_data(unit)
    local pct_str, hp_str = format_health_parts(unit, cur, max)
    if unit == "focus" then
        if texts.percent then
            texts.percent:ClearAllPoints()
            texts.percent:SetPoint("BOTTOMLEFT", health_bar, "BOTTOMLEFT", 4, 7)
            texts.percent:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            texts.percent:SetJustifyH("LEFT")
        end
        texts.health:ClearAllPoints()
        texts.health:SetPoint("BOTTOMRIGHT", health_bar, "BOTTOMRIGHT", -4, 7)
        texts.health:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        texts.health:SetJustifyH("RIGHT")
    end
    if texts.percent then
        texts.percent:SetText(pct_str)
        texts.percent:Show()
    end
    texts.health:SetText(hp_str)
    texts.health:Show()
end
OzUF.update_health_bar_texts = function(self, health_bar, custom_unit)
    if self ~= OzUF then return update_health_bar_texts(self, health_bar) end
    return update_health_bar_texts(health_bar, custom_unit)
end

-- Suppress prefix in status bars (Mana, Energy, Rage) so only numbers are shown
if SetTextStatusBarTextPrefix then
    local orig_SetTextStatusBarTextPrefix = SetTextStatusBarTextPrefix
    SetTextStatusBarTextPrefix = function(bar, prefix)
        orig_SetTextStatusBarTextPrefix(bar, nil)
    end
end

-- Hook TextStatusBar_UpdateTextString to ensure native health/mana texts remain formatted without prefixes
if TextStatusBar_UpdateTextString then
    local orig_TextStatusBar_UpdateTextString = TextStatusBar_UpdateTextString
    TextStatusBar_UpdateTextString = function(bar)
        local status_bar = bar or this
        if status_bar then
            status_bar.prefix = nil
            status_bar.alwaysPrefix = nil
        end
        orig_TextStatusBar_UpdateTextString(status_bar)
        if status_bar == PlayerFrameHealthBar and OzUF.Player and OzUF.Player.update_health_text then
            OzUF.Player:update_health_text()
        elseif status_bar == TargetFrameHealthBar and OzUF.Target and OzUF.Target.update_health_text then
            OzUF.Target:update_health_text()
        elseif status_bar and status_bar.TextString then
            local text = status_bar.TextString:GetText()
            if text then
                local _, _, clean = string.find(text, ".*:%s*(.+)")
                if clean then
                    status_bar.TextString:SetText(clean)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Movable Unit Frames Engine
--------------------------------------------------------------------------------

local overlays = {}
local control_bar = nil

local function save_frame_position(frame, name)
    if not frame then return end
    local point, _, relPoint, xOfs, yOfs = frame:GetPoint()
    if not point then return end
    if not OzUF_DB.positions then OzUF_DB.positions = {} end
    OzUF_DB.positions[name] = {
        point = point,
        relPoint = relPoint,
        x = math.floor(xOfs + 0.5),
        y = math.floor(yOfs + 0.5),
    }
end
OzUF.save_frame_position = function(self, frame, name)
    if self ~= OzUF then return save_frame_position(self, frame) end
    return save_frame_position(frame, name)
end

local function restore_frame_position(frame, name)
    if not frame or not OzUF_DB or not OzUF_DB.positions then return end
    local pos = OzUF_DB.positions[name]
    if pos and pos.point and pos.x and pos.y then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
        frame:SetUserPlaced(true)
        frame:SetClampedToScreen(true)
    end
end
OzUF.restore_frame_position = function(self, frame, name)
    if self ~= OzUF then return restore_frame_position(self, frame) end
    return restore_frame_position(frame, name)
end

local function restore_all_positions()
    for _, name in ipairs(MOVABLE_FRAMES) do
        local cap_name = name
        local frame = _G[cap_name]
        if frame then
            restore_frame_position(frame, cap_name)
        end
    end
end
OzUF.restore_all_positions = restore_all_positions

local function create_drag_overlays()
    for _, name in ipairs(MOVABLE_FRAMES) do
        local cap_name = name
        local target_frame = _G[cap_name]
        if target_frame and not overlays[cap_name] then
            local ov = CreateFrame("Button", nil, target_frame)
            ov:SetAllPoints(target_frame)
            ov:SetFrameLevel(target_frame:GetFrameLevel() + 10)
            ov:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            ov:SetBackdropColor(0.1, 0.6, 0.9, 0.45)
            ov:SetBackdropBorderColor(0.2, 0.8, 1.0, 0.9)
            ov:EnableMouse(true)
            ov:RegisterForDrag("LeftButton")

            local label = ov:CreateFontString(nil, "OVERLAY")
            label:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
            label:SetPoint("CENTER", ov, "CENTER", 0, 0)
            label:SetText(FRAME_LABELS[cap_name] or cap_name)
            label:SetTextColor(1, 1, 1)

            target_frame:SetMovable(true)
            target_frame:SetClampedToScreen(true)

            local cap_target = target_frame
            local cap_n = cap_name
            ov:SetScript("OnDragStart", function()
                cap_target:StartMoving()
            end)
            ov:SetScript("OnDragStop", function()
                cap_target:StopMovingOrSizing()
                cap_target:SetUserPlaced(true)
                save_frame_position(cap_target, cap_n)
            end)

            ov:Hide()
            overlays[cap_name] = ov
        end
    end
end
OzUF.create_drag_overlays = create_drag_overlays

local function create_control_bar()
    if control_bar then return end

    local bar = CreateFrame("Frame", "OzUFControlBar", UIParent)
    bar:SetWidth(320)
    bar:SetHeight(44)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -25)
    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bar:SetBackdropColor(0, 0, 0, 0.85)
    bar:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
    bar:SetFrameStrata("DIALOG")
    bar:Hide()

    local title = bar:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    title:SetPoint("LEFT", bar, "LEFT", 12, 0)
    title:SetText("OzUF: Drag to Move")
    title:SetTextColor(1, 0.85, 0.2)

    local lock_btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    lock_btn:SetWidth(90)
    lock_btn:SetHeight(24)
    lock_btn:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    lock_btn:SetText("Lock Frames")
    lock_btn:SetScript("OnClick", function()
        OzUF:lock_frames()
    end)

    local reset_btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    reset_btn:SetWidth(80)
    reset_btn:SetHeight(24)
    reset_btn:SetPoint("RIGHT", lock_btn, "LEFT", -6, 0)
    reset_btn:SetText("Reset")
    reset_btn:SetScript("OnClick", function()
        OzUF:reset_positions()
    end)

    control_bar = bar
end
OzUF.create_control_bar = create_control_bar

function OzUF:unlock_frames()
    OzUF_DB.locked = false
    create_drag_overlays()
    create_control_bar()

    for _, name in ipairs(MOVABLE_FRAMES) do
        local cap_name = name
        local ov = overlays[cap_name]
        local frame = _G[cap_name]
        if ov and frame then
            frame:Show()
            ov:Show()
        end
    end

    if control_bar then control_bar:Show() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Frames unlocked. Drag highlight boxes to reposition.")
end

function OzUF:restore_frame_visibility()
    -- 1. Party Frames (PartyMemberFrame 1 to 4)
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then
            if not UnitExists("party" .. i) then
                pf:Hide()
                local pet_pf = _G["PartyMemberFrame" .. i .. "PetFrame"]
                if pet_pf then pet_pf:Hide() end
            else
                pf:Show()
                if PartyMemberFrame_UpdateMember then
                    local old_this = this
                    this = pf
                    PartyMemberFrame_UpdateMember()
                    this = old_this
                end
                if OzUF.Party and OzUF.Party.update then
                    OzUF.Party:update("party" .. i)
                end
            end
        end
    end

    -- 2. Focus Frame (OzUFFocusFrame)
    if OzUFFocusFrame then
        local has_focus = false
        if OzUF.Focus and OzUF.Focus.name then
            has_focus = true
        elseif OzUF.focus_name then
            has_focus = true
        end

        if has_focus then
            OzUFFocusFrame:Show()
            if OzUF.Focus and OzUF.Focus.update then
                OzUF.Focus:update()
            end
        else
            OzUFFocusFrame:Hide()
        end
    end

    -- 3. Target Frame
    if TargetFrame then
        if not UnitExists("target") then
            TargetFrame:Hide()
        else
            TargetFrame:Show()
            if TargetFrame_Update then
                TargetFrame_Update()
            end
            if OzUF.Target and OzUF.Target.update then
                OzUF.Target:update()
            end
        end
    end

    -- 4. Target of Target Frame
    if TargetofTargetFrame then
        if not UnitExists("target") or not UnitExists("targettarget") then
            TargetofTargetFrame:Hide()
        else
            if TargetofTarget_Update then
                TargetofTarget_Update()
            else
                TargetofTargetFrame:Show()
            end
        end
    end

    -- 5. Pet Frame
    if PetFrame then
        if not UnitExists("pet") then
            PetFrame:Hide()
        else
            PetFrame:Show()
            if PetFrame_Update then
                PetFrame_Update()
            end
        end
    end
end

function OzUF:lock_frames()
    OzUF_DB.locked = true
    for _, name in ipairs(MOVABLE_FRAMES) do
        local cap_name = name
        local ov = overlays[cap_name]
        if ov then ov:Hide() end
    end

    if control_bar then control_bar:Hide() end
    self:restore_frame_visibility()
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Frames locked.")
end

function OzUF:reset_positions()
    OzUF_DB.positions = {}
    if PlayerFrame then
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
        PlayerFrame:SetUserPlaced(false)
    end
    if TargetFrame then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -4)
        TargetFrame:SetUserPlaced(false)
    end
    if OzUFFocusFrame then
        OzUFFocusFrame:ClearAllPoints()
        OzUFFocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -180)
    end
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then pf:SetUserPlaced(false) end
    end
    if PetFrame then PetFrame:SetUserPlaced(false) end
    if TargetofTargetFrame then TargetofTargetFrame:SetUserPlaced(false) end

    if OzUF_DB.locked then
        self:restore_frame_visibility()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Frame positions reset to defaults.")
end

--------------------------------------------------------------------------------
-- Unified Lifecycle Delegates
--------------------------------------------------------------------------------

function OzUF:setup_hide_rest_icon()
    if OzUF.Player and OzUF.Player.setup_hide_rest_icon then
        OzUF.Player:setup_hide_rest_icon()
    end
end

function OzUF:apply_double_health_layout()
    if OzUF.Player and OzUF.Player.apply_double_health then
        OzUF.Player:apply_double_health()
    end
    if OzUF.Target and OzUF.Target.apply_double_health then
        OzUF.Target:apply_double_health()
    end
    if OzUF.Party and OzUF.Party.apply_double_health then
        OzUF.Party:apply_double_health()
    end
end

function OzUF:apply_portrait_mode()
    if OzUF.Player and OzUF.Player.apply_portrait_mode then
        OzUF.Player:apply_portrait_mode()
    end
    if OzUF.Target and OzUF.Target.apply_portrait_mode then
        OzUF.Target:apply_portrait_mode()
    end
    if OzUF.Party and OzUF.Party.apply_portrait_mode then
        OzUF.Party:apply_portrait_mode()
    end
    if OzUF.Focus and OzUF.Focus.apply_portrait_mode then
        OzUF.Focus:apply_portrait_mode()
    end
end

function OzUF:apply_scales()
    if OzUF.Player and OzUF.Player.apply_scale then
        OzUF.Player:apply_scale()
    end
    if OzUF.Target and OzUF.Target.apply_scale then
        OzUF.Target:apply_scale()
    end
    if OzUF.Party and OzUF.Party.apply_scale then
        OzUF.Party:apply_scale()
    end
    if OzUF.Focus and OzUF.Focus.apply_scale then
        OzUF.Focus:apply_scale()
    end
end

function OzUF:apply_textures()
    if OzUF.Player and OzUF.Player.apply_texture then
        OzUF.Player:apply_texture()
    end
    if OzUF.Target and OzUF.Target.apply_texture then
        OzUF.Target:apply_texture()
    end
    if OzUF.Party and OzUF.Party.apply_texture then
        OzUF.Party:apply_texture()
    end
    if OzUF.Focus and OzUF.Focus.apply_texture then
        OzUF.Focus:apply_texture()
    end
end

--------------------------------------------------------------------------------
-- Main Event Listener
--------------------------------------------------------------------------------

local event_frame = CreateFrame("Frame", "OzUFEventFrame", UIParent)
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:RegisterEvent("UNIT_HEALTH")
event_frame:RegisterEvent("UNIT_MAXHEALTH")
event_frame:RegisterEvent("PLAYER_TARGET_CHANGED")
event_frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
event_frame:RegisterEvent("UNIT_LEVEL")
event_frame:RegisterEvent("PLAYER_LEVEL_UP")
event_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")

event_frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OzUF" then
        init_database()
        if OzUF.Focus and OzUF.Focus.create_frame then
            OzUF.Focus:create_frame()
        end
        create_drag_overlays()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OzUF:setup_hide_rest_icon()
        OzUF:apply_double_health_layout()
        OzUF:apply_textures()
        OzUF:apply_portrait_mode()
        OzUF:apply_scales()
        restore_all_positions()

        if OzUF.Player and OzUF.Player.update then
            OzUF.Player:update()
        end
        if OzUF.Target and OzUF.Target.update then
            OzUF.Target:update()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if OzUF.Target and OzUF.Target.update then
            OzUF.Target:update()
        end
        if OzUF.Focus and OzUF.Focus.update then
            OzUF.Focus:update()
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local unit = arg1
        if unit == "player" and OzUF.Player then
            OzUF.Player:update()
        elseif unit == "target" and OzUF.Target then
            OzUF.Target:update()
        elseif unit and string.find(unit, "party") and OzUF.Party then
            OzUF.Party:update(unit)
        end

        if OzUF.Focus and OzUF.Focus.name and OzUF.Focus.update then
            OzUF.Focus:update()
        end
    elseif event == "UNIT_LEVEL" or event == "PLAYER_LEVEL_UP" then
        if (not arg1 or arg1 == "player") and OzUF.Player and OzUF.Player.update_level then
            OzUF.Player:update_level()
        end
        if arg1 == "target" and OzUF.Target and OzUF.Target.update_level then
            OzUF.Target:update_level()
        end
        if OzUF.Focus and OzUF.Focus.update then
            OzUF.Focus:update()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if OzUF.Player and OzUF.Player.update_status then
            OzUF.Player:update_status()
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        if OzUF.Party then
            OzUF.Party:apply_double_health()
            OzUF.Party:apply_portrait_mode()
            OzUF.Party:apply_scale()
            OzUF.Party:apply_texture()
        end
    end
end)

-- Periodic ticker for Focus tracking
local ticker_time = 0
event_frame:SetScript("OnUpdate", function()
    local elapsed = arg1 or 0.1
    ticker_time = ticker_time + elapsed
    if ticker_time >= 0.25 then
        ticker_time = 0
        if OzUF.Focus and OzUF.Focus.name and OzUF.Focus.update then
            OzUF.Focus:update()
        end
    end
end)
