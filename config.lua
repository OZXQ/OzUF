--[[ OzUF - Lean Config & Minimap Button (Shagu Style) ]]--
local _G = getfenv(0)
OzUF = OzUF or {}
local isZh = GetLocale() == "zhCN"

OzUF_DB = OzUF_DB or {}

local movables = { "PlayerFrame", "TargetFrame", "PartyMemberFrame1" }

-------------------------------------------------------------------------------
-- 1. Frame Position Persistence & Dragging
-------------------------------------------------------------------------------
function OzUF.SaveFramePosition(frame)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    OzUF_DB = OzUF_DB or {}
    local point, _, relPoint, x, y = frame:GetPoint()
    if point and x and y then
        OzUF_DB["pos_" .. name] = {
            point = point,
            relPoint = relPoint or point,
            x = x,
            y = y,
        }
    end
end

function OzUF.LoadFramePosition(frame)
    if not frame then return end
    local name = frame:GetName()
    if not name then return end
    if not OzUF_DB then return end
    local pos = OzUF_DB["pos_" .. name]
    if pos and pos.x and pos.y then
        frame:SetMovable(true)
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT", pos.x, pos.y)
        frame:SetUserPlaced(true)
    end
end

function OzUF.LoadAllFramePositions()
    for _, name in ipairs(movables) do
        local f = _G[name]
        if f then
            OzUF.LoadFramePosition(f)
        end
    end
    if OzUF_DB and OzUF_DB["focus_pos"] and OzUF.FocusFrame then
        local pos = OzUF_DB["focus_pos"]
        OzUF.FocusFrame:ClearAllPoints()
        OzUF.FocusFrame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relPoint or "TOPLEFT", pos.x or 250, pos.y or -220)
    end
    if OzUF.Castbars then
        if OzUF.Castbars.Player and OzUF.Castbars.Player.LoadPosition then OzUF.Castbars.Player:LoadPosition() end
        if OzUF.Castbars.Target and OzUF.Castbars.Target.LoadPosition then OzUF.Castbars.Target:LoadPosition() end
        if OzUF.Castbars.Focus  and OzUF.Castbars.Focus.LoadPosition  then OzUF.Castbars.Focus:LoadPosition()  end
    end
end

function OzUF.SetupFrameDrag(frame)
    if not frame then return end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    if frame.RegisterForClicks then
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if OzUF.IsFramesUnlocked() or IsShiftKeyDown() then
            this:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        OzUF.SaveFramePosition(this)
    end)
end

function OzUF.SetLockAll(locked)
    OzUF_DB["locked"] = locked
    for _, name in ipairs(movables) do
        local f = _G[name]
        if f then
            OzUF.SetupFrameDrag(f)
        end
    end
    if OzUF.FocusFrame then
        OzUF.FocusFrame.isLocked = locked
    end
    if OzUF.Castbars then
        if OzUF.Castbars.Player then OzUF.Castbars.Player:EnableMouse(not locked) end
        if OzUF.Castbars.Target then OzUF.Castbars.Target:EnableMouse(not locked) end
        if OzUF.Castbars.Focus then OzUF.Castbars.Focus:EnableMouse(not locked) end
    end
    local msg = locked and (isZh and "所有框体已锁定" or "All frames locked.") 
                        or (isZh and "所有框体已解锁 (可直接左键拖动调整位置)" or "All frames unlocked (drag frames to move).")
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. msg)
end

function OzUF.IsFramesUnlocked()
    return OzUF_DB["locked"] == false
end

function OzUF.ResetPositions()
    for _, name in ipairs(movables) do
        OzUF_DB["pos_" .. name] = nil
        local f = _G[name]
        if f then
            f:ClearAllPoints()
            f:SetUserPlaced(false)
        end
    end
    if PlayerFrame then
        PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
    end
    if TargetFrame then
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -4)
    end
    if PartyMemberFrame1 then
        PartyMemberFrame1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -160)
    end
    if OzUF_DB then
        OzUF_DB["focus_pos"] = nil
        OzUF_DB["player_castbar_pos"] = nil
        OzUF_DB["target_castbar_pos"] = nil
        OzUF_DB["focus_castbar_pos"] = nil
    end
    if OzUF.FocusFrame then
        OzUF.FocusFrame:ClearAllPoints()
        OzUF.FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -220)
    end
    if OzUF.Castbars then
        if OzUF.Castbars.Player and OzUF.Castbars.Player.ResetToDefaultPosition then
            OzUF.Castbars.Player:ResetToDefaultPosition()
        end
        if OzUF.Castbars.Target and OzUF.Castbars.Target.ResetToDefaultPosition then
            OzUF.Castbars.Target:ResetToDefaultPosition()
        end
        if OzUF.Castbars.Focus and OzUF.Castbars.Focus.ResetToDefaultPosition then
            OzUF.Castbars.Focus:ResetToDefaultPosition()
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00OzUF|r: " .. (isZh and "所有框体位置已重置为默认" or "All frame positions reset to default."))
end

