--[[
    OzUF - Party Frame Module (partyframe.lua)
    Clones features from:
    - unitframes-classcolor.lua (Party member name class colors)
    - unitframes-classportrait.lua (Party member class circular portraits)
]] --

local _G = getfenv(0)

-------------------------------------------------------------------------------
-- Party Class Colors
-------------------------------------------------------------------------------
local function UpdatePartyColors()
    for id = 1, MAX_PARTY_MEMBERS do
        local name = _G["PartyMemberFrame" .. id .. "Name"]
        local unit = "party" .. id
        if UnitExists(unit) and name then
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class] or { r = 0.5, g = 0.5, b = 0.5 }
            name:SetTextColor(color.r, color.g, color.b, 1)
        end
    end
end

-------------------------------------------------------------------------------
-- Party Class Portraits
-------------------------------------------------------------------------------
local function UpdatePartyPortraits()
    for id = 1, MAX_PARTY_MEMBERS do
        local portrait = _G["PartyMemberFrame" .. id .. "Portrait"]
        local unit = "party" .. id
        if UnitExists(unit) and portrait then
            local _, class = UnitClass(unit)
            if UnitIsPlayer(unit) and class and OzUF.CLASS_ICON[class] then
                portrait:SetTexture(OzUF.CLASS_ICON[class])
            else
                portrait:SetTexCoord(0, 1, 0, 1)
                SetPortraitTexture(portrait, unit)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Hooks & Event Registration
-------------------------------------------------------------------------------
local origPartyMemberFrame_UpdateMember = PartyMemberFrame_UpdateMember
PartyMemberFrame_UpdateMember = function(self)
    origPartyMemberFrame_UpdateMember(self)
    UpdatePartyColors()
    UpdatePartyPortraits()
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
    UpdatePartyColors()
    UpdatePartyPortraits()
end)

