--[[
    OzUF - Core & Shared Utilities
    WoW 1.12.1 / Vanilla / Turtle WoW / SuperWoW
]] --

OzUF = {}
local _G = getfenv(0)

-- Textures
OzUF.TEX_NORMAL = "Interface\\AddOns\\OzUF\\texture\\targetframe_normal.blp"
OzUF.TEX_ELITE = "Interface\\AddOns\\OzUF\\texture\\targetframe_elite.blp"
OzUF.TEX_RARE = "Interface\\AddOns\\OzUF\\texture\\targetframe_rare.blp"
OzUF.TEX_RARE_ELITE = "Interface\\AddOns\\OzUF\\texture\\targetframe_rareelite.blp"
OzUF.TEX_STATUS = "Interface\\AddOns\\OzUF\\texture\\frame_flash.blp"

-- Localization (zhCN & enUS)
local isZh = GetLocale() == "zhCN"
OzUF.L = {
    ["CANCEL_FOCUS"] = isZh and "取消焦点" or "Cancel Focus",
    ["SET_FOCUS"] = isZh and "设置焦点" or "Set Focus",
    ["LOCK_FOCUS"] = isZh and "锁定焦点框体" or "Lock Focus Frame",
    ["UNLOCK_FOCUS"] = isZh and "解锁焦点框体" or "Unlock Focus Frame",
    ["FOCUS_LOCKED"] = isZh and "焦点框体已锁定" or "Focus frame locked.",
    ["FOCUS_UNLOCKED"] = isZh and "焦点框体已解锁" or "Focus frame unlocked.",
    ["NO_TARGET_FOCUS"] = isZh and "请先选择一个目标以设置为焦点" or "Target a unit to set as focus.",
    ["FOCUS_SET"] = isZh and "焦点已设置为: " or "Focus set to: ",
}



OzUF.CLASS_ICON = {
    ["DRUID"] = "Interface\\AddOns\\OzUF\\texture\\class_druid.blp",
    ["HUNTER"] = "Interface\\AddOns\\OzUF\\texture\\class_hunter.blp",
    ["MAGE"] = "Interface\\AddOns\\OzUF\\texture\\class_mage.blp",
    ["PALADIN"] = "Interface\\AddOns\\OzUF\\texture\\class_paladin.blp",
    ["PRIEST"] = "Interface\\AddOns\\OzUF\\texture\\class_priest.blp",
    ["ROGUE"] = "Interface\\AddOns\\OzUF\\texture\\class_rogue.blp",
    ["SHAMAN"] = "Interface\\AddOns\\OzUF\\texture\\class_shaman.blp",
    ["WARLOCK"] = "Interface\\AddOns\\OzUF\\texture\\class_warlock.blp",
    ["WARRIOR"] = "Interface\\AddOns\\OzUF\\texture\\class_warrior.blp",
}

-------------------------------------------------------------------------------
-- Aura Button Reference Cache
-- Aura buttons are created once at load and afterwards only re-textured /
-- re-anchored (client FrameXML TargetDebuffButton_Update & RefreshBuffs never
-- CreateFrame), so object identity is stable and safe to cache. This removes
-- the ~600-900 string concatenations + getglobal performed on every refresh.
-------------------------------------------------------------------------------
OzUF.AuraButtons = OzUF.AuraButtons or {}
local auraState = {}

local function GetAuraGroup(prefix, maxCount, isDebuff)
    local arr = OzUF.AuraButtons[prefix]
    if not arr then
        arr = {}
        OzUF.AuraButtons[prefix] = arr
    end
    for i = 1, maxCount do
        if not arr[i] then
            arr[i] = {
                button = _G[prefix .. i],
                icon   = _G[prefix .. i .. "Icon"],
                count  = isDebuff and _G[prefix .. i .. "Count"],
                border = isDebuff and _G[prefix .. i .. "Border"],
            }
        end
    end
    return arr
end
OzUF.GetAuraGroup = GetAuraGroup

