--[[
    OzUF - Target Module (target.lua)
    Handles Target and Target of Target frame enhancements:
    - Double height health bar (29px) with 2-line layout inside the health bar:
      - Line 1: Target Name (Left)
      - Line 2: Health value (current / max) & percentage
    - Target level on TargetFrameTextureFrameLevelText (portrait circular badge)
    - Texture filling connects seamlessly to portrait (no 5px disconnect)
    - Full height background preservation on dead/corpse targets
    - Portrait toggle (Compact bar mode)
    - Frame scaling
]] --

local _G = getfenv(0)
OzUF.Target = {}

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

function OzUF.Target:get_name_element()
    return TargetName
        or TargetFrameName
        or TargetFrameTextureFrameName
        or (TargetFrame and TargetFrame.name)
        or (TargetFrameTextureFrame and TargetFrameTextureFrame.name)
end

function OzUF.Target:get_level_element()
    local elem = TargetLevelText
        or TargetFrameTextureFrameLevelText
        or (TargetFrame and TargetLevelText)
        or (TargetFrame and TargetFrame.level)
        or (TargetFrameTextureFrame and TargetFrameTextureFrame.level)
    if not elem and TargetFrame then
        elem = TargetFrame:CreateFontString("TargetLevelText", "OVERLAY")
        TargetLevelText = elem
    end
    return elem
end

function OzUF.Target:get_health_text_element()
    local text = TargetFrameHealthBarText
        or (TargetFrameHealthBar and TargetFrameHealthBar.TextString)
        or (TargetFrameHealthBar and TargetFrameHealthBar.ozuf_health_text)
    if not text and TargetFrameHealthBar then
        text = TargetFrameHealthBar:CreateFontString("TargetFrameHealthBarText", "OVERLAY")
        TargetFrameHealthBarText = text
        TargetFrameHealthBar.TextString = text
        TargetFrameHealthBar.ozuf_health_text = text
    end
    return text
end

function OzUF.Target:get_percent_text_element()
    local t_pct = TargetFrameHealthBar and TargetFrameHealthBar.ozuf_percent_text
    if not t_pct and TargetFrameHealthBar then
        t_pct = TargetFrameHealthBar:CreateFontString("TargetFrameHealthBarPercentText", "OVERLAY")
        TargetFrameHealthBar.ozuf_percent_text = t_pct
    end
    return t_pct
end

function OzUF.Target:update_level()
    local tLevel = OzUF.Target:get_level_element()
    if not tLevel then return end

    tLevel.Show = nil
    if OzUF_DB and OzUF_DB.hide_portraits then
        tLevel:Hide()
        if TargetHighLevelTexture then TargetHighLevelTexture:Hide() end
        return
    end

    if not UnitExists("target") then
        tLevel:Hide()
        if TargetHighLevelTexture then TargetHighLevelTexture:Hide() end
        return
    end

    tLevel:ClearAllPoints()
    tLevel:SetPoint("CENTER", TargetFrame, "CENTER", 64, -15)
    tLevel:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    tLevel:SetDrawLayer("OVERLAY")

    local lvl_str = OzUF:get_unit_level_text("target")
    local lr, lg, lb = OzUF:get_level_color("target")
    tLevel:SetText(lvl_str)
    tLevel:SetTextColor(lr, lg, lb)
    tLevel:Show()

    if TargetHighLevelTexture then
        TargetHighLevelTexture:Hide()
    end
end

function OzUF.Target:apply_texture()
    if not TargetFrameTexture then return end
    if OzUF_DB and OzUF_DB.hide_portraits then
        TargetFrameTexture:Hide()
        return
    end

    TargetFrameTexture:Show()
    local classification = UnitClassification("target")
    if classification == "worldboss" or classification == "elite" then
        TargetFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame-Elite.blp")
    elseif classification == "rareelite" or classification == "rare" then
        TargetFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame-Elite-Rare.blp")
    else
        TargetFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
    end
    TargetFrameTexture:SetTexCoord(0, 1, 0, 1)
    TargetFrameTexture:ClearAllPoints()
    TargetFrameTexture:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", 2, 2)
    TargetFrameTexture:SetWidth(256)
    TargetFrameTexture:SetHeight(128)

    if TargetFrameFlash then
        TargetFrameFlash:ClearAllPoints()
        TargetFrameFlash:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", 2, 2)
        TargetFrameFlash:SetWidth(256)
        TargetFrameFlash:SetHeight(128)
        TargetFrameFlash:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
        TargetFrameFlash:SetTexCoord(0, 1, 0, 1)
        TargetFrameFlash:SetBlendMode("ADD")
    end
