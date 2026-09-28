--[[
    OzUF - Party Module (party.lua)
    Handles PartyMemberFrame 1-4 enhancements:
    - Custom frame background texture (UI-TargetingFrame2.blp at 152x76 proportional scale with SetTexCoord(1, 0, 0, 1))
    - Double height health bar with 2 clean lines
    - Portrait toggle (Compact bar mode)
    - Frame scaling
    - Party updates
]]--

local _G = getfenv(0)
OzUF.Party = {}

function OzUF.Party:apply_texture()
    for i = 1, 4 do
        local party_frame = _G["PartyMemberFrame" .. i]
        local party_tex = _G["PartyMemberFrame" .. i .. "Texture"]
        if party_tex and party_frame then
            if OzUF_DB and OzUF_DB.hide_portraits then
                party_tex:Hide()
            else
                party_tex:Show()
                party_tex:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
                party_tex:SetTexCoord(1, 0, 0, 1)
                party_tex:ClearAllPoints()
                party_tex:SetPoint("TOPLEFT", party_frame, "TOPLEFT", -16, 4)
                party_tex:SetWidth(152)
                party_tex:SetHeight(76)
            end
        end
    end
end

function OzUF.Party:apply_double_health()
    if not OzUF_DB or not OzUF_DB.double_health then return end

    for i = 1, 4 do
        local party_frame = _G["PartyMemberFrame" .. i]
        local party_hb = _G["PartyMemberFrame" .. i .. "HealthBar"]
        local party_mb = _G["PartyMemberFrame" .. i .. "ManaBar"]
        local party_name = _G["PartyMemberFrame" .. i .. "Name"]
        local portrait = _G["PartyMemberFrame" .. i .. "Portrait"]

        if party_frame and party_hb and party_mb then
            party_hb:ClearAllPoints()
            party_hb:SetPoint("TOPLEFT", party_frame, "TOPLEFT", 48, -10)
            party_hb:SetWidth(70)
            party_hb:SetHeight(16)
            OzUF:create_health_bar_texts(party_frame, party_hb, "party" .. i)

            if party_name then party_name:Hide() end

            party_mb:ClearAllPoints()
            party_mb:SetPoint("TOPLEFT", party_hb, "BOTTOMLEFT", 0, -2)
            party_mb:SetWidth(70)
            party_mb:SetHeight(6)
        end

        if portrait and party_frame then
            portrait:ClearAllPoints()
            portrait:SetPoint("TOPLEFT", party_frame, "TOPLEFT", 9, -3)
            portrait:SetWidth(38)
            portrait:SetHeight(38)
        end
    end
end

function OzUF.Party:apply_portrait_mode()
    if not OzUF_DB then return end
    local hide_p = OzUF_DB.hide_portraits

    for i = 1, 4 do
        local party_frame = _G["PartyMemberFrame" .. i]
        local portrait = _G["PartyMemberFrame" .. i .. "Portrait"]
        local party_hb = _G["PartyMemberFrame" .. i .. "HealthBar"]
        local party_mb = _G["PartyMemberFrame" .. i .. "ManaBar"]
        local party_tex = _G["PartyMemberFrame" .. i .. "Texture"]

        if portrait and party_hb and party_mb and party_frame then
            if hide_p then
                portrait:Hide()
                if party_tex then party_tex:Hide() end
                party_hb:ClearAllPoints()
                party_hb:SetPoint("TOPLEFT", party_frame, "TOPLEFT", 16, -10)
                party_hb:SetWidth(140)
                party_hb:SetHeight(16)
                party_mb:ClearAllPoints()
                party_mb:SetPoint("TOPLEFT", party_hb, "BOTTOMLEFT", 0, -2)
                party_mb:SetWidth(140)
                party_mb:SetHeight(6)
            else
                portrait:Show()
                portrait:ClearAllPoints()
                portrait:SetPoint("TOPLEFT", party_frame, "TOPLEFT", 9, -3)
                portrait:SetWidth(38)
                portrait:SetHeight(38)

                if party_tex then
                    party_tex:Show()
                    party_tex:SetTexture("Interface\\AddOns\\OzUF\\texture\\UI-TargetingFrame2.blp")
                    party_tex:SetTexCoord(1, 0, 0, 1)
                    party_tex:ClearAllPoints()
                    party_tex:SetPoint("TOPLEFT", party_frame, "TOPLEFT", -16, 4)
                    party_tex:SetWidth(152)
                    party_tex:SetHeight(76)
                end

                party_hb:ClearAllPoints()
                party_hb:SetPoint("TOPLEFT", party_frame, "TOPLEFT", 48, -10)
                party_hb:SetWidth(70)
                party_hb:SetHeight(16)
                party_mb:ClearAllPoints()
                party_mb:SetPoint("TOPLEFT", party_hb, "BOTTOMLEFT", 0, -2)
                party_mb:SetWidth(70)
                party_mb:SetHeight(6)
            end
        end
    end
end

function OzUF.Party:apply_scale()
    if not OzUF_DB or not OzUF_DB.scales or not OzUF_DB.scales.party then return end
    local scale = OzUF_DB.scales.party
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then pf:SetScale(scale) end
    end
end

function OzUF.Party:update(unit)
    if not unit then return end
    local hb = _G[unit .. "HealthBar"] or _G["PartyMemberFrame" .. (string.sub(unit, 6, 6) or "") .. "HealthBar"]
    if hb then
        OzUF:update_health_bar_texts(hb, unit)
    end
    OzUF.Party:apply_texture()
end

-- Hook PartyMemberFrame_UpdateMember to ensure custom texture is preserved
if PartyMemberFrame_UpdateMember then
    local orig_PartyMemberFrame_UpdateMember = PartyMemberFrame_UpdateMember
    PartyMemberFrame_UpdateMember = function(arg)
        orig_PartyMemberFrame_UpdateMember(arg)
        OzUF.Party:apply_texture()
    end
end
