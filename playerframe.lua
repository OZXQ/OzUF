--[[
    OzUF - Player & Pet Frame Module (playerframe.lua)
    Clones features from:
    - unitframes-bighealth-new.lua (Big health bar, custom reversed textures, layout)
    - unitframes-classcolor.lua (Player class coloring on health bar and name background)
    - unitframes-classportrait.lua (Class circular icon on portrait)
    - health-numbers.lua (Health & mana outline numbers)
    - unitframe-energytick.lua (Energy tick & mana 5s/2s regen ticker)
]] --

local _G = getfenv(0)



-------------------------------------------------------------------------------
-- Background Texture & Classification (Mirrored Left to Right)
-------------------------------------------------------------------------------
local function UpdatePlayerTexture()
    PlayerFrame:SetWidth(256)
    PlayerFrame:SetHeight(128)
    PlayerFrame:SetScale(OzUF.GetPlayerScale and OzUF.GetPlayerScale() or 0.8)
    PlayerFrameTexture:SetTexture(OzUF.TEX_NORMAL)
    PlayerFrameTexture:SetTexCoord(1, 0, 0, 1)
end

local orig_PlayerFrameTexture_SetTexture = PlayerFrameTexture.SetTexture
PlayerFrameTexture.SetTexture = function(self, texPath)
    if texPath and (string.find(texPath, "UI-TargetingFrame_HC", 1, true) or string.find(texPath, "ui-targetingframe_hc", 1, true) or string.find(texPath, "UI-PlayerFrame_HC", 1, true) or string.find(texPath, "ui-playerframe_hc", 1, true)) then
        orig_PlayerFrameTexture_SetTexture(self, OzUF.TEX_NORMAL)
    else
        orig_PlayerFrameTexture_SetTexture(self, texPath)
    end
end


-------------------------------------------------------------------------------
-- Class Portrait
-------------------------------------------------------------------------------
local function UpdatePlayerPortrait()
    local _, class = UnitClass("player")
    if class and OzUF.CLASS_ICON[class] then
        PlayerPortrait:SetTexture(OzUF.CLASS_ICON[class])
        PlayerPortrait:SetTexCoord(0, 1, 0, 1)
    else
        PlayerPortrait:SetTexCoord(0, 1, 0, 1)
    end
    PlayerPortrait:SetPoint("TOPLEFT", 43, -13)
end