-- Drop cached references. Call after PLAYER_ENTERING_WORLD so we capture the
-- final objects instead of ones a later-loaded addon may have replaced.
function OzUF.ResetAuraCache(framePrefix)
    if not OzUF.AuraButtons then return end
    if framePrefix then
        OzUF.AuraButtons[framePrefix .. "Buff"] = nil
        OzUF.AuraButtons[framePrefix .. "Debuff"] = nil
        auraState[framePrefix] = nil
    else
        OzUF.AuraButtons = {}
        for k in pairs(auraState) do auraState[k] = nil end
    end
end

-------------------------------------------------------------------------------
-- Aura Arrangement & Update (Shared by TargetFrame & FocusFrame)
-------------------------------------------------------------------------------
function OzUF.ArrangeButtonGroup(prefix, count, startAnchor, isFirstGroup, firstRowCount, secondRowCount, thirdRowCount,
                                 laterRowCount, maxRows)
    if count < 1 then return nil, 0 end

    local rows = 1
    local currentRowCount = 1
    local rowStartIndex = 1

    local arr = OzUF.AuraButtons[prefix]

    for i = 1, count do
        local entry = arr and arr[i]
        local button = entry and entry.button or _G[prefix .. i]
        if button then
            button:ClearAllPoints()
            button:Show()

            local buttonsPerRow
            if rows == 1 then
                buttonsPerRow = firstRowCount
            elseif rows == 2 then
                buttonsPerRow = secondRowCount
            elseif rows == 3 then
                buttonsPerRow = thirdRowCount
            else
                buttonsPerRow = laterRowCount
            end

            if i == 1 then
                if type(startAnchor) == "string" then
                    if isFirstGroup then
                        button:SetPoint("BOTTOMLEFT", startAnchor, "TOPLEFT", 25, -20)
                    else
                        button:SetPoint("BOTTOMLEFT", startAnchor, "TOPLEFT", 0, 2)
                    end
                else
                    button:SetPoint("BOTTOMLEFT", startAnchor, "TOPLEFT", 0, 2)
                end
            else
                if currentRowCount >= buttonsPerRow then
                    rows = rows + 1
                    if rows > maxRows then
                        button:Hide()
                    else
                        currentRowCount = 1
                        rowStartIndex = i
                        local anchorEntry = arr and arr[i - buttonsPerRow]
                        local anchorButton = anchorEntry and anchorEntry.button or _G[prefix .. (i - buttonsPerRow)]
                        if anchorButton then
                            button:SetPoint("BOTTOMLEFT", anchorButton, "TOPLEFT", 0, 2)
                        end
                    end
                else
                    if rows <= maxRows then
                        local prevEntry = arr and arr[i - 1]
                        local prevButton = prevEntry and prevEntry.button or _G[prefix .. (i - 1)]
                        if prevButton then
                            button:SetPoint("LEFT", prevButton, "RIGHT", 3, 0)
                        end
                    else
                        button:Hide()
                    end
                    currentRowCount = currentRowCount + 1
                end
            end
        end
    end

    if count > 0 then
        local lastEntry = arr and arr[rowStartIndex]
        return lastEntry and lastEntry.button or _G[prefix .. rowStartIndex], rows
    end
    return nil, 0
end

