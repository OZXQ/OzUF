--[[
    OzUF - Party Frame Module (partyframe.lua)
    Clones features from:
    - unitframes-classcolor.lua (Party member name class colors)
    - unitframes-classportrait.lua (Party member class circular portraits)
]] --

local _G = getfenv(0)

-------------------------------------------------------------------------------
-- Static lookup tables (built once, no per-call string concatenation)
-------------------------------------------------------------------------------
local PARTY_UNITS = {}
local party_refs = {}
local DEFAULT_CLASS_COLOR = { r = 0.5, g = 0.5, b = 0.5 }

local function build_party_refs()
    for id = 1, MAX_PARTY_MEMBERS do
        PARTY_UNITS[id] = PARTY_UNITS[id] or ("party" .. id)
        if not party_refs[id] then
            party_refs[id] = {
                name = _G["PartyMemberFrame" .. id .. "Name"],
                portrait = _G["PartyMemberFrame" .. id .. "Portrait"],
            }
        end
    end
end

-------------------------------------------------------------------------------
-- Single-pass refresh (class colors + class portraits)
-------------------------------------------------------------------------------
local function refresh_party_frames()
    build_party_refs()

    for id = 1, MAX_PARTY_MEMBERS do
        local ref = party_refs[id]
        local unit = PARTY_UNITS[id]
        if ref and unit and UnitExists(unit) then
            local _, class = UnitClass(unit)

            if ref.name then
                local color = RAID_CLASS_COLORS[class] or DEFAULT_CLASS_COLOR
                ref.name:SetTextColor(color.r, color.g, color.b, 1)
            end

            local portrait = ref.portrait
            if portrait then
                if UnitIsPlayer(unit) and class and OzUF.CLASS_ICON[class] then
                    portrait:SetTexture(OzUF.CLASS_ICON[class])
                else
                    portrait:SetTexCoord(0, 1, 0, 1)
                    SetPortraitTexture(portrait, unit)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Coalesced refresh driver
-- PartyMemberFrame_UpdateMember is invoked once per party member, so doing the
-- work inline was O(n^2). Mark dirty here and refresh once after the burst.
-------------------------------------------------------------------------------
local partyDirty = false
local partyTimer = 0
local partyDriver = CreateFrame("Frame")
partyDriver:Hide()

local function request_party_refresh()
    partyDirty = true
    partyTimer = 0
    partyDriver:Show()
end

partyDriver:SetScript("OnUpdate", function()
    partyTimer = partyTimer + arg1
    if partyTimer < 0.2 then return end
    partyTimer = 0
    this:Hide()
    if not partyDirty then return end
    partyDirty = false
    refresh_party_frames()
end)

-------------------------------------------------------------------------------
-- Hooks & Event Registration
-------------------------------------------------------------------------------
local origPartyMemberFrame_UpdateMember = PartyMemberFrame_UpdateMember
PartyMemberFrame_UpdateMember = function(self)
    origPartyMemberFrame_UpdateMember(self)
    request_party_refresh()
end

local partyEvents = CreateFrame("Frame")
partyEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
partyEvents:RegisterEvent("UNIT_PORTRAIT_UPDATE")
partyEvents:RegisterEvent("PARTY_MEMBERS_CHANGED")

partyEvents:SetScript("OnEvent", function()
    if event == "UNIT_PORTRAIT_UPDATE" and arg1 then
        if arg1 ~= "party1" and arg1 ~= "party2" and arg1 ~= "party3" and arg1 ~= "party4" then
            return
        end
    end
    request_party_refresh()
end)
