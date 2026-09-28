--[[
    OzUF - Configuration UI Module (configui.lua)
    Provides in-game graphical configuration dialog and slash commands:
    - Lock / Unlock Movable Frames
    - Double Health Bar Height toggle
    - Hide Rest Icon toggle
    - Mob Numeric Health Only toggle
    - Hide Portraits (Compact Bar Mode) toggle
    - Scale Slider
    - Reset Layout and Close buttons
    - /ozuf slash command handler
]]--

local _G = getfenv(0)
OzUF.ConfigUI = {}
OzUF.ConfigUI.frame = nil

function OzUF.ConfigUI:create_frame()
    if OzUF.ConfigUI.frame then return OzUF.ConfigUI.frame end

    local f = CreateFrame("Frame", "OzUFConfigFrame", UIParent)
    f:SetWidth(340)
    f:SetHeight(380)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:Hide()

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("OzUF Settings")
    title:SetTextColor(1, 0.85, 0.2)

    -- Checkboxes
    local y_offset = -45
    local function add_checkbox(name, label, get_fn, set_fn)
        local cb = CreateFrame("CheckButton", "OzUFCB_" .. name, f, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y_offset)
        local text = _G[cb:GetName() .. "Text"]
        if text then
            text:SetFont(STANDARD_TEXT_FONT, 11)
            text:SetText(label)
        end
        cb:SetChecked(get_fn())
        cb:SetScript("OnClick", function()
            local checked = this:GetChecked() and true or false
            set_fn(checked)
        end)
        y_offset = y_offset - 28
        return cb
    end

    add_checkbox("Lock", "Lock Frames (Hide Drag Boxes)",
        function() return OzUF_DB.locked end,
        function(val)
            if val then OzUF:lock_frames() else OzUF:unlock_frames() end
        end
    )

    add_checkbox("DoubleHealth", "Double Health Bar Height (24px, 2-Line)",
        function() return OzUF_DB.double_health end,
        function(val)
            OzUF_DB.double_health = val
            OzUF:apply_double_health_layout()
        end
    )

    add_checkbox("HideRest", "Hide Rest Icon ('zzz')",
        function() return OzUF_DB.hide_rest_icon end,
        function(val)
            OzUF_DB.hide_rest_icon = val
            OzUF:setup_hide_rest_icon()
        end
    )

    add_checkbox("MobNumeric", "Mob Health Numbers Only (Hide %)",
        function() return OzUF_DB.mob_health_numeric_only end,
        function(val)
            OzUF_DB.mob_health_numeric_only = val
            if TargetFrameHealthBar then OzUF:update_health_bar_texts(TargetFrameHealthBar) end
        end
    )

    add_checkbox("HidePortraits", "Hide Portraits (Compact Bar Mode)",
        function() return OzUF_DB.hide_portraits end,
        function(val)
            OzUF_DB.hide_portraits = val
            OzUF:apply_portrait_mode()
        end
    )

    -- Slider for Frame Scale
    y_offset = y_offset - 10
    local scale_label = f:CreateFontString(nil, "OVERLAY")
    scale_label:SetFont(STANDARD_TEXT_FONT, 11)
    scale_label:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y_offset)
    scale_label:SetText("Player Frame Scale:")
    scale_label:SetTextColor(1, 1, 1)

    local scale_slider = CreateFrame("Slider", "OzUFScaleSlider", f, "OptionsSliderTemplate")
    scale_slider:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y_offset - 18)
    scale_slider:SetMinMaxValues(0.6, 1.4)
    scale_slider:SetValueStep(0.05)
    scale_slider:SetValue((OzUF_DB and OzUF_DB.scales and OzUF_DB.scales.player) or 1.0)
    _G[scale_slider:GetName() .. "Low"]:SetText("60%")
    _G[scale_slider:GetName() .. "High"]:SetText("140%")
    _G[scale_slider:GetName() .. "Text"]:SetText(string.format("%.0f%%", ((OzUF_DB and OzUF_DB.scales and OzUF_DB.scales.player) or 1.0) * 100))

    scale_slider:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue() * 20 + 0.5) / 20
        if OzUF_DB and OzUF_DB.scales then
            OzUF_DB.scales.player = val
            OzUF_DB.scales.target = val
        end
        _G[this:GetName() .. "Text"]:SetText(string.format("%.0f%%", val * 100))
        OzUF:apply_scales()
    end)

    -- Buttons
    local close_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close_btn:SetWidth(90)
    close_btn:SetHeight(24)
    close_btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
    close_btn:SetText("Close")
    close_btn:SetScript("OnClick", function() f:Hide() end)

    local reset_btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset_btn:SetWidth(110)
    reset_btn:SetHeight(24)
    reset_btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 16)
    reset_btn:SetText("Reset Layout")
    reset_btn:SetScript("OnClick", function() OzUF:reset_positions() end)

    OzUF.ConfigUI.frame = f
    return f
end

function OzUF.ConfigUI:toggle()
    local f = OzUF.ConfigUI:create_frame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

-- Slash Command Handler
local function slash_handler(msg)
    if not msg or msg == "" then
        OzUF.ConfigUI:toggle()
        return
    end

    if string.find(msg, "unlock") or string.find(msg, "move") then
        OzUF:unlock_frames()
    elseif string.find(msg, "lock") then
        OzUF:lock_frames()
    elseif string.find(msg, "reset") then
        OzUF:reset_positions()
    elseif string.find(msg, "focus") then
        OzUF:set_focus("target")
    elseif string.find(msg, "clearfocus") then
        OzUF:clear_focus()
    elseif string.find(msg, "portrait") then
        OzUF_DB.hide_portraits = not OzUF_DB.hide_portraits
        OzUF:apply_portrait_mode()
        local status = OzUF_DB.hide_portraits and "hidden (Compact Mode)" or "shown"
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF:|r Portraits are now " .. status)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900OzUF Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  /ozuf - Open settings dialog")
        DEFAULT_CHAT_FRAME:AddMessage("  /ozuf unlock - Unlock frames to move")
        DEFAULT_CHAT_FRAME:AddMessage("  /ozuf lock - Lock frames")
        DEFAULT_CHAT_FRAME:AddMessage("  /ozuf portrait - Toggle portraits / compact bar")
        DEFAULT_CHAT_FRAME:AddMessage("  /focus - Set current target as focus")
        DEFAULT_CHAT_FRAME:AddMessage("  /clearfocus - Clear focus")
    end
end

SLASH_OZUF1 = "/ozuf"
SlashCmdList["OZUF"] = slash_handler