function OzUF.UpdateAuras(unit, framePrefix, maxBuffs, maxDebuffs)
    maxBuffs = maxBuffs or 32
    maxDebuffs = maxDebuffs or 32

    local buffKey = framePrefix .. "Buff"
    local debuffKey = framePrefix .. "Debuff"
    local buffArr = GetAuraGroup(buffKey, maxBuffs, false)
    local debArr = GetAuraGroup(debuffKey, maxDebuffs, true)

    local st = auraState[framePrefix]
    if not st then
        st = { nb = -1, nd = -1, friend = nil }
        auraState[framePrefix] = st
    end

    -- Unit gone: hide what is currently shown, then bail out
    if not unit or not UnitExists(unit) then
        if st.nb == 0 and st.nd == 0 then return end
        for i = 1, ((st.nb < 0) and maxBuffs or st.nb) do
            local b = buffArr[i].button
            if b then
                b:ClearAllPoints()
                b:Hide()
            end
        end
        for i = 1, ((st.nd < 0) and maxDebuffs or st.nd) do
            local b = debArr[i].button
            if b then
                b:ClearAllPoints()
                b:Hide()
            end
        end
        st.nb, st.nd, st.friend = 0, 0, nil
        return
    end

    local num_buff = 0
    local num_debuff = 0

    -- Icons / counts / borders, breaking on the first empty slot instead of
    -- always sweeping the full 64 / 128 range
    for i = 1, maxBuffs do
        local buff = UnitBuff(unit, i)
        if not buff then break end
        num_buff = i
        local e = buffArr[i]
        if e.icon and e.icon:GetTexture() ~= buff then
            e.icon:SetTexture(buff)
        end
        -- Client TargetBuffButtonTemplate OnEnter calls SetUnitBuff("target", this.id),
        -- it reads the .id field (not GetID()), so it must be kept in sync here.
        if e.button then e.button.id = i end
    end

    for i = 1, maxDebuffs do
        local debuff, debuffApplications, debuffType = UnitDebuff(unit, i)
        if not debuff then break end
        num_debuff = i
        local e = debArr[i]
        if e.icon and e.icon:GetTexture() ~= debuff then
            e.icon:SetTexture(debuff)
        end
        if e.count then
            if debuffApplications and debuffApplications > 1 then
                e.count:SetText(debuffApplications)
                e.count:Show()
            else
                e.count:Hide()
            end
        end
        if e.border and DebuffTypeColor then
            local color = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor["none"]
            e.border:SetVertexColor(color.r, color.g, color.b)
        end
        -- Client TargetDebuffButtonTemplate OnEnter reads this.id too
        if e.button then e.button.id = i end
    end

    -- Hide only the tail that shrank (full sweep on the very first call only)
    local hideFromBuff = (st.nb < 0) and 1 or (num_buff + 1)
    local hideToBuff = (st.nb < 0) and maxBuffs or st.nb
    for i = hideFromBuff, hideToBuff do
        local b = buffArr[i].button
        if b then b:Hide() end
    end

    local hideFromDebuff = (st.nd < 0) and 1 or (num_debuff + 1)
    local hideToDebuff = (st.nd < 0) and maxDebuffs or st.nd
    for i = hideFromDebuff, hideToDebuff do
        local b = debArr[i].button
        if b then b:Hide() end
    end

    local isFriend = UnitIsFriend("player", unit) and true or false

    -- Dirty check: re-anchoring is the expensive part, skip when nothing changed.
    -- friend is tracked too, since flipping between enemy/friend reorders the rows.
    if num_buff == st.nb and num_debuff == st.nd and isFriend == st.friend then return end
    st.nb, st.nd, st.friend = num_buff, num_debuff, isFriend

    if isFriend then
        local lastBuffRowStart = OzUF.ArrangeButtonGroup(buffKey, num_buff, framePrefix, true, 8, 8, 8, 8, 8)
        if num_debuff > 0 then
            OzUF.ArrangeButtonGroup(debuffKey, num_debuff, lastBuffRowStart or framePrefix,
                lastBuffRowStart == nil, 12, 12, 12, 12, 8)
        end
    else
        local lastDebuffRowStart = OzUF.ArrangeButtonGroup(debuffKey, num_debuff, framePrefix, true, 4, 4, 4, 12, 8)
        if num_buff > 0 then
            OzUF.ArrangeButtonGroup(buffKey, num_buff, lastDebuffRowStart or framePrefix,
                lastDebuffRowStart == nil, 8, 8, 8, 8, 8)
        end
    end
end

OzUF.status_text_font = OzUF.status_text_font or CreateFont("StatusTextFont")
OzUF.status_text_font:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
OzUF.status_text_font:SetTextColor(1, 1, 1, 1)


-- Number rounding
function OzUF.round(input, places)
    if not places then places = 0 end
    if type(input) == "number" and type(places) == "number" then
        local pow = 1
        for i = 1, places do pow = pow * 10 end
        return math.floor(input * pow + 0.5) / pow
    end
    return input
end

-- Number abbreviation (1.2k, 1.5m)
function OzUF.Abbreviate(number, eachk)
    if not number then return "" end
    local sign = number < 0 and -1 or 1
    number = math.abs(number)

    if number > 1000000 then
        return OzUF.round(number / 1000000 * sign, 2) .. "m"
    elseif not eachk and number > 10000 then
        return OzUF.round(number / 1000 * sign, 2) .. "k"
    elseif eachk and number > 1000 then
        return OzUF.round(number / 1000 * sign, 2) .. "k"
    end

    return number
