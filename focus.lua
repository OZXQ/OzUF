--[[
    OzUF - Focus Module (focus.lua)
    Pure Lua FocusFrame for WoW 1.12:
    - Movable Focus Frame (OzUFFocusFrame)
    - Custom frame background texture (UI-TargetingFrame2.blp at 256x128 with SetTexCoord(1, 0, 0, 1))
    - 29px Health bar with 2-line text
    - Level display on portrait badge (OzUFFocusFrameTextureFrameLevelText)
    - Proper green health bar color
    - Portrait toggle (Compact bar mode)
    - Frame scaling
    - Slash commands: /focus, /clearfocus
    - Seamless 101px offset connecting directly to portrait
]]--

local _G = getfenv(0)
OzUF.Focus = {}
OzUF.Focus.name = nil
OzUF.Focus.unit = nil

function OzUF.Focus:apply_texture()
    if not OzUFFocusFrameTexture then return end
    if OzUF_DB and OzUF_DB.hide_portraits then
        OzUFFocusFrameTexture:Hide()
        return
    end

    OzUFFocusFrameTexture:Show()
    local active_unit = OzUF.Focus.unit
    local classification = (active_unit and UnitExists(active_unit) and UnitClassification(active_unit)) or OzUF.Focus.classification
    if classification == "worldboss" or classification == "elite" then
        OzUFFocusFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame-Elite.blp")
    elseif classification == "rareelite" or classification == "rare" then
        OzUFFocusFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame-Elite-Rare.blp")
    else
        OzUFFocusFrameTexture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
    end
    OzUFFocusFrameTexture:SetTexCoord(1, 0, 0, 1)
    OzUFFocusFrameTexture:ClearAllPoints()
    OzUFFocusFrameTexture:SetPoint("TOPLEFT", OzUFFocusFrame, "TOPLEFT", -2, 2)
    OzUFFocusFrameTexture:SetWidth(256)
    OzUFFocusFrameTexture:SetHeight(128)
end

function OzUF.Focus:apply_strata()
    if not OzUFFocusFrame then return end
    local strata = (PlayerFrame and PlayerFrame:GetFrameStrata()) or (TargetFrame and TargetFrame:GetFrameStrata()) or "LOW"
    OzUFFocusFrame:SetFrameStrata(strata)
end

