--[[
    OzUF - Player Module (player.lua)
    Handles Player and Pet frame enhancements:
    - Custom frame background texture (UI-TargetingFrame2.blp at 256x128 with SetTexCoord(1, 0, 0, 1))
    - Double height health bar (29px) with left-aligned percentage and right-aligned current/max
    - Seamless 101px offset with width 124px connecting to portrait
    - Rest icon ("zzz") hiding with reversible suppression
    - Status indicators and combat glowing through PlayerStatusGlow and PlayerAttackBackground
    - Portrait toggle (Compact bar mode)
    - Frame scaling
    - Name display removed on player
    - Player level display on PlayerLevelText
]] --

local _G = getfenv(0)
OzUF.Player = {}

local function get_db()
    return OzUF_DB or OzUF.DEFAULT_CONFIG or {}
end

-- Centralized Show suppression helpers
local function suppress_show(frame)
    if not frame then return end
    frame:Hide()
    if not frame.ozuf_orig_show then
        frame.ozuf_orig_show = frame.Show
    end
    frame.Show = function() end
end

local function restore_show(frame)
    if not frame then return end
    if frame.ozuf_orig_show then
        frame.Show = frame.ozuf_orig_show
        frame.ozuf_orig_show = nil
    else
        frame.Show = nil
    end
end

local cached_name_element = nil
function OzUF.Player:get_name_element()
    if not cached_name_element then
        cached_name_element = PlayerName or PlayerFrameName or (PlayerFrame and PlayerFrame.name)
    end
    return cached_name_element
end

function OzUF.Player:apply_texture()
    if not PlayerFrameTexture then return end
    local db = get_db()
    if db.hide_portraits then
        PlayerFrameTexture:Hide()
        return
    end

    PlayerFrameTexture:Show()
    PlayerFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
    PlayerFrameTexture:SetTexCoord(1, 0, 0, 1)
    PlayerFrameTexture:ClearAllPoints()
    PlayerFrameTexture:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", -2, 2)
    PlayerFrameTexture:SetWidth(256)
    PlayerFrameTexture:SetHeight(128)
end

function OzUF.Player:setup_hide_rest_icon()
    local db = get_db()
    if db.hide_rest_icon then
        suppress_show(PlayerRestIcon)
        suppress_show(PlayerRestGlow)
    else
        restore_show(PlayerRestIcon)
        restore_show(PlayerRestGlow)
    end
end

function OzUF.Player:update_level()
    if not PlayerLevelText then return end
    local db = get_db()
    if db.hide_portraits then
        PlayerLevelText:Hide()
        return
    end
    local lvl = UnitLevel("player")
    local lvl_str = (lvl and lvl > 0) and tostring(lvl) or "??"
    PlayerLevelText:SetText(lvl_str)
    local lr, lg, lb = OzUF:get_level_color("player")
    PlayerLevelText:SetTextColor(lr, lg, lb)
    PlayerLevelText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    PlayerLevelText:SetDrawLayer("OVERLAY")
    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetPoint("CENTER", PlayerFrame, "CENTER", -64, -15)
    PlayerLevelText:Show()
end

function OzUF.Player:update_health_text()
    if not PlayerFrameHealthBarText then return end
    local cur, max = OzUF:get_unit_health_data("player")
    local pct_str, hp_str = OzUF:format_health_parts("player", cur, max)
    PlayerFrameHealthBarText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    PlayerFrameHealthBarText:SetText(hp_str)
    PlayerFrameHealthBarText:Show()

    local p_pct = PlayerFrameHealthBar and PlayerFrameHealthBar.ozuf_percent_text
    if p_pct then
        p_pct:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        p_pct:SetText(pct_str)
        p_pct:Show()
    end
end