end

-- Update portrait to class icon if unit is player
function OzUF.UpdateClassPortrait(frame)
    if not frame or not frame.portrait or not frame.unit then return end
    local _, class = UnitClass(frame.unit)
    if UnitIsPlayer(frame.unit) and class and OzUF.CLASS_ICON[class] then
        frame.portrait:SetTexture(OzUF.CLASS_ICON[class])
        frame.portrait:SetTexCoord(0, 1, 0, 1)
    else
        frame.portrait:SetTexCoord(0, 1, 0, 1)
        SetPortraitTexture(frame.portrait, frame.unit)
    end
end

-- Safe reaction and class color resolver for WoW 1.12 (UnitSelectionColor replacement)
function OzUF.GetUnitReactionColor(unit)
    if not unit or not UnitExists(unit) then
        return 0.5, 0.5, 0.5
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    end

    local reaction = UnitReaction(unit, "player")
    if reaction then
        if reaction >= 5 then
            return 0.0, 1.0, 0.0
        elseif reaction == 4 then
            return 1.0, 1.0, 0.0
        else
            return 1.0, 0.0, 0.0
        end
    end

    if UnitCanAttack("player", unit) then
        return 1.0, 0.0, 0.0
    elseif UnitIsFriend("player", unit) then
        return 0.0, 1.0, 0.0
    end

    return 0.5, 0.5, 0.5
end

-------------------------------------------------------------------------------
-- LibHealth (Mob health estimation cloned from ShaguTweaks libhealth)
-------------------------------------------------------------------------------
local mobdb = {}
local target, dmg, perc, diff = nil, 0, 0, 0, 0
local libhealth = CreateFrame("Frame")
libhealth.enabled = true
libhealth.reqhit = 2
libhealth.reqdmg = 10

libhealth:RegisterEvent("UNIT_HEALTH")
libhealth:RegisterEvent("UNIT_COMBAT")
libhealth:RegisterEvent("PLAYER_TARGET_CHANGED")
libhealth:RegisterEvent("PLAYER_ENTERING_WORLD")

libhealth:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        OzUF_DB = OzUF_DB or {}
        OzUF_DB["libhealth"] = OzUF_DB["libhealth"] or {}
        mobdb = OzUF_DB["libhealth"]
    elseif event == "PLAYER_TARGET_CHANGED" then
        dmg, perc = 0, UnitHealth("target")
        if UnitName("target") and UnitLevel("target") and UnitHealthMax("target") == 100 then
            target = string.format("%s:%d", UnitName("target"), UnitLevel("target"))
        else
            target = nil
        end
    elseif target and event == "UNIT_COMBAT" and arg1 == "target" then
        if arg2 and arg2 == "HEAL" then return end
        if arg4 and arg4 > 0 then
            dmg = dmg + arg4
        end
    elseif target and event == "UNIT_HEALTH" and arg1 == "target" then
        diff = perc - UnitHealth("target")
        if dmg > 0 and diff > 0 then
            mobdb[target] = mobdb[target] or {}
            if not mobdb[target][2] or diff > mobdb[target][2] then
                mobdb[target][1] = math.ceil(dmg / diff * 100)
                mobdb[target][2] = diff
                mobdb[target][3] = mobdb[target][3] and mobdb[target][3] + 1 or 1
            end
        end
    end
end)

function libhealth:GetUnitHealth(unitstr)
    local cur = UnitHealth(unitstr)
    local max = UnitHealthMax(unitstr)

    if cur > 100 or max > 100 or max < 100 then
        return cur, max, true
    end

    local unit = UnitName(unitstr)
    local level = UnitLevel(unitstr)
    if not unit or not level then
        return cur, max
    end

    local dbstring = string.format("%s:%s", unit, level)
    if mobdb[dbstring] and mobdb[dbstring][1] and mobdb[dbstring][2] > libhealth.reqdmg and (not mobdb[dbstring][3] or mobdb[dbstring][3] > libhealth.reqhit) then
        return math.ceil(mobdb[dbstring][1] / 100 * cur), mobdb[dbstring][1], true
    end

    return cur, max