-------------------------------------------------------------------------------
-- 2. Frame Scales
-------------------------------------------------------------------------------
function OzUF.SetScale(unit, val)
    OzUF_DB["scale_" .. unit] = val
    if unit == "targetcast" then
        OzUF_DB["scale_target_castbar"] = val
    elseif unit == "focuscast" then
        OzUF_DB["scale_focus_castbar"] = val
    end
    if unit == "player" and PlayerFrame then
        PlayerFrame:SetScale(val)
    elseif unit == "target" and TargetFrame then
        TargetFrame:SetScale(val)
    elseif unit == "focus" and OzUF.FocusFrame then
        OzUF.FocusFrame:SetScale(val)
    elseif unit == "party" then
        for i = 1, 4 do
            if _G["PartyMemberFrame" .. i] then _G["PartyMemberFrame" .. i]:SetScale(val) end
        end
    elseif unit == "playercast" and OzUF.Castbars and OzUF.Castbars.Player then
        OzUF.Castbars.Player:SetScale(val)
    elseif unit == "targetcast" and OzUF.Castbars and OzUF.Castbars.Target then
        OzUF.Castbars.Target:SetScale(val)
    elseif unit == "focuscast" and OzUF.Castbars and OzUF.Castbars.Focus then
        OzUF.Castbars.Focus:SetScale(val)
    end
end

-------------------------------------------------------------------------------
-- 3. Options Window
-------------------------------------------------------------------------------
local cfg = CreateFrame("Frame", "OzUFConfig", UIParent)
cfg:SetWidth(270)
cfg:SetHeight(300)
cfg:SetPoint("CENTER", 0, 30)
cfg:SetFrameStrata("DIALOG")
cfg:SetMovable(true)
cfg:EnableMouse(true)
cfg:RegisterForDrag("LeftButton")
cfg:SetScript("OnDragStart", function() this:StartMoving() end)
cfg:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
cfg:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
cfg:Hide()
tinsert(UISpecialFrames, "OzUFConfig")

local title = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", cfg, "TOP", 0, -12)
title:SetText(isZh and "OzUF 设置" or "OzUF Settings")

-- Lock All Checkbox
local lockCb = CreateFrame("CheckButton", "OzUFLockCB", cfg, "UICheckButtonTemplate")
lockCb:SetPoint("TOPLEFT", 16, -34)
getglobal("OzUFLockCBText"):SetText(isZh and "锁定所有框体" or "Lock All Frames")
lockCb:SetScript("OnClick", function()
    OzUF.SetLockAll(this:GetChecked() == 1)
end)

-- Slider builder helper
local function AddSlider(name, label, unit, defaultVal, y)
    local s = CreateFrame("Slider", name, cfg, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 16, y)
    s:SetWidth(235)
    s:SetHeight(16)
    s:SetMinMaxValues(0.5, 1.5)
    s:SetValueStep(0.05)
    getglobal(name .. "Low"):SetText("50%")
    getglobal(name .. "High"):SetText("150%")

    local function UpdateText(val)
        getglobal(name .. "Text"):SetText(label .. ": " .. math.floor(val * 100 + 0.5) .. "%")
    end

    local cur = OzUF_DB["scale_" .. unit] or defaultVal
    s:SetValue(cur)
    UpdateText(cur)

    s:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue() * 100 + 0.5) / 100
        UpdateText(val)
        OzUF.SetScale(unit, val)
    end)
    return s
end