function OzUF.Player:apply_status_layout()
    local db = get_db()
    local hide_p = db.hide_portraits

    if PlayerStatusGlow then
        PlayerStatusGlow:SetAlpha(1.0)
    end

    if hide_p then
        -- Compact bar mode (no portrait): align combat indicators to the left of the health bar
        if PlayerAttackBackground then
            PlayerAttackBackground:ClearAllPoints()
            PlayerAttackBackground:SetPoint("RIGHT", PlayerFrameHealthBar, "LEFT", -2, 0)
            PlayerAttackBackground:SetWidth(24)
            PlayerAttackBackground:SetHeight(24)
        end

        if PlayerAttackIcon then
            PlayerAttackIcon:ClearAllPoints()
            PlayerAttackIcon:SetPoint("CENTER", PlayerAttackBackground or PlayerFrameHealthBar, "CENTER", 0, 0)
            PlayerAttackIcon:SetWidth(24)
            PlayerAttackIcon:SetHeight(24)
        end

        if PlayerStatusGlow then
            PlayerStatusGlow:ClearAllPoints()
            PlayerStatusGlow:SetPoint("CENTER", PlayerAttackBackground or PlayerFrameHealthBar, "CENTER", 0, 0)
            PlayerStatusGlow:SetWidth(24)
            PlayerStatusGlow:SetHeight(24)
        end

        if PlayerAttackGlow then
            PlayerAttackGlow:ClearAllPoints()
            PlayerAttackGlow:SetAllPoints(PlayerStatusGlow)
        end

        if PlayerStatusTexture then
            PlayerStatusTexture:Hide()
        end
    else
        -- Standard portrait mode: attach around portrait
        if PlayerAttackBackground then
            PlayerAttackBackground:ClearAllPoints()
            PlayerAttackBackground:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 37, -50)
            PlayerAttackBackground:SetWidth(32)
            PlayerAttackBackground:SetHeight(32)
        end

        if PlayerAttackIcon then
            PlayerAttackIcon:ClearAllPoints()
            PlayerAttackIcon:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 38, -51)
            PlayerAttackIcon:SetWidth(32)
            PlayerAttackIcon:SetHeight(32)
        end

        if PlayerStatusGlow then
            PlayerStatusGlow:ClearAllPoints()
            PlayerStatusGlow:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 37, -52)
            PlayerStatusGlow:SetWidth(32)
            PlayerStatusGlow:SetHeight(32)
        end

        if PlayerAttackGlow then
            PlayerAttackGlow:ClearAllPoints()
            PlayerAttackGlow:SetPoint("TOPLEFT", PlayerStatusGlow, "TOPLEFT", 1, 1)
            PlayerAttackGlow:SetWidth(32)
            PlayerAttackGlow:SetHeight(32)
        end

        if PlayerStatusTexture then
            PlayerStatusTexture:ClearAllPoints()
            PlayerStatusTexture:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 35, -8)
            PlayerStatusTexture:SetWidth(190)
            PlayerStatusTexture:SetHeight(66)
        end
    end
end

function OzUF.Player:update_status()
    local db = get_db()
    local hide_p = db.hide_portraits
    local hide_rest = db.hide_rest_icon
    local in_combat = (PlayerFrame and (PlayerFrame.inCombat or PlayerFrame.onHateList)) or UnitAffectingCombat("player")
    local resting = IsResting()

    if in_combat then
        -- Combat / Attack status: show crossed-swords icon and attack glow
        if PlayerAttackBackground then PlayerAttackBackground:Show() end
        if PlayerAttackIcon then PlayerAttackIcon:Show() end
        if PlayerAttackGlow then PlayerAttackGlow:Show() end
        if PlayerRestGlow then PlayerRestGlow:Hide() end
        if PlayerRestIcon then PlayerRestIcon:Hide() end
        if PlayerStatusGlow then PlayerStatusGlow:Show() end

        if PlayerStatusTexture then
            if hide_p then
                PlayerStatusTexture:Hide()
            else
                PlayerStatusTexture:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                PlayerStatusTexture:Show()
            end
        end
    elseif resting then
        -- Resting status: respect hide_rest_icon
        if hide_rest then
            if PlayerRestIcon then PlayerRestIcon:Hide() end
            if PlayerRestGlow then PlayerRestGlow:Hide() end
            if PlayerStatusGlow then PlayerStatusGlow:Hide() end
            if PlayerStatusTexture then PlayerStatusTexture:Hide() end
        else
            if PlayerRestIcon then PlayerRestIcon:Show() end
            if PlayerRestGlow then PlayerRestGlow:Show() end
            if PlayerAttackGlow then PlayerAttackGlow:Hide() end
            if PlayerStatusGlow then PlayerStatusGlow:Show() end
            if PlayerStatusTexture and not hide_p then
                PlayerStatusTexture:SetVertexColor(1.0, 0.88, 0.25, 1.0)
                PlayerStatusTexture:Show()
            end
        end
        if PlayerAttackIcon then PlayerAttackIcon:Hide() end
        if PlayerAttackBackground then PlayerAttackBackground:Hide() end
    else
        -- Normal (out of combat, not resting)
        if PlayerStatusTexture then PlayerStatusTexture:Hide() end
        if PlayerRestIcon then PlayerRestIcon:Hide() end
        if PlayerAttackIcon then PlayerAttackIcon:Hide() end
        if PlayerStatusGlow then PlayerStatusGlow:Hide() end
        if PlayerAttackBackground then PlayerAttackBackground:Hide() end
    end