-------------------------------------------------------------------------------
-- Big Health Bar Dimensions & Positions
-------------------------------------------------------------------------------
local function SetupPlayerLayout()
    UpdatePlayerTexture()
    PlayerStatusTexture:SetTexture(OzUF.TEX_STATUS)

    PlayerFrameHealthBar:SetPoint("TOPLEFT", 108, -24)
    PlayerFrameHealthBar:SetWidth(118)
    PlayerFrameHealthBar:SetHeight(28)
    PlayerFrameManaBar:SetPoint("TOPLEFT", 108, -55)
    PlayerFrameManaBar:SetWidth(118)
    PlayerFrameManaBar:SetHeight(11)
    PlayerFrameBackground:SetPoint("TOPLEFT", 108, -24)
    PlayerFrameBackground:SetWidth(118)
    PlayerFrameBackground:SetHeight(39)

    -- Pet Frame setup
    PetFrame:ClearAllPoints()
    PetFrame:SetPoint("BOTTOM", PlayerFrame, 20, 10)
    PetFrameTexture:SetTexture(OzUF.TEX_NORMAL)

    -- Status texts styling
    if PlayerFrameHealthBarText then
        PlayerFrameHealthBarText:SetFontObject(OzUF.status_text_font)
        PlayerFrameHealthBarText:ClearAllPoints()
        PlayerFrameHealthBarText:SetJustifyH("RIGHT")
        PlayerFrameHealthBarText:SetPoint("BOTTOMRIGHT", PlayerFrameHealthBar, "BOTTOMRIGHT", -2, 0)
    end

    if PlayerFrameManaBarText then
        PlayerFrameManaBarText:SetFontObject(OzUF.status_text_font)
        PlayerFrameManaBarText:ClearAllPoints()
        PlayerFrameManaBarText:SetJustifyH("RIGHT")
        PlayerFrameManaBarText:SetPoint("BOTTOMRIGHT", PlayerFrameManaBar, "BOTTOMRIGHT", -2, 3)
    end

    PlayerLevelText:ClearAllPoints()
    PlayerLevelText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    PlayerLevelText:SetPoint("BOTTOMLEFT", PlayerFrame, "BOTTOMLEFT", 46, 55)
    PlayerLevelText:SetJustifyH("CENTER")

    PlayerName:ClearAllPoints()
    PlayerName:SetPoint("TOP", PlayerFrame, "TOP", 40, -28)
    PlayerName:SetJustifyH("CENTER")

    PlayerStatusTexture:SetTexCoord(1, 0, 0, 0.18)
    PlayerStatusTexture:SetWidth(256)
    PlayerStatusTexture:SetHeight(92)
    PlayerStatusTexture:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 0, 0)

    for _, frame in pairs({ PetFrameHealthBar, PetFrameManaBar }) do
        if frame.TextString then
            frame.TextString:SetFontObject(OzUF.status_text_font)
            frame.TextString:ClearAllPoints()
            frame.TextString:SetJustifyH("LEFT")
        end
    end

    PetFrameHealthBar.TextString:SetPoint("CENTER", PetFrameHealthBar, "CENTER", -2, 0)
    PetFrameManaBar.TextString:SetPoint("CENTER", PetFrameManaBar, "CENTER", -2, -2)

    -- Font outline on player name
    -- if PlayerFrame.name then
    --     local font, size = PlayerFrame.name:GetFont()
    --     PlayerFrame.name:SetFont(font, size, "NONE")
    -- end
end

-------------------------------------------------------------------------------
-- Class Color Application
-------------------------------------------------------------------------------
local function SetupPlayerClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class] or { r = 0.5, g = 0.5, b = 0.5 }

    if not PlayerFrameNameBackground then
        PlayerFrameNameBackground = PlayerFrame:CreateTexture(nil, "BACKGROUND")
        PlayerFrameNameBackground:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground")
        PlayerFrameNameBackground:SetWidth(119)
        PlayerFrameNameBackground:SetHeight(19)
        PlayerFrameNameBackground:SetPoint("TOPLEFT", 106, -22)
        PlayerFrameNameBackground:SetDrawLayer("BORDER")
        PlayerFrameNameBackground.Show = function() end
        PlayerFrameNameBackground:Hide()
    end
    PlayerFrameNameBackground:SetVertexColor(color.r, color.g, color.b, 1)

    -- Disable vanilla ui color restore functions
    if not PlayerFrameHealthBar.orig_SetStatusBarColor then
        PlayerFrameHealthBar.orig_SetStatusBarColor = PlayerFrameHealthBar.SetStatusBarColor
        PlayerFrameHealthBar.SetStatusBarColor = function() end
    end

    -- Set player healthbar to class color
    PlayerFrameHealthBar:orig_SetStatusBarColor(color.r, color.g, color.b, 1)
end