function OzUF.Focus:create_frame()
    if OzUFFocusFrame then return end

    local f = CreateFrame("Button", "OzUFFocusFrame", UIParent)
    f:SetWidth(232)
    f:SetHeight(100)
    local strata = (PlayerFrame and PlayerFrame:GetFrameStrata()) or (TargetFrame and TargetFrame:GetFrameStrata()) or "LOW"
    f:SetFrameStrata(strata)
    f:SetToplevel(true)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -180)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:Hide()

    -- Portrait (64x64 in BACKGROUND layer)
    local portrait = f:CreateTexture("OzUFFocusPortrait", "BACKGROUND")
    portrait:SetWidth(64)
    portrait:SetHeight(64)
    portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -9)
    f.portrait = portrait

    -- HealthBar (29px height, 124px width, offset 101 connecting directly to portrait)
    local hb = CreateFrame("StatusBar", "OzUFFocusFrameHealthBar", f)
    hb:SetHeight(29)
    hb:SetWidth(124)
    hb:SetPoint("TOPLEFT", f, "TOPLEFT", 101, -22)
    hb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hb:SetStatusBarColor(0.0, 0.85, 0.1) -- Clean green health bar
    f.health_bar = hb

    -- ManaBar (9px height, 124px width)
    local mb = CreateFrame("StatusBar", "OzUFFocusFrameManaBar", f)
    mb:SetHeight(9)
    mb:SetWidth(124)
    mb:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -1)
    mb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    mb:SetStatusBarColor(0.2, 0.4, 0.9)
    f.mana_bar = mb

    -- Background Frame Texture Container (Frame level hb + 1)
    local texture_frame = CreateFrame("Frame", "OzUFFocusTextureFrame", f)
    texture_frame:SetAllPoints(f)
    texture_frame:SetFrameLevel(hb:GetFrameLevel() + 1)
    texture_frame:EnableMouse(false)

    local texture = texture_frame:CreateTexture("OzUFFocusFrameTexture", "ARTWORK")
    texture:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    texture:SetWidth(256)
    texture:SetHeight(128)
    texture:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
    texture:SetTexCoord(1, 0, 0, 1)
    f.texture = texture

    -- Level FontString on the portrait circle badge (mirrored bottom-left, matching PlayerLevelText)
    local level_fs = texture_frame:CreateFontString("OzUFFocusFrameTextureFrameLevelText", "OVERLAY")
    level_fs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    level_fs:SetPoint("CENTER", f, "CENTER", -63, -15)
    OzUFFocusLevelText = level_fs
    OzUFFocusFrameTextureFrameLevelText = level_fs
    f.level_text = level_fs

    -- Text overlay (Frame level hb + 2, sits above texture_frame)
    OzUF:create_health_bar_texts(f, hb, "focus")

    -- Target clicking behavior: Target by saved name cleanly
    f:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            OzUF.Focus:clear()
        else
            if OzUF.Focus.name then
                TargetByName(OzUF.Focus.name, true)
            end
        end
    end)

    -- Tooltip on hover
    f:SetScript("OnEnter", function()
        if OzUF.Focus.name then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(OzUF.Focus.name, 1, 1, 1)
            GameTooltip:AddLine("Left-click to target. Right-click to clear focus.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function OzUF.Focus:get_level_element()
    return OzUFFocusFrameTextureFrameLevelText 
        or OzUFFocusLevelText 
        or (OzUFFocusFrame and OzUFFocusFrame.level_text)
end

function OzUF.Focus:update_level(unit)
    local fLevel = OzUF.Focus:get_level_element()
    if not fLevel then return end

    if OzUF_DB and OzUF_DB.hide_portraits then
        fLevel:Hide()
        return
    end

    if not OzUF.Focus.name then
        fLevel:SetText("")
        fLevel:Hide()
        return
    end

    if unit and UnitExists(unit) then
        local lvl_str = OzUF:get_unit_level_text(unit)
        local lr, lg, lb = OzUF:get_level_color(unit)
        OzUF.Focus.level_str = lvl_str
        OzUF.Focus.level_color = {r = lr, g = lg, b = lb}
    end

    local lvl_str = OzUF.Focus.level_str or "??"
    local color = OzUF.Focus.level_color or {r = 1, g = 1, b = 1}

    fLevel:ClearAllPoints()
    fLevel:SetPoint("CENTER", OzUFFocusFrame, "CENTER", -63, -15)
    fLevel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    fLevel:SetDrawLayer("OVERLAY")
    fLevel:SetText(lvl_str)
    fLevel:SetTextColor(color.r, color.g, color.b)
    fLevel:Show()
end

function OzUF.Focus:update()
    if not OzUFFocusFrame or not OzUFFocusFrame:IsShown() then return end
    OzUF.Focus:apply_strata()

    local active_unit = nil
    local name_to_find = OzUF.Focus.name

    if name_to_find then
        local candidates = {
            "target", "targettarget", "mouseover",
            "party1", "party2", "party3", "party4",
            "partypet1", "partypet2", "partypet3", "partypet4",
            "party1target", "party2target", "party3target", "party4target",
            "pet"
        }
        for _, token in ipairs(candidates) do
            local cap_token = token
            if UnitExists(cap_token) and UnitName(cap_token) == name_to_find then
                active_unit = cap_token
                break
            end
        end

        if not active_unit and GetNumRaidMembers and GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local r_token = "raid" .. i
                if UnitExists(r_token) and UnitName(r_token) == name_to_find then
                    active_unit = r_token
                    break
                end
                local rt_token = "raid" .. i .. "target"
                if UnitExists(rt_token) and UnitName(rt_token) == name_to_find then
                    active_unit = rt_token
                    break
                end
            end
        end
    end

    if active_unit then
        OzUF.Focus.unit = active_unit
        OzUF.focus_unit = active_unit

        -- Update portrait
        SetPortraitTexture(OzUFFocusPortrait, active_unit)

        -- Health & Bar
        local cur_hp, max_hp = OzUF:get_unit_health_data(active_unit)
        OzUF.Focus.cur_hp = cur_hp
        OzUF.Focus.max_hp = max_hp
        local pct_str, hp_str = OzUF:format_health_parts(active_unit, cur_hp, max_hp)
        OzUF.Focus.pct_str = pct_str
        OzUF.Focus.hp_str = hp_str
        OzUFFocusFrameHealthBar:SetMinMaxValues(0, max_hp)
        OzUFFocusFrameHealthBar:SetValue(cur_hp)

        -- Standard green health bar color
        OzUFFocusFrameHealthBar:SetStatusBarColor(0.0, 0.85, 0.1)

        -- Level display on portrait badge (OzUFFocusFrameTextureFrameLevelText)
        OzUF.Focus:update_level(active_unit)

        -- Mana & Bar
        local cur_mana = UnitMana(active_unit)
        local max_mana = UnitManaMax(active_unit)
        local power_type = UnitPowerType(active_unit)
        OzUF.Focus.cur_mana = cur_mana
        OzUF.Focus.max_mana = max_mana
        OzUF.Focus.power_type = power_type

        OzUFFocusFrameManaBar:SetMinMaxValues(0, max_mana)
        OzUFFocusFrameManaBar:SetValue(cur_mana)

        if power_type == 1 then
            OzUFFocusFrameManaBar:SetStatusBarColor(0.9, 0.2, 0.2) -- Rage
        elseif power_type == 2 then
            OzUFFocusFrameManaBar:SetStatusBarColor(0.9, 0.5, 0.1) -- Focus
        elseif power_type == 3 then
            OzUFFocusFrameManaBar:SetStatusBarColor(0.9, 0.9, 0.2) -- Energy
        else
            OzUFFocusFrameManaBar:SetStatusBarColor(0.2, 0.4, 0.9) -- Mana
        end

        if UnitIsPlayer(active_unit) then
            local _, class_token = UnitClass(active_unit)
            OzUF.Focus.color = OzUF.CLASS_COLORS and OzUF.CLASS_COLORS[class_token]
        else
            local reaction = UnitReaction(active_unit, "player")
            if reaction and reaction <= 2 then
                OzUF.Focus.color = {r = 1, g = 0.2, b = 0.2}
            elseif reaction and reaction <= 4 then
                OzUF.Focus.color = {r = 1, g = 1, b = 0.2}
            else
                OzUF.Focus.color = {r = 0.2, g = 1, b = 0.2}
            end
        end

        -- Update 2-line text overlay
        OzUF:update_health_bar_texts(OzUFFocusFrameHealthBar, active_unit)

        -- Update texture based on classification
        OzUF.Focus.classification = UnitClassification(active_unit)
        OzUF.Focus:apply_texture()
    else
        -- Not in direct scan range: retain last known data, do NOT clear or sync with target
        if OzUF.Focus.name and OzUFFocusFrameHealthBar.ozuf_texts then
            local texts = OzUFFocusFrameHealthBar.ozuf_texts
            texts.overlay:Show()
            texts.name:ClearAllPoints()
            texts.name:SetPoint("TOP", OzUFFocusFrameHealthBar, "TOP", 0, -2)
            texts.name:SetWidth(120)
            texts.name:SetHeight(12)
            texts.name:SetJustifyH("CENTER")
            texts.name:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
            texts.name:SetText(OzUF.Focus.name)
            if OzUF.Focus.color then
                texts.name:SetTextColor(OzUF.Focus.color.r, OzUF.Focus.color.g, OzUF.Focus.color.b)
            end

            -- Retain formatted health percentage and value (same format as target)
            local pct_str = OzUF.Focus.pct_str
            local hp_str = OzUF.Focus.hp_str
            if (not hp_str or not pct_str) and OzUF.Focus.cur_hp and OzUF.Focus.max_hp then
                pct_str, hp_str = OzUF:format_health_parts("target", OzUF.Focus.cur_hp, OzUF.Focus.max_hp)
            end
            if texts.percent then
                texts.percent:ClearAllPoints()
                texts.percent:SetPoint("BOTTOMLEFT", OzUFFocusFrameHealthBar, "BOTTOMLEFT", 4, 7)
                texts.percent:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                texts.percent:SetJustifyH("LEFT")
                texts.percent:SetText(pct_str or "")
                texts.percent:Show()
            end
            texts.health:ClearAllPoints()
            texts.health:SetPoint("BOTTOMRIGHT", OzUFFocusFrameHealthBar, "BOTTOMRIGHT", -4, 7)
            texts.health:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            texts.health:SetJustifyH("RIGHT")
            texts.health:SetText(hp_str or "")
            texts.health:Show()

            if OzUF.Focus.cur_hp and OzUF.Focus.max_hp then
                OzUFFocusFrameHealthBar:SetMinMaxValues(0, OzUF.Focus.max_hp)
                OzUFFocusFrameHealthBar:SetValue(OzUF.Focus.cur_hp)
            end
        end
        OzUFFocusFrameHealthBar:SetStatusBarColor(0.0, 0.85, 0.1)
        OzUF.Focus:update_level(nil)
        OzUF.Focus:apply_texture()
    end
end

function OzUF.Focus:set(unit)
    local target_unit = unit or "target"
    if not UnitExists(target_unit) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r No valid unit to set focus on.")
        return
    end

    OzUF.Focus.name = UnitName(target_unit)
    OzUF.focus_name = OzUF.Focus.name
    OzUF.Focus.unit = target_unit

    -- Cache level information
    local lvl_str = OzUF:get_unit_level_text(target_unit)
    local lr, lg, lb = OzUF:get_level_color(target_unit)
    OzUF.Focus.level_str = lvl_str
    OzUF.Focus.level_color = {r = lr, g = lg, b = lb}

    -- Cache health and mana
    local cur_hp, max_hp = OzUF:get_unit_health_data(target_unit)
    OzUF.Focus.cur_hp = cur_hp
    OzUF.Focus.max_hp = max_hp
    local pct_str, hp_str = OzUF:format_health_parts(target_unit, cur_hp, max_hp)
    OzUF.Focus.pct_str = pct_str
    OzUF.Focus.hp_str = hp_str

    OzUF.Focus.cur_mana = UnitMana(target_unit)
    OzUF.Focus.max_mana = UnitManaMax(target_unit)
    OzUF.Focus.power_type = UnitPowerType(target_unit)
    OzUF.Focus.classification = UnitClassification(target_unit)

    if UnitIsPlayer(target_unit) then
        local _, class_token = UnitClass(target_unit)
        OzUF.Focus.color = OzUF.CLASS_COLORS and OzUF.CLASS_COLORS[class_token]
    else
        local reaction = UnitReaction(target_unit, "player")
        if reaction and reaction <= 2 then
            OzUF.Focus.color = {r = 1, g = 0.2, b = 0.2}
        elseif reaction and reaction <= 4 then
            OzUF.Focus.color = {r = 1, g = 1, b = 0.2}
        else
            OzUF.Focus.color = {r = 0.2, g = 1, b = 0.2}
        end
    end

    OzUF.Focus:create_frame()
    SetPortraitTexture(OzUFFocusPortrait, target_unit)
    OzUFFocusFrame:Show()
    OzUF.Focus:update()
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Focus set to: |cffffff00" .. OzUF.Focus.name .. "|r")
end

function OzUF.Focus:clear()
    OzUF.Focus.name = nil
    OzUF.Focus.unit = nil
    OzUF.Focus.level_str = nil
    OzUF.Focus.level_color = nil
    OzUF.Focus.cur_hp = nil
    OzUF.Focus.max_hp = nil
    OzUF.Focus.hp_str = nil
    OzUF.Focus.pct_str = nil
    OzUF.Focus.color = nil
    OzUF.Focus.classification = nil
    OzUF.focus_name = nil
    OzUF.focus_unit = nil
    OzUF.Focus:update_level(nil)
    if OzUFFocusFrame then
        OzUFFocusFrame:Hide()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Focus cleared.")
end

function OzUF.Focus:apply_portrait_mode()
    if not OzUF_DB then return end
    OzUF.Focus:apply_strata()
    local hide_p = OzUF_DB.hide_portraits
    local fLevel = OzUF.Focus:get_level_element()

    if OzUFFocusPortrait and OzUFFocusFrameHealthBar then
        if hide_p then
            OzUFFocusPortrait:Hide()
            if OzUFFocusFrameTexture then OzUFFocusFrameTexture:Hide() end
            if fLevel then fLevel:Hide() end
            OzUFFocusFrameHealthBar:ClearAllPoints()
            OzUFFocusFrameHealthBar:SetPoint("TOPLEFT", OzUFFocusFrame, "TOPLEFT", 16, -22)
            OzUFFocusFrameHealthBar:SetWidth(180)
            OzUFFocusFrameHealthBar:SetHeight(29)
            OzUFFocusFrameManaBar:ClearAllPoints()
            OzUFFocusFrameManaBar:SetPoint("TOPLEFT", OzUFFocusFrameHealthBar, "BOTTOMLEFT", 0, -1)
            OzUFFocusFrameManaBar:SetWidth(180)
            OzUFFocusFrameManaBar:SetHeight(9)
        else
            OzUFFocusPortrait:Show()
            OzUFFocusPortrait:ClearAllPoints()
            OzUFFocusPortrait:SetPoint("TOPLEFT", OzUFFocusFrame, "TOPLEFT", 40, -9)
            OzUFFocusPortrait:SetWidth(64)
            OzUFFocusPortrait:SetHeight(64)
            if OzUFFocusFrameTexture then
                OzUFFocusFrameTexture:Show()
                OzUF.Focus:apply_texture()
            end
            if fLevel then
                fLevel:ClearAllPoints()
                fLevel:SetPoint("CENTER", OzUFFocusFrame, "CENTER", -63, -15)
                fLevel:Show()
            end
            OzUFFocusFrameHealthBar:ClearAllPoints()
            OzUFFocusFrameHealthBar:SetPoint("TOPLEFT", OzUFFocusFrame, "TOPLEFT", 101, -22)
            OzUFFocusFrameHealthBar:SetWidth(124)
            OzUFFocusFrameHealthBar:SetHeight(29)
            OzUFFocusFrameManaBar:ClearAllPoints()
            OzUFFocusFrameManaBar:SetPoint("TOPLEFT", OzUFFocusFrameHealthBar, "BOTTOMLEFT", 0, -1)
            OzUFFocusFrameManaBar:SetWidth(124)
            OzUFFocusFrameManaBar:SetHeight(9)
        end
    end
end

function OzUF.Focus:apply_scale()
    if not OzUF_DB or not OzUF_DB.scales then return end
    local s = OzUF_DB.scales
    if OzUFFocusFrame and s.focus then OzUFFocusFrame:SetScale(s.focus) end
end

-- Backward compatibility aliases on OzUF
function OzUF:set_focus(unit)
    OzUF.Focus:set(unit)
end

function OzUF:clear_focus()
    OzUF.Focus:clear()
end

function OzUF:update_focus_frame()
    OzUF.Focus:update()
end

-- Register Slash Commands
SLASH_OZUFFOCUS1 = "/focus"
SlashCmdList["OZUFFOCUS"] = function(msg)
    OzUF.Focus:set("target")
end

SLASH_OZUCLEARFOCUS1 = "/clearfocus"
SlashCmdList["OZUCLEARFOCUS"] = function(msg)
    OzUF.Focus:clear()
end