end

function OzUF.Player:apply_double_health()
    local db = get_db()
    local hide_p = db.hide_portraits

    if PlayerFrameHealthBar then
        if db.double_health then
            PlayerFrameHealthBar:SetHeight(29)
            PlayerFrameHealthBar:ClearAllPoints()

            if hide_p then
                PlayerFrameHealthBar:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 16, -22)
                PlayerFrameHealthBar:SetWidth(180)
            else
                PlayerFrameHealthBar:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 101, -22)
                PlayerFrameHealthBar:SetWidth(124)
            end

            -- Match PlayerFrameBackground to health bar height
            if PlayerFrameBackground then
                PlayerFrameBackground:ClearAllPoints()
                PlayerFrameBackground:SetAllPoints(PlayerFrameHealthBar)
                PlayerFrameBackground:SetDrawLayer("BACKGROUND")
                PlayerFrameBackground:Show()
            end

            -- Original Blizzard health text (reused for Current/Max aligned right)
            if PlayerFrameHealthBarText then
                PlayerFrameHealthBarText:ClearAllPoints()
                PlayerFrameHealthBarText:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", -4, 0)
                PlayerFrameHealthBarText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                PlayerFrameHealthBarText:SetTextColor(1, 1, 1)
                PlayerFrameHealthBarText:SetJustifyH("RIGHT")
                PlayerFrameHealthBarText:SetDrawLayer("OVERLAY")
                PlayerFrameHealthBarText:Show()
            end

            -- Percentage text aligned left
            local p_pct = PlayerFrameHealthBar.ozuf_percent_text
            if not p_pct then
                p_pct = PlayerFrameHealthBar:CreateFontString("PlayerFrameHealthBarPercentText", "OVERLAY")
                PlayerFrameHealthBar.ozuf_percent_text = p_pct
            end
            if p_pct then
                p_pct:ClearAllPoints()
                p_pct:SetPoint("LEFT", PlayerFrameHealthBar, "LEFT", 4, 0)
                p_pct:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                p_pct:SetTextColor(1, 1, 1)
                p_pct:SetJustifyH("LEFT")
                p_pct:SetDrawLayer("OVERLAY")
                p_pct:Show()
            end

            -- Move PlayerFrameManaBar down below the 29px health bar, connected seamlessly
            if PlayerFrameManaBar then
                PlayerFrameManaBar:ClearAllPoints()
                PlayerFrameManaBar:SetPoint("TOPLEFT", PlayerFrameHealthBar, "BOTTOMLEFT", 0, -1)
                PlayerFrameManaBar:SetHeight(9)
                if hide_p then
                    PlayerFrameManaBar:SetWidth(180)
                else
                    PlayerFrameManaBar:SetWidth(124)
                end
            end
        else
            -- Restore original 12px height and layout
            PlayerFrameHealthBar:SetHeight(12)
            PlayerFrameHealthBar:ClearAllPoints()
            PlayerFrameHealthBar:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 106, -41)
            PlayerFrameHealthBar:SetWidth(119)

            if PlayerFrameHealthBarText then
                PlayerFrameHealthBarText:ClearAllPoints()
                PlayerFrameHealthBarText:SetPoint("CENTER", PlayerFrameHealthBar, "CENTER", 50, 4)
                PlayerFrameHealthBarText:SetFont(STANDARD_TEXT_FONT, 10)
                PlayerFrameHealthBarText:SetJustifyH("CENTER")
            end

            if PlayerFrameHealthBar.ozuf_percent_text then
                PlayerFrameHealthBar.ozuf_percent_text:Hide()
            end

            if PlayerFrameManaBar then
                PlayerFrameManaBar:ClearAllPoints()
                PlayerFrameManaBar:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 106, -52)
                PlayerFrameManaBar:SetHeight(12)
                PlayerFrameManaBar:SetWidth(119)
            end
        end
    end

    -- Remove name display on player
    local pName = OzUF.Player:get_name_element()
    if pName then
        suppress_show(pName)
        pName:SetText("")
    end

    if PlayerPortrait then
        if hide_p then
            PlayerPortrait:Hide()
        else
            PlayerPortrait:Show()
            PlayerPortrait:ClearAllPoints()
            PlayerPortrait:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 40, -9)
            PlayerPortrait:SetWidth(64)
            PlayerPortrait:SetHeight(64)
        end
    end

    OzUF.Player:apply_status_layout()
    OzUF.Player:update_status()
    OzUF.Player:update_level()