end

OzUF.libhealth = libhealth

-------------------------------------------------------------------------------
-- TextStatusBar hook for health and mana numbers
-------------------------------------------------------------------------------
local HookTextStatusBar_UpdateTextString = TextStatusBar_UpdateTextString
function TextStatusBar_UpdateTextString(sb)
    if not sb then sb = this end
    if not sb then return end

    -- Only call Blizzard's original handler for default Blizzard status bars (e.g. PlayerFrame)
    local custom_bar = (sb == OzUFFocusFrameHealthBar or sb == OzUFFocusFrameManaBar
        or sb == TargetFrameHealthBar or sb == TargetFrameManaBar)

    local text_string = sb.TextString
    if (not text_string) or (not sb.unit) then
        if (not custom_bar) and HookTextStatusBar_UpdateTextString then
            pcall(HookTextStatusBar_UpdateTextString, sb)
        end
        return
    end

    local min, max = sb:GetMinMaxValues()
    local cur = sb:GetValue()
    cur = cur or 0
    max = max or 0

    if sb == TargetFrameHealthBar then
        if UnitIsPlayer(sb.unit) then
            cur = UnitHealth(sb.unit) or 0
            max = UnitHealthMax(sb.unit) or 0
        else
            cur, max = OzUF.libhealth:GetUnitHealth(sb.unit)
            cur = cur or 0
            max = max or 0
        end
    elseif sb == OzUFFocusFrameHealthBar then
        if OzUF.Focus and OzUF.Focus.GetHealth then
            cur, max = OzUF.Focus:GetHealth()
            cur = cur or 0
            max = max or 0
        end
    end

    local text_hidden = false
    if max == 0 then
        text_hidden = true
    elseif UnitExists(sb.unit) and (UnitIsDead(sb.unit) or UnitIsGhost(sb.unit)) then
        text_hidden = true
    end

    -- SetValue -> TextStatusBar_OnValueChanged -> this function, for EVERY status
    -- bar on screen. Skip all string work when nothing we render would change.
    -- The check runs BEFORE Blizzard's handler on purpose: skipping only our own
    -- part would leave Blizzard's "1234 / 5678" text visible instead of ours.
    if sb.oz_unit == sb.unit and sb.oz_cur == cur and sb.oz_max == max and sb.oz_hidden == text_hidden then
        return
    end
    sb.oz_unit, sb.oz_cur, sb.oz_max, sb.oz_hidden = sb.unit, cur, max, text_hidden

    if (not custom_bar) and HookTextStatusBar_UpdateTextString then
        pcall(HookTextStatusBar_UpdateTextString, sb)
    end

    sb.lockShow = 42
    sb:Show()

    if text_hidden then
        text_string:Hide()
        text_string:SetText("")
    else
        text_string:SetText(OzUF.Abbreviate(cur) .. "/" .. OzUF.Abbreviate(max))
        text_string:Show()
    end
end

-------------------------------------------------------------------------------
-- Frame Scale Helpers
-------------------------------------------------------------------------------
function OzUF.GetPlayerScale()
    return (OzUF_DB and OzUF_DB["scale_player"]) or 0.8
end

function OzUF.GetTargetScale()
    return (OzUF_DB and OzUF_DB["scale_target"]) or 0.8
end

function OzUF.GetFocusScale()
    return (OzUF_DB and OzUF_DB["scale_focus"]) or 0.6
end

function OzUF.GetPartyScale()
    return (OzUF_DB and OzUF_DB["scale_party"]) or 1.0
end

function OzUF.GetPlayerCastbarScale()
    return (OzUF_DB and OzUF_DB["scale_playercast"]) or 1.0
end

function OzUF.GetTargetCastbarScale()
    return (OzUF_DB and (OzUF_DB["scale_targetcast"] or OzUF_DB["scale_target_castbar"])) or 1.0
end

function OzUF.GetFocusCastbarScale()
    return (OzUF_DB and (OzUF_DB["scale_focuscast"] or OzUF_DB["scale_focus_castbar"])) or 1.0
end