end

function OzUF.Target:update_health_text()
    local hp_text = OzUF.Target:get_health_text_element()
    local t_pct = OzUF.Target:get_percent_text_element()
    if not hp_text then return end

    if not UnitExists("target") then
        hp_text:Hide()
        if t_pct then
            t_pct:Hide()
        end
        return
    end

    local cur, max = OzUF:get_unit_health_data("target")
    local pct_str, hp_str = OzUF:format_health_parts("target", cur, max)

    hp_text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    hp_text:SetText(hp_str)
    hp_text:Show()

    if t_pct then
        t_pct:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        t_pct:SetText(pct_str)
        t_pct:Show()
    end
end

function OzUF.Target:apply_target_name()
    if not UnitExists("target") then return end

    -- Line 1: Target Name inside Health Bar (horizontally centered)
    local tName = OzUF.Target:get_name_element()
    if tName and TargetFrameHealthBar then
        tName.Show = nil
        tName:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        tName:ClearAllPoints()
        tName:SetPoint("TOP", TargetFrameHealthBar, "TOP", 0, -2)
        tName:SetWidth(120)
        tName:SetHeight(12)
        tName:SetJustifyH("CENTER")
        tName:SetDrawLayer("OVERLAY")
        tName:Show()

        if UnitIsPlayer("target") then
            local _, class_token = UnitClass("target")
            local color = OzUF.CLASS_COLORS and OzUF.CLASS_COLORS[class_token]
            if color then
                tName:SetTextColor(color.r, color.g, color.b)
            end
        else
            local reaction = UnitReaction("target", "player")
            if reaction and reaction <= 2 then
                tName:SetTextColor(1, 0.2, 0.2)
            elseif reaction and reaction <= 4 then
                tName:SetTextColor(1, 1, 0.2)
            else
                tName:SetTextColor(0.2, 1, 0.2)
            end
        end
    end

    -- Update target level on TargetFrameTextureFrameLevelText (portrait badge)
    OzUF.Target:update_level()

    if TargetFrameNameBackground then
        TargetFrameNameBackground:Hide()
    end
end