-------------------------------------------------------------------------------
-- Energy & Mana Ticks (unitframe-energytick.lua clone)
-------------------------------------------------------------------------------
local energytick = nil
local function SetupEnergyTick()
    if energytick then return end
    energytick = CreateFrame("Frame", nil, PlayerFrameManaBar)
    energytick:SetAllPoints(PlayerFrameManaBar)
    energytick:RegisterEvent("PLAYER_REGEN_ENABLED")
    energytick:RegisterEvent("PLAYER_REGEN_DISABLED")
    energytick:RegisterEvent("PLAYER_ENTERING_WORLD")
    energytick:RegisterEvent("UNIT_DISPLAYPOWER")
    energytick:RegisterEvent("UNIT_ENERGY")
    energytick:RegisterEvent("UNIT_MANA")

    energytick:SetScript("OnEvent", function()
        if UnitPowerType("player") == 0 then
            this.mode = "MANA"
            if (UnitMana("player") == UnitManaMax("player")) and (not UnitAffectingCombat("player")) then
                this:Hide()
            else
                this:Show()
            end
        elseif UnitPowerType("player") == 3 then
            this.mode = "ENERGY"
            if (UnitMana("player") == UnitManaMax("player")) and (not UnitAffectingCombat("player")) then
                this:Hide()
            else
                this:Show()
            end
        else
            this:Hide()
        end

        if event == "PLAYER_ENTERING_WORLD" then
            this.lastMana = UnitMana("player")
        end

        if (event == "UNIT_MANA" or event == "UNIT_ENERGY") and arg1 == "player" then
            this.currentMana = UnitMana("player")
            local diff = 0
            if this.lastMana then
                diff = this.currentMana - this.lastMana
            end

            if this.mode == "MANA" and diff < 0 then
                this.target = 5
            elseif this.mode == "MANA" and diff > 0 then
                if this.max ~= 5 and diff > (this.badtick and this.badtick * 1.2 or 5) then
                    this.target = 2
                else
                    this.badtick = diff
                end
            elseif this.mode == "ENERGY" and diff > 0 then
                this.target = 2
            end
            this.lastMana = this.currentMana
        end
    end)

    local pheight = PlayerFrameManaBar:GetHeight()
    local pwidth = PlayerFrameManaBar:GetWidth()

    local tick_timer = 0
    energytick:SetScript("OnUpdate", function()
        if this.target then
            this.start, this.max = GetTime(), this.target
            this.target = nil
        end

        if not this.start then return end

        -- Throttle the tick spark to 20Hz instead of running every rendered frame
        tick_timer = tick_timer + arg1
        if tick_timer < 0.05 then return end
        tick_timer = 0

        this.current = GetTime() - this.start

        if this.current > this.max then
            this.start, this.max, this.current = GetTime(), 2, 0
        end

        local pos = math.floor(pwidth * (this.current / this.max))
        if not pheight then return end
        if pos ~= this.lastPos then
            this.lastPos = pos
            this.spark:SetPoint("LEFT", pos - math.floor((pheight + 5) / 2), 0)
        end
    end)


    energytick.spark = energytick:CreateTexture(nil, "OVERLAY")
    energytick.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    energytick.spark:SetHeight(pheight + 10)
    energytick.spark:SetWidth(pheight + 4)
    energytick.spark:SetBlendMode("ADD")
end

-------------------------------------------------------------------------------
-- Event Registration & Initialization
-------------------------------------------------------------------------------
local playerEventFrame = CreateFrame("Frame")
playerEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
playerEventFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")

playerEventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        SetupPlayerLayout()
        SetupPlayerClassColor()
        SetupEnergyTick()
        UpdatePlayerPortrait()
    elseif event == "UNIT_PORTRAIT_UPDATE" and arg1 == "player" then
        UpdatePlayerPortrait()
    end
end)

-- Hook UnitFrame_Update for portrait restoration
local HookUnitFrame_Update = UnitFrame_Update
UnitFrame_Update = function(isParty)
    HookUnitFrame_Update(isParty)
    if this == PlayerFrame then
        UpdatePlayerPortrait()
        UpdatePlayerTexture()
    end
end

-- Delayed refresh on login to ensure texture binds cleanly after loading screen
local playerLoginDelay = CreateFrame("Frame")
playerLoginDelay:Hide()
playerLoginDelay:RegisterEvent("PLAYER_ENTERING_WORLD")
playerLoginDelay:SetScript("OnEvent", function()
    this.timer = 0
    this:Show()
end)
playerLoginDelay:SetScript("OnUpdate", function()
    if not this.timer then return end
    this.timer = this.timer + arg1
    if this.timer >= 0.2 then
        this:Hide()
        this.timer = nil
        UpdatePlayerTexture()
        UpdatePlayerPortrait()
    end
end)