AddSlider("OzUFScalePlayer", isZh and "玩家框体缩放" or "Player Scale", "player", 0.8, -78)
AddSlider("OzUFScaleTarget", isZh and "目标框体缩放" or "Target Scale", "target", 0.8, -118)
AddSlider("OzUFScaleFocus",  isZh and "焦点框体缩放" or "Focus Scale",  "focus",  0.6, -158)
AddSlider("OzUFScaleParty",  isZh and "小队框体缩放" or "Party Scale",  "party",  1.0, -198)

-- Reset & Close Buttons
local reset = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
reset:SetWidth(90)
reset:SetHeight(22)
reset:SetPoint("BOTTOMLEFT", 16, 14)
reset:SetText(isZh and "重置位置" or "Reset Pos")
reset:SetScript("OnClick", function() OzUF.ResetPositions() end)

local close = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
close:SetWidth(90)
close:SetHeight(22)
close:SetPoint("BOTTOMRIGHT", -16, 14)
close:SetText(isZh and "关闭" or "Close")
close:SetScript("OnClick", function() cfg:Hide() end)

function OzUF.ToggleConfig()
    if cfg:IsShown() then
        cfg:Hide()
    else
        lockCb:SetChecked((OzUF_DB["locked"] ~= false) and 1 or 0)
        cfg:Show()
    end
end

-------------------------------------------------------------------------------
-- 4. Minimap Button
-------------------------------------------------------------------------------
local btn = CreateFrame("Button", "OzUFMinimap", Minimap)
btn:SetWidth(31)
btn:SetHeight(31)
btn:SetFrameStrata("LOW")
btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
btn:EnableMouse(true)
btn:SetMovable(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton", "RightButton")

local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Eye_01")
icon:SetPoint("CENTER", 0, 0)
icon:SetWidth(20)
icon:SetHeight(20)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", 0, 0)

btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function SetPos(angle)
    OzUF_DB["minimap_angle"] = angle
    local rad = math.rad(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

btn:SetScript("OnDragStart", function() this.drag = true end)
btn:SetScript("OnDragStop", function() this.drag = nil end)
btn:SetScript("OnUpdate", function()
    if this.drag then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        local deg = math.deg(math.atan2(py / s - my, px / s - mx))
        SetPos(deg < 0 and deg + 360 or deg)
    end
end)

btn:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        OzUF.SetLockAll(not OzUF.IsFramesUnlocked())
    else
        OzUF.ToggleConfig()
    end
end)

btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("OzUF")
    GameTooltip:AddLine(isZh and "左键: 打开设置" or "Left Click: Settings", 1, 1, 1)
    GameTooltip:AddLine(isZh and "右键: 锁定/解锁框体" or "Right Click: Lock/Unlock", 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-------------------------------------------------------------------------------
-- 5. Init & Slash Commands
-------------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("VARIABLES_LOADED")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function()
    SetPos(OzUF_DB["minimap_angle"] or 215)

    if OzUF_DB["scale_player"] then OzUF.SetScale("player", OzUF_DB["scale_player"]) end
    if OzUF_DB["scale_target"] then OzUF.SetScale("target", OzUF_DB["scale_target"]) end
    if OzUF_DB["scale_focus"]  then OzUF.SetScale("focus",  OzUF_DB["scale_focus"])  end
    if OzUF_DB["scale_party"]  then OzUF.SetScale("party",  OzUF_DB["scale_party"])  end

    for _, name in ipairs(movables) do
        local f = _G[name]
        if f then OzUF.SetupFrameDrag(f) end
    end
    OzUF.LoadAllFramePositions()

    if OzUF_DB["locked"] == false then
        OzUF.SetLockAll(false)
    end
end)

local delayInit = CreateFrame("Frame")
delayInit:Hide()
delayInit:RegisterEvent("PLAYER_ENTERING_WORLD")
delayInit:SetScript("OnEvent", function()
    this.timer = 0
    this:Show()
end)
delayInit:SetScript("OnUpdate", function()
    if not this.timer then return end
    this.timer = this.timer + arg1
    if this.timer >= 0.2 then
        this:Hide()
        this.timer = nil
        for _, name in ipairs(movables) do
            local f = _G[name]
            if f then OzUF.SetupFrameDrag(f) end
        end
        OzUF.LoadAllFramePositions()
    end
end)

SLASH_OZUF1 = "/oz"
SLASH_OZUF2 = "/ozuf"
SlashCmdList["OZUF"] = function(msg)
    if msg == "reset" then
        OzUF.ResetPositions()
    else
        OzUF.ToggleConfig()
    end
end