function OzUF.Target:apply_double_health()
    if not OzUF_DB or not OzUF_DB.double_health then return end

    local hide_p = OzUF_DB and OzUF_DB.hide_portraits

    if TargetFrameHealthBar then
        TargetFrameHealthBar:SetHeight(29)
        TargetFrameHealthBar:ClearAllPoints()

        if hide_p then
            TargetFrameHealthBar:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -16, -22)
            TargetFrameHealthBar:SetWidth(180)
        else
            -- 5px closer to portrait (-101 instead of -106) with width 124 to connect seamlessly
            TargetFrameHealthBar:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -101, -22)
            TargetFrameHealthBar:SetWidth(124)
        end

        -- Match TargetFrameBackground to health bar height so corpses don't show old thin height
        if TargetFrameBackground then
            TargetFrameBackground:ClearAllPoints()
            TargetFrameBackground:SetAllPoints(TargetFrameHealthBar)
            TargetFrameBackground:SetDrawLayer("BACKGROUND")
            TargetFrameBackground:Show()
        end

        -- Align TargetFrameFlash to frame border with UI-TargetingFrame-Flash
        if TargetFrameFlash then
            TargetFrameFlash:ClearAllPoints()
            if hide_p then
                TargetFrameFlash:Hide()
            else
                TargetFrameFlash:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", 2, 2)
                TargetFrameFlash:SetWidth(256)
                TargetFrameFlash:SetHeight(128)
                TargetFrameFlash:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
                TargetFrameFlash:SetTexCoord(0, 1, 0, 1)
                TargetFrameFlash:SetBlendMode("ADD")
            end
        end

        -- Line 2: Current/max aligned right
        local hp_text = OzUF.Target:get_health_text_element()
        if hp_text then
            hp_text.Show = nil
            hp_text:ClearAllPoints()
            hp_text:SetPoint("BOTTOMRIGHT", TargetFrameHealthBar, "BOTTOMRIGHT", -4, 7)
            hp_text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            hp_text:SetTextColor(1, 1, 1)
            hp_text:SetJustifyH("RIGHT")
            hp_text:SetDrawLayer("OVERLAY")
            hp_text:Show()
        end

        -- Line 2: Percentage aligned left
        local t_pct = OzUF.Target:get_percent_text_element()
        if t_pct then
            t_pct.Show = nil
            t_pct:ClearAllPoints()
            t_pct:SetPoint("BOTTOMLEFT", TargetFrameHealthBar, "BOTTOMLEFT", 4, 7)
            t_pct:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            t_pct:SetTextColor(1, 1, 1)
            t_pct:SetJustifyH("LEFT")
            t_pct:SetDrawLayer("OVERLAY")
            t_pct:Show()
        end

        -- Hide Blizzard's duplicate Dead text and external MobHealth texts so OzUF handles it cleanly
        if TargetDeadText then
            suppress_show(TargetDeadText)
        end
        if MobHealthText then
            suppress_show(MobHealthText)
        end
        if MobHealth3Text then
            suppress_show(MobHealth3Text)
        end

        -- Move TargetFrameManaBar down below the 29px health bar, also connected seamlessly
        if TargetFrameManaBar then
            TargetFrameManaBar:ClearAllPoints()
            TargetFrameManaBar:SetPoint("TOPRIGHT", TargetFrameHealthBar, "BOTTOMRIGHT", 0, -1)
            TargetFrameManaBar:SetHeight(9)
            if hide_p then
                TargetFrameManaBar:SetWidth(180)
            else
                TargetFrameManaBar:SetWidth(124)
            end
        end
    end

    if TargetPortrait then
        if hide_p then
            TargetPortrait:Hide()
        else
            TargetPortrait:Show()
            TargetPortrait:ClearAllPoints()
            TargetPortrait:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -40, -9)
            TargetPortrait:SetWidth(64)
            TargetPortrait:SetHeight(64)
        end
    end

    OzUF.Target:apply_target_name()
end

function OzUF.Target:apply_portrait_mode()
    if not OzUF_DB then return end
    OzUF.Target:apply_double_health()
    OzUF.Target:apply_texture()
end

function OzUF.Target:apply_scale()
    if not OzUF_DB or not OzUF_DB.scales then return end
    local s = OzUF_DB.scales
    if TargetFrame and s.target then TargetFrame:SetScale(s.target) end
end

function OzUF.Target:update()
    if not UnitExists("target") then return end
    OzUF.Target:apply_double_health()
    OzUF.Target:update_health_text()
    OzUF.Target:apply_target_name()
    OzUF.Target:apply_texture()
end

-- Hook TargetFrame_CheckClassification to apply custom type-based background
if TargetFrame_CheckClassification then
    local orig_TargetFrame_CheckClassification = TargetFrame_CheckClassification
    TargetFrame_CheckClassification = function()
        orig_TargetFrame_CheckClassification()
        OzUF.Target:apply_texture()
    end
end

-- Hook TargetFrame_CheckDead to keep health bar 29px and prevent corpse from shrinking background
if TargetFrame_CheckDead then
    local orig_TargetFrame_CheckDead = TargetFrame_CheckDead
    TargetFrame_CheckDead = function()
        orig_TargetFrame_CheckDead()
        if OzUF.Target and OzUF.Target.update then
            OzUF.Target:update()
        end
        if TargetDeadText then
            suppress_show(TargetDeadText)
        end
    end
end

-- Hook TargetFrame_CheckLevel to maintain custom font, color, and outline on level badge
if TargetFrame_CheckLevel then
    local orig_TargetFrame_CheckLevel = TargetFrame_CheckLevel
    TargetFrame_CheckLevel = function()
        orig_TargetFrame_CheckLevel()
        if OzUF.Target and OzUF.Target.update_level then
            OzUF.Target:update_level()
        end
    end
end

-- Hook TargetFrame_Update to refresh 2-line display, health text, and textures
if TargetFrame_Update then
    local orig_TargetFrame_Update = TargetFrame_Update
    TargetFrame_Update = function()
        orig_TargetFrame_Update()
        OzUF.Target:update()
    end
end