end

function OzUF.Player:apply_portrait_mode()
    OzUF.Player:apply_double_health()
    OzUF.Player:apply_texture()
end

function OzUF.Player:apply_scale()
    local db = get_db()
    local s = db.scales
    if s then
        if PlayerFrame and s.player then PlayerFrame:SetScale(s.player) end
        if PetFrame and s.pet then PetFrame:SetScale(s.pet) end
    end
end

function OzUF.Player:update()
    OzUF.Player:apply_double_health()
    OzUF.Player:update_health_text()
    OzUF.Player:update_level()
    local pName = OzUF.Player:get_name_element()
    if pName then
        pName:Hide()
        pName:SetText("")
    end
    OzUF.Player:apply_texture()
    OzUF.Player:update_status()
end

-- Hook PlayerFrame_UpdateStatus with recursion guard
local updating_status = false
if PlayerFrame_UpdateStatus then
    local orig_PlayerFrame_UpdateStatus = PlayerFrame_UpdateStatus
    PlayerFrame_UpdateStatus = function()
        if updating_status then return end
        updating_status = true
        orig_PlayerFrame_UpdateStatus()
        OzUF.Player:update_status()
        updating_status = false
    end
end

-- Hook PlayerFrame_OnUpdate to ensure PlayerStatusGlow flashes even if PlayerStatusTexture is hidden
if PlayerFrame_OnUpdate then
    local orig_PlayerFrame_OnUpdate = PlayerFrame_OnUpdate
    PlayerFrame_OnUpdate = function(elapsed)
        orig_PlayerFrame_OnUpdate(elapsed)
        local frame = this or PlayerFrame
        if not frame then return end
        if PlayerStatusGlow and PlayerStatusGlow:IsVisible() and PlayerStatusTexture and not PlayerStatusTexture:IsVisible() then
            local counter = (frame.statusCounter or 0) + (elapsed or 0)
            local sign = frame.statusSign or 1
            if counter > 0.5 then
                sign = -sign
                frame.statusSign = sign
            end
            counter = math.mod(counter, 0.5)
            frame.statusCounter = counter
            local alpha = (sign == 1) and ((55 + counter * 400) / 255) or ((255 - counter * 400) / 255)
            PlayerStatusGlow:SetAlpha(alpha)
        end
    end
end

-- Hook PlayerFrame_Update with recursion guard
local updating_player = false
if PlayerFrame_Update then
    local orig_PlayerFrame_Update = PlayerFrame_Update
    PlayerFrame_Update = function()
        if updating_player then return end
        updating_player = true
        orig_PlayerFrame_Update()
        OzUF.Player:apply_texture()
        OzUF.Player:update()
        updating_player = false
    end
end
