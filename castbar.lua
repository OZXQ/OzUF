--[[
    OzUF - Castbar Module (castbar.lua)
    Provides Target and Focus castbars for WoW 1.12.1 / Vanilla / Turtle WoW / SuperWoW.
    Features:
    1. Movable: Shift+drag (or unlock state) to move freely anywhere on screen; saved in OzUF_DB.
       When no custom position is saved, target castbar defaults to top/bottom of TargetFrame,
       and focus castbar defaults beneath FocusFrame.
    2. Remaining and Total cast time display (e.g. "1.5s / 3.0s").
    3. Latency indicator on the castbar:
       Displays the player's network lag zone at the end/start of the bar so players can queue or time spells.
    4. Dual engine support:
       - Uses native UnitCastingInfo/UnitChannelInfo if available (e.g. SuperWoW / Turtle WoW client extension)
       - Falls back to built-in Combat Log parser with full spell database (cloned from FocusFrame / ShaguTweaks)
    5. Clean single file, no modifications required in other frame files.
]]--

local _G = getfenv(0)

OzUF = OzUF or {}
OzUF.Castbars = OzUF.Castbars or {}

local isZh = GetLocale() == "zhCN"

-------------------------------------------------------------------------------
-- Localization
-------------------------------------------------------------------------------
local L_PLAYER_CASTBAR = isZh and "玩家施法条" or "Player Castbar"
local L_TARGET_CASTBAR = isZh and "目标施法条" or "Target Castbar"
local L_FOCUS_CASTBAR  = isZh and "焦点施法条" or "Focus Castbar"
local L_DRAG_HINT      = isZh and "按住 Shift 拖动位置" or "Shift-Drag to Move"

-------------------------------------------------------------------------------
-- Spell Database & Combat Log Tracking (Fallback Engine)
-------------------------------------------------------------------------------
local casts = {}

local SPELLS = {
    -- DRUID
    ["Entangling Roots"] = { casttime = 1.5, icon = "Spell_Nature_StrangleVines" },
    ["Healing Touch"] = { casttime = 3.0, icon = "Spell_Nature_HealingTouch" },
    ["Hibernate"] = { casttime = 1.5, icon = "Spell_Nature_Sleep" },
    ["Rebirth"] = { casttime = 2.0, icon = "Spell_Nature_Reincarnation" },
    ["Regrowth"] = { casttime = 2.0, icon = "Spell_Nature_ResistNature" },
    ["Soothe Animal"] = { casttime = 1.5, icon = "Ability_Hunter_BeastSoothe" },
    ["Starfire"] = { casttime = 3.0, icon = "Spell_Arcane_StarFire" },
    ["Teleport: Moonglade"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportMoonglade" },
    ["Wrath"] = { casttime = 1.5, icon = "Spell_Nature_AbolishMagic" },
    ["Hurricane"] = { casttime = 9.5, icon = "Spell_Nature_Cyclone", channel = true },
    ["Tranquility"] = { casttime = 10.0, icon = "Spell_Nature_Tranquility", channel = true },

    -- HUNTER
    ["Aimed Shot"] = { casttime = 3.0, icon = "Inv_Spear_07" },
    ["Multi-Shot"] = { casttime = 0.5, icon = "Ability_UpgradeMoonGlaive" },
    ["Dismiss Pet"] = { casttime = 5.0, icon = "Spell_Nature_SpiritWolf" },
    ["Eyes of the Beast"] = { casttime = 2.0, icon = "Ability_EyeOfTheOwl" },
    ["Revive Pet"] = { casttime = 10.0, icon = "Ability_Hunter_BeastSoothe" },
    ["Scare Beast"] = { casttime = 1.5, icon = "Ability_Druid_Cower" },
    ["Eagle Eye"] = { casttime = 60.0, icon = "Ability_Hunter_EagleEye", channel = true },

    -- MAGE
    ["Fireball"] = { casttime = 3.0, icon = "Spell_Fire_FlameBolt" },
    ["Frostbolt"] = { casttime = 2.5, icon = "Spell_Frost_FrostBolt02" },
    ["Pyroblast"] = { casttime = 6.0, icon = "Spell_Fire_Fireball02" },
    ["Scorch"] = { casttime = 1.5, icon = "Spell_Fire_SoulBurn" },
    ["Flamestrike"] = { casttime = 3.0, icon = "Spell_Fire_SelfDestruct" },
    ["Polymorph"] = { casttime = 1.5, icon = "Spell_Nature_Polymorph" },
    ["Polymorph: Pig"] = { casttime = 1.5, icon = "Spell_Magic_PolymorphPig" },
    ["Polymorph: Turtle"] = { casttime = 1.5, icon = "Ability_Hunter_Pet_Turtle" },
    ["Conjure Food"] = { casttime = 3.0, icon = "Inv_Misc_Food_73cinnamonroll" },
    ["Conjure Water"] = { casttime = 3.0, icon = "Inv_Drink_18" },
    ["Conjure Mana Agate"] = { casttime = 3.0, icon = "Inv_Misc_Gem_Emerald_01" },
    ["Conjure Mana Citrine"] = { casttime = 3.0, icon = "Inv_Misc_Gem_Opal_01" },
    ["Conjure Mana Jade"] = { casttime = 3.0, icon = "Inv_Misc_Gem_Emerald_02" },
    ["Conjure Mana Ruby"] = { casttime = 3.0, icon = "Inv_Misc_Gem_Ruby_01" },
    ["Portal: Darnassus"] = { casttime = 10.0, icon = "Spell_Arcane_PortalDarnassus" },
    ["Portal: Thunder Bluff"] = { casttime = 10.0, icon = "Spell_Arcane_PortalThunderBluff" },
    ["Portal: Ironforge"] = { casttime = 10.0, icon = "Spell_Arcane_PortalIronForge" },
    ["Portal: Orgrimmar"] = { casttime = 10.0, icon = "Spell_Arcane_PortalOrgrimmar" },
    ["Portal: Stormwind"] = { casttime = 10.0, icon = "Spell_Arcane_PortalStormWind" },
    ["Portal: Undercity"] = { casttime = 10.0, icon = "Spell_Arcane_PortalUnderCity" },
    ["Teleport: Darnassus"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportDarnassus" },
    ["Teleport: Thunder Bluff"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportThunderBluff" },
    ["Teleport: Ironforge"] = { casttime = 10.0, icon = "Spell_Arcane_PortalIronForge" },
    ["Teleport: Orgrimmar"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportOrgrimmar" },
    ["Teleport: Stormwind"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportStormWind" },
    ["Teleport: Undercity"] = { casttime = 10.0, icon = "Spell_Arcane_TeleportUnderCity" },
    ["Arcane Missiles"] = { casttime = 5.0, icon = "Spell_Nature_StarFall", channel = true },
    ["Blizzard"] = { casttime = 8.0, icon = "Spell_Frost_IceStorm", channel = true },
    ["Evocation"] = { casttime = 8.0, icon = "Spell_Nature_Purge", channel = true },

    -- PALADIN
    ["Holy Light"] = { casttime = 2.5, icon = "Spell_Holy_HolyBolt" },
    ["Flash of Light"] = { casttime = 1.5, icon = "Spell_Holy_FlashHeal" },
    ["Hammer of Wrath"] = { casttime = 1.0, icon = "Ability_ThunderClap" },
    ["Holy Wrath"] = { casttime = 2.0, icon = "Spell_Holy_WeaponMastery" },
    ["Redemption"] = { casttime = 10.0, icon = "Spell_Holy_Resurrection" },
    ["Summon Warhorse"] = { casttime = 3.0, icon = "Spell_Nature_Swiftness" },
    ["Summon Charger"] = { casttime = 3.0, icon = "Ability_Mount_Charger" },
    ["Turn Undead"] = { casttime = 1.5, icon = "Spell_Holy_TurnUndead" },

    -- PRIEST
    ["Flash Heal"] = { casttime = 1.5, icon = "Spell_Holy_FlashHeal" },
    ["Greater Heal"] = { casttime = 2.5, icon = "Spell_Holy_GreaterHeal" },
    ["Heal"] = { casttime = 2.5, icon = "Spell_Holy_Heal" },
    ["Lesser Heal"] = { casttime = 2.5, icon = "Spell_Holy_LesserHeal" },
    ["Holy Fire"] = { casttime = 3.5, icon = "Spell_Holy_SearingLight" },
    ["Mana Burn"] = { casttime = 3.0, icon = "Spell_Shadow_ManaBurn" },
    ["Mind Blast"] = { casttime = 1.5, icon = "Spell_Shadow_UnholyFrenzy" },
    ["Mind Control"] = { casttime = 3.0, icon = "Spell_Shadow_ShadowWordDominate" },
    ["Prayer of Healing"] = { casttime = 3.0, icon = "Spell_Holy_PrayerOfHealing02" },
    ["Resurrection"] = { casttime = 10.0, icon = "Spell_Holy_Resurrection" },
    ["Shackle Undead"] = { casttime = 1.5, icon = "Spell_Nature_Slow" },
    ["Smite"] = { casttime = 2.5, icon = "Spell_Holy_HolySmite" },
    ["Mind Flay"] = { casttime = 3.0, icon = "Spell_Shadow_SiphonMana", channel = true },
    ["Mind Vision"] = { casttime = 30.0, icon = "Spell_Holy_MindVision", channel = true },

    -- ROGUE
    ["Disarm Trap"] = { casttime = 5.0, icon = "Spell_Shadow_GrimWard" },
    ["Pick Lock"] = { casttime = 5.0, icon = "Spell_Nature_MoonKey" },

    -- SHAMAN
    ["Chain Heal"] = { casttime = 2.5, icon = "Spell_Nature_HealingWaveGreater" },
    ["Chain Lightning"] = { casttime = 1.5, icon = "Spell_Nature_ChainLightning" },
    ["Healing Wave"] = { casttime = 2.5, icon = "Spell_Nature_HealingWaveGreater" },
    ["Lesser Healing Wave"] = { casttime = 1.5, icon = "Spell_Nature_HealingWaveLesser" },
    ["Lightning Bolt"] = { casttime = 2.5, icon = "Spell_Nature_Lightning" },
    ["Ancestral Spirit"] = { casttime = 10.0, icon = "Spell_Nature_Regenerate" },
    ["Astral Recall"] = { casttime = 10.0, icon = "Spell_Nature_AstralRecal" },
    ["Far Sight"] = { casttime = 2.0, icon = "Spell_Nature_FarSight" },
    ["Ghost Wolf"] = { casttime = 3.0, icon = "Spell_Nature_SpiritWolf" },

    -- WARLOCK
    ["Banish"] = { casttime = 1.5, icon = "Spell_Shadow_Cripple" },
    ["Create Firestone"] = { casttime = 3.0, icon = "Inv_Misc_Gem_Bloodstone_02" },
    ["Create Healthstone"] = { casttime = 3.0, icon = "Inv_Stone_04" },
    ["Create Soulstone"] = { casttime = 3.0, icon = "Spell_Shadow_SoulGem" },
    ["Create Spellstone"] = { casttime = 5.0, icon = "Inv_Misc_Gem_Sapphire_01" },
    ["Enslave Demon"] = { casttime = 3.0, icon = "Spell_Shadow_EnslaveDemon" },
    ["Fear"] = { casttime = 1.5, icon = "Spell_Shadow_Possession" },
    ["Howl of Terror"] = { casttime = 2.0, icon = "Spell_Shadow_DeathScream" },
    ["Immolate"] = { casttime = 1.5, icon = "Spell_Fire_Immolation" },
    ["Inferno"] = { casttime = 2.0, icon = "Spell_Fire_Incinerate" },
    ["Ritual of Doom"] = { casttime = 10.0, icon = "Spell_Shadow_AntiMagicShell" },
    ["Ritual of Summoning"] = { casttime = 5.0, icon = "Spell_Shadow_Twilight" },
    ["Searing Pain"] = { casttime = 1.5, icon = "Spell_Fire_SoulBurn" },
    ["Seduction"] = { casttime = 1.5, icon = "Spell_Shadow_MindSteal" },
    ["Shadow Bolt"] = { casttime = 2.5, icon = "Spell_Shadow_ShadowBolt" },
    ["Soul Fire"] = { casttime = 4.0, icon = "Spell_Fire_Fireball02" },
    ["Summon Dreadsteed"] = { casttime = 3.0, icon = "Ability_Mount_Dreadsteed" },
    ["Summon Felhunter"] = { casttime = 10.0, icon = "Spell_Shadow_SummonFelhunter" },
    ["Summon Felsteed"] = { casttime = 3.0, icon = "Spell_Nature_Swiftness" },
    ["Summon Imp"] = { casttime = 10.0, icon = "Spell_Shadow_SummonImp" },
    ["Summon Succubus"] = { casttime = 10.0, icon = "Spell_Shadow_SummonSuccubus" },
    ["Summon Voidwalker"] = { casttime = 10.0, icon = "Spell_Shadow_SummonVoidwalker" },
    ["Drain Life"] = { casttime = 5.0, icon = "Spell_Shadow_LifeDrain02", channel = true },
    ["Drain Mana"] = { casttime = 5.0, icon = "Spell_Shadow_SiphonMana", channel = true },
    ["Drain Soul"] = { casttime = 15.0, icon = "Spell_Shadow_Haunting", channel = true },
    ["Health Funnel"] = { casttime = 10.0, icon = "Spell_Shadow_LifeDrain", channel = true },
    ["Rain of Fire"] = { casttime = 8.0, icon = "Spell_Shadow_RainOfFire", channel = true },

    -- WARRIOR
    ["Slam"] = { casttime = 1.5, icon = "Ability_Warrior_DecisiveStrike" },

    -- SHARED / RACIAL / TRADE
    ["Hearthstone"] = { casttime = 10.0, icon = "INV_Misc_Rune_01" },
    ["War Stomp"] = { casttime = 0.5, icon = "Ability_WarStomp" },
    ["First Aid"] = { casttime = 7.0, icon = "Spell_Holy_Heal", channel = true },
}

-- zhCN localized aliases for Chinese client
if isZh then
    SPELLS["纠缠根须"] = SPELLS["Entangling Roots"]
    SPELLS["治疗之触"] = SPELLS["Healing Touch"]
    SPELLS["休眠"] = SPELLS["Hibernate"]
    SPELLS["复生"] = SPELLS["Rebirth"]
    SPELLS["愈合"] = SPELLS["Regrowth"]
    SPELLS["安抚动物"] = SPELLS["Soothe Animal"]
    SPELLS["星火术"] = SPELLS["Starfire"]
    SPELLS["传送：月光林地"] = SPELLS["Teleport: Moonglade"]
    SPELLS["愤怒"] = SPELLS["Wrath"]
    SPELLS["宁静"] = SPELLS["Tranquility"]
    SPELLS["飓风"] = SPELLS["Hurricane"]

    SPELLS["瞄准射击"] = SPELLS["Aimed Shot"]
    SPELLS["多重射击"] = SPELLS["Multi-Shot"]
    SPELLS["解散野兽"] = SPELLS["Dismiss Pet"]
    SPELLS["野兽之眼"] = SPELLS["Eyes of the Beast"]
    SPELLS["复活宠物"] = SPELLS["Revive Pet"]
    SPELLS["恐吓野兽"] = SPELLS["Scare Beast"]
    SPELLS["鹰眼术"] = SPELLS["Eagle Eye"]

    SPELLS["火球术"] = SPELLS["Fireball"]
    SPELLS["寒冰箭"] = SPELLS["Frostbolt"]
    SPELLS["炎爆术"] = SPELLS["Pyroblast"]
    SPELLS["灼烧"] = SPELLS["Scorch"]
    SPELLS["烈焰风暴"] = SPELLS["Flamestrike"]
    SPELLS["变形术"] = SPELLS["Polymorph"]
    SPELLS["变形术：猪"] = SPELLS["Polymorph: Pig"]
    SPELLS["变形术：龟"] = SPELLS["Polymorph: Turtle"]
    SPELLS["造食术"] = SPELLS["Conjure Food"]
    SPELLS["造水术"] = SPELLS["Conjure Water"]
    SPELLS["奥术飞弹"] = SPELLS["Arcane Missiles"]
    SPELLS["暴风雪"] = SPELLS["Blizzard"]
    SPELLS["唤醒"] = SPELLS["Evocation"]

    SPELLS["圣光术"] = SPELLS["Holy Light"]
    SPELLS["圣光闪现"] = SPELLS["Flash of Light"]
    SPELLS["愤怒之锤"] = SPELLS["Hammer of Wrath"]
    SPELLS["神圣愤怒"] = SPELLS["Holy Wrath"]
    SPELLS["救赎"] = SPELLS["Redemption"]
    SPELLS["召唤军马"] = SPELLS["Summon Warhorse"]
    SPELLS["召唤战马"] = SPELLS["Summon Charger"]
    SPELLS["超度亡灵"] = SPELLS["Turn Undead"]

    SPELLS["快速治疗"] = SPELLS["Flash Heal"]
    SPELLS["强效治疗术"] = SPELLS["Greater Heal"]
    SPELLS["治疗术"] = SPELLS["Heal"]
    SPELLS["次级治疗术"] = SPELLS["Lesser Heal"]
    SPELLS["神圣之火"] = SPELLS["Holy Fire"]
    SPELLS["法力燃烧"] = SPELLS["Mana Burn"]
    SPELLS["心灵震爆"] = SPELLS["Mind Blast"]
    SPELLS["心灵控制"] = SPELLS["Mind Control"]
    SPELLS["治疗祷言"] = SPELLS["Prayer of Healing"]
    SPELLS["复活术"] = SPELLS["Resurrection"]
    SPELLS["束缚亡灵"] = SPELLS["Shackle Undead"]
    SPELLS["惩击"] = SPELLS["Smite"]
    SPELLS["精神鞭笞"] = SPELLS["Mind Flay"]
    SPELLS["心灵视界"] = SPELLS["Mind Vision"]

    SPELLS["解除陷阱"] = SPELLS["Disarm Trap"]
    SPELLS["开锁"] = SPELLS["Pick Lock"]

    SPELLS["治疗链"] = SPELLS["Chain Heal"]
    SPELLS["闪电链"] = SPELLS["Chain Lightning"]
    SPELLS["治疗波"] = SPELLS["Healing Wave"]
    SPELLS["次级治疗波"] = SPELLS["Lesser Healing Wave"]
    SPELLS["闪电箭"] = SPELLS["Lightning Bolt"]
    SPELLS["先祖之魂"] = SPELLS["Ancestral Spirit"]
    SPELLS["星界传送"] = SPELLS["Astral Recall"]
    SPELLS["视界术"] = SPELLS["Far Sight"]
    SPELLS["幽魂之狼"] = SPELLS["Ghost Wolf"]

    SPELLS["放逐术"] = SPELLS["Banish"]
    SPELLS["制造火焰石"] = SPELLS["Create Firestone"]
    SPELLS["制造治疗石"] = SPELLS["Create Healthstone"]
    SPELLS["制造灵魂石"] = SPELLS["Create Soulstone"]
    SPELLS["制造法术石"] = SPELLS["Create Spellstone"]
    SPELLS["奴役恶魔"] = SPELLS["Enslave Demon"]
    SPELLS["恐惧术"] = SPELLS["Fear"]
    SPELLS["恐惧嚎叫"] = SPELLS["Howl of Terror"]
    SPELLS["献祭"] = SPELLS["Immolate"]
    SPELLS["地狱火"] = SPELLS["Inferno"]
    SPELLS["末日仪式"] = SPELLS["Ritual of Doom"]
    SPELLS["召唤仪式"] = SPELLS["Ritual of Summoning"]
    SPELLS["灼热之痛"] = SPELLS["Searing Pain"]
    SPELLS["诱惑"] = SPELLS["Seduction"]
    SPELLS["暗影箭"] = SPELLS["Shadow Bolt"]
    SPELLS["灵魂之火"] = SPELLS["Soul Fire"]
    SPELLS["吸取生命"] = SPELLS["Drain Life"]
    SPELLS["吸取法力"] = SPELLS["Drain Mana"]
    SPELLS["吸取灵魂"] = SPELLS["Drain Soul"]
    SPELLS["生命通道"] = SPELLS["Health Funnel"]
    SPELLS["火焰之雨"] = SPELLS["Rain of Fire"]

    SPELLS["猛击"] = SPELLS["Slam"]

    SPELLS["炉石"] = SPELLS["Hearthstone"]
    SPELLS["战争践踏"] = SPELLS["War Stomp"]
    SPELLS["急救"] = SPELLS["First Aid"]
end

local INTERRUPTS = {
    ["Shield Bash"] = true, ["Pummel"] = true, ["Kick"] = true,
    ["Earth Shock"] = true, ["War Stomp"] = true, ["Counterspell"] = true,
    ["Silence"] = true, ["Gouge"] = true, ["Kidney Shot"] = true,
    ["Cheap Shot"] = true, ["Hammer of Justice"] = true, ["Bash"] = true,
    ["盾牌猛击"] = true, ["拳击"] = true, ["脚踢"] = true,
    ["地震术"] = true, ["战争践踏"] = true, ["法术反制"] = true,
    ["沉默"] = true, ["凿击"] = true, ["肾击"] = true,
    ["偷袭"] = true, ["制裁之锤"] = true, ["重击"] = true,
}

local function StartCast(caster, spell, isChannel)
    if not caster or not spell then return end
    local info = SPELLS[spell]
    local now = GetTime()
    local duration = (info and info.casttime) or 2.0
    local channel = isChannel or (info and info.channel) or false
    local icon = info and info.icon and ("Interface\\Icons\\" .. info.icon) or "Interface\\Icons\\Temp"

    casts[caster] = {
        spell = spell,
        icon = icon,
        timeStart = now,
        timeEnd = now + duration,
        casttime = duration,
        channel = channel,
    }
end

local function StopCast(caster)
    if caster and casts[caster] then
        casts[caster] = nil
    end
end

-------------------------------------------------------------------------------
-- Locale-Specific Combat Log Parser (Avoids mixed regex overhead)
-------------------------------------------------------------------------------
local ParseCombatLog

if isZh then
    -- Chinese (zhCN) Parser: only evaluates Chinese combat log patterns
    ParseCombatLog = function(msg, event)
        -- 1. Death events
        if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" or event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
            local _, _, dc = string.find(msg, "^(.+)死亡了")
            if not dc then
                _, _, dc = string.find(msg, "^(.+)被.+杀死了")
            end
            if dc then
                StopCast(dc)
            end
            return
        end

        -- 2. Cast start
        local _, _, c, s = string.find(msg, "^(.+)开始施放(.-)[。%s]*$")
        if not c then
            _, _, c, s = string.find(msg, "^(.+)正在施放(.-)[。%s]*$")
        end
        if not c then
            _, _, c, s = string.find(msg, "^(.+)开始施展(.-)[。%s]*$")
        end
        if not c then
            _, _, c, s = string.find(msg, "^(.+)施放了(.-)[。%s]*$")
        end

        if c and s then
            s = string.gsub(s, "[。%.%s]+$", "")
            StartCast(c, s, false)
            return
        end

        -- 3. Channeling detection via periodic gain
        local _, _, gc, gs = string.find(msg, "^(.+)获得了(.-)的效果")
        if gc and gs then
            gs = string.gsub(gs, "[。%.%s]+$", "")
            if SPELLS[gs] and SPELLS[gs].channel then
                StartCast(gc, gs, true)
                return
            end
        end

        -- 4. Interrupted detection
        local _, _, ic = string.find(msg, "打断了(.+)的")
        if ic then
            StopCast(ic)
            return
        end
    end
else
    -- English (enUS / default) Parser: only evaluates English combat log patterns
    ParseCombatLog = function(msg, event)
        -- 1. Death events
        if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" or event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
            local _, _, dc = string.find(msg, "^(.+) dies%.")
            if not dc then
                _, _, dc = string.find(msg, "^(.+) is slain by")
            end
            if dc then
                StopCast(dc)
            end
            return
        end

        -- 2. Cast start
        local _, _, c, s = string.find(msg, "^(.+) begins to cast (.+)%.")
        if not c then
            _, _, c, s = string.find(msg, "^(.+) begins to perform (.+)%.")
        end
        if not c then
            _, _, c, s = string.find(msg, "^(.+) casts (.+)%.")
        end

        if c and s then
            StartCast(c, s, false)
            return
        end

        -- 3. Channeling detection via periodic gain
        local _, _, gc, gs = string.find(msg, "^(.+) gains (.+)%.")
        if gc and gs and SPELLS[gs] and SPELLS[gs].channel then
            StartCast(gc, gs, true)
            return
        end

        -- 4. Interrupted detection
        local _, _, ic = string.find(msg, "interrupts? (.+)'s")
        if ic then
            StopCast(ic)
            return
        end
    end
end

-------------------------------------------------------------------------------
-- Combat Log Parsing Frame
-------------------------------------------------------------------------------
local logFrame = CreateFrame("Frame")
logFrame:Hide()
logFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
logFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
logFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS")
logFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
logFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
logFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF")
logFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
logFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")

logFrame:SetScript("OnEvent", function()
    if not arg1 then return end
    ParseCombatLog(arg1, event)
end)

-------------------------------------------------------------------------------
-- Player Cast Tracking & Blizzard CastingBar Suppression (Reversible / Non-destructive)
-------------------------------------------------------------------------------
local playerCast = nil
local playerSpellIcons = {}

local function HideBlizzardCastbar()
    if not CastingBarFrame then return end
    CastingBarFrame:Hide()
    CastingBarFrame.Show = function() end
end
HideBlizzardCastbar()

local function RebuildSpellIconMap()
    for i = 1, 300 do
        local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
        if not name then break end
        local tex = GetSpellTexture(i, BOOKTYPE_SPELL or "spell")
        if tex and not playerSpellIcons[name] then
            playerSpellIcons[name] = tex
        end
    end
end

local function GetPlayerSpellTexture(spellName)
    if not spellName or spellName == "" then return "Interface\\Icons\\Temp" end
    local cached = playerSpellIcons[spellName]
    if cached then return cached end

    RebuildSpellIconMap()
    if playerSpellIcons[spellName] then
        return playerSpellIcons[spellName]
    end

    local entry = SPELLS[spellName]
    local icon = entry and entry.icon or "Temp"
    if not string.find(icon, "\\") then icon = "Interface\\Icons\\" .. icon end
    playerSpellIcons[spellName] = icon
    return icon
end

local playerEvents = CreateFrame("Frame")
playerEvents:Hide()
playerEvents:RegisterEvent("PLAYER_LOGIN")
playerEvents:RegisterEvent("SPELLS_CHANGED")
playerEvents:RegisterEvent("SPELLCAST_START")
playerEvents:RegisterEvent("SPELLCAST_STOP")
playerEvents:RegisterEvent("SPELLCAST_FAILED")
playerEvents:RegisterEvent("SPELLCAST_INTERRUPTED")
playerEvents:RegisterEvent("SPELLCAST_DELAYED")
playerEvents:RegisterEvent("SPELLCAST_CHANNEL_START")
playerEvents:RegisterEvent("SPELLCAST_CHANNEL_UPDATE")
playerEvents:RegisterEvent("SPELLCAST_CHANNEL_STOP")
playerEvents:RegisterEvent("PLAYER_DEAD")

playerEvents:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" then
        RebuildSpellIconMap()
        return
    elseif event == "SPELLCAST_START" then
        local duration = (arg2 or 0) / 1000
        local now = GetTime()
        playerCast = {
            spell = arg1 or "",
            icon = GetPlayerSpellTexture(arg1),
            startTime = now,
            endTime = now + duration,
            total = duration,
            channel = false,
        }
    elseif event == "SPELLCAST_STOP" then
        if playerCast and not playerCast.channel then
            playerCast = nil
        end
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" or event == "PLAYER_DEAD" then
        playerCast = nil
    elseif event == "SPELLCAST_DELAYED" then
        if playerCast and not playerCast.channel and arg1 then
            local delay = arg1 / 1000
            playerCast.startTime = playerCast.startTime + delay
            playerCast.endTime = playerCast.endTime + delay
            playerCast.total = playerCast.endTime - playerCast.startTime
        end
    elseif event == "SPELLCAST_CHANNEL_START" then
        local duration = (arg1 or 0) / 1000
        local now = GetTime()
        playerCast = {
            spell = arg2 or "",
            icon = GetPlayerSpellTexture(arg2),
            startTime = now,
            endTime = now + duration,
            total = duration,
            channel = true,
        }
    elseif event == "SPELLCAST_CHANNEL_UPDATE" then
        if playerCast and playerCast.channel then
            if not arg1 or arg1 == 0 then
                playerCast = nil
            else
                local remaining = arg1 / 1000
                local now = GetTime()
                local origDuration = playerCast.total
                playerCast.endTime = now + remaining
                playerCast.startTime = playerCast.endTime - origDuration
            end
        end
    elseif event == "SPELLCAST_CHANNEL_STOP" then
        if playerCast and playerCast.channel then
            playerCast = nil
        end
    end
end)

-------------------------------------------------------------------------------
-- Cast Query Helper (Combines Native API & Combat Log Cache)
-------------------------------------------------------------------------------
local function SafeUnitExists(unit)
    if not unit or unit == "" then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and exists
end

local function SafeUnitName(unit)
    if not unit or not SafeUnitExists(unit) then return nil end
    local ok, name = pcall(UnitName, unit)
    return ok and name or nil
end

local function SafeUnitIsDeadOrGhost(unit)
    if not unit or not SafeUnitExists(unit) then return false end
    local ok, dead = pcall(UnitIsDead, unit)
    if ok and dead then return true end
    local okg, ghost = pcall(UnitIsGhost, unit)
    if okg and ghost then return true end
    return false
end

-- Reusable cast data table. GetUnitCastData runs at 20Hz for 3 bars, so returning
-- a freshly built table each tick allocated ~60 tables/sec for nothing: callers
-- read the fields immediately and never keep a reference to the table.
local cast_data = {}
local function fill_cast_data(spell, icon, cur, total, rem, channel)
    cast_data.spell = spell
    cast_data.icon = icon
    cast_data.cur = cur
    cast_data.total = total
    cast_data.rem = rem
    cast_data.channel = channel
    return cast_data
end

-- Same as SafeUnitName but WITHOUT the existence check. Use it whenever the
-- caller already verified UnitExists, to avoid a second pcall per tick.
local function get_unit_name(unit)
    if not unit or unit == "" then return nil end
    local ok, name = pcall(UnitName, unit)
    return ok and name or nil
end

local function GetUnitCastData(unit, fallbackName)
    -- 1. Fast path for player: prioritize SPELLCAST_* events, zero allocation & zero pcall
    if unit == "player" then
        if playerCast then
            local now = GetTime()
            if now < playerCast.endTime then
                local total = playerCast.total
                if total <= 0 then total = 0.001 end
                local cur
                if playerCast.channel then
                    cur = playerCast.endTime - now
                else
                    cur = now - playerCast.startTime
                end
                if cur < 0 then cur = 0 end
                if cur > total then cur = total end

                local rem = playerCast.channel and cur or (total - cur)
                if rem < 0 then rem = 0 end
                if rem > total then rem = total end

                return fill_cast_data(playerCast.spell, playerCast.icon, cur, total, rem, playerCast.channel)
            else
                playerCast = nil
            end
        end

        -- Secondary fallback for player if extension like SuperWoW triggers cast without event
        local UnitCastingInfo = _G.UnitCastingInfo or (ShaguTweaks and ShaguTweaks.UnitCastingInfo)
        local UnitChannelInfo = _G.UnitChannelInfo or (ShaguTweaks and ShaguTweaks.UnitChannelInfo)
        if UnitCastingInfo then
            local ok, s, ns, t, tex, st, et = pcall(UnitCastingInfo, "player")
            local isChannel = false
            if not (ok and s) and UnitChannelInfo then
                local okc, cs, cns, ct, ctex, cst, cet = pcall(UnitChannelInfo, "player")
                if okc and cs then
                    s, tex, st, et = cs, ctex, cst, cet
                    isChannel = true
                end
            end
            if s and st and et and et > st then
                local now = GetTime()
                local total = (et - st) / 1000
                local cur = isChannel and ((et / 1000) - now) or (now - (st / 1000))
                if cur < 0 then cur = 0 end
                if cur > total then cur = total end
                local rem = isChannel and cur or (total - cur)
                if rem < 0 then rem = 0 end
                if rem > total then rem = total end

                return fill_cast_data(s, tex or playerSpellIcons[s] or "Interface\\Icons\\Temp", cur, total, rem, isChannel)
            end
        end
        return nil
    end

    -- 2. Target / Focus path
    if unit and not SafeUnitExists(unit) then
        unit = nil
    end

    if unit and SafeUnitIsDeadOrGhost(unit) then
        if fallbackName then
            casts[fallbackName] = nil
        end
        return nil
    end

    -- Try native UnitCastingInfo / UnitChannelInfo
    if unit then
        local UnitCastingInfo = _G.UnitCastingInfo or (ShaguTweaks and ShaguTweaks.UnitCastingInfo)
        local UnitChannelInfo = _G.UnitChannelInfo or (ShaguTweaks and ShaguTweaks.UnitChannelInfo)

        if UnitCastingInfo then
            local spell, nameSubtext, text, texture, startTime, endTime, isTradeSkill
            local ok, s, ns, t, tex, st, et, ts = pcall(UnitCastingInfo, unit)
            if ok and s then
                spell, nameSubtext, text, texture, startTime, endTime, isTradeSkill = s, ns, t, tex, st, et, ts
            end

            local isChannel = false
            if not spell and UnitChannelInfo then
                local okc, cs, cns, ct, ctex, cst, cet, cts = pcall(UnitChannelInfo, unit)
                if okc and cs then
                    spell, nameSubtext, text, texture, startTime, endTime, isTradeSkill = cs, cns, ct, ctex, cst, cet, cts
                    isChannel = true
                end
            end

            if spell and startTime and endTime and endTime > startTime then
                local now = GetTime()
                local total = (endTime - startTime) / 1000
                local cur = isChannel and ((endTime / 1000) - now) or (now - (startTime / 1000))
                if cur < 0 then cur = 0 end
                if cur > total then cur = total end

                local rem = isChannel and cur or (total - cur)
                if rem < 0 then rem = 0 end
                if rem > total then rem = total end

                return fill_cast_data(spell, texture or "Interface\\Icons\\Temp", cur, total, rem, isChannel)
            end
        end

        if not fallbackName then
            fallbackName = get_unit_name(unit)
        end
    end

    -- 3. Fallback to name-based combat log tracker
    if fallbackName and casts[fallbackName] then
        local entry = casts[fallbackName]
        local now = GetTime()
        if now < entry.timeEnd then
            local total = entry.casttime
            if total <= 0 then total = 0.001 end
            local cur = entry.channel and (entry.timeEnd - now) or (now - entry.timeStart)
            if cur < 0 then cur = 0 end
            if cur > total then cur = total end

            local rem = entry.channel and cur or (total - cur)
            if rem < 0 then rem = 0 end
            if rem > total then rem = total end

            return fill_cast_data(entry.spell, entry.icon, cur, total, rem, entry.channel)
        else
            casts[fallbackName] = nil
        end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Castbar Factory
-------------------------------------------------------------------------------
local function CreateCastbar(frameName, defaultParent, dbKey, getUnitFunc, defaultAnchor)
    local bar = CreateFrame("StatusBar", frameName, UIParent)
    bar:SetWidth(150)
    bar:SetHeight(13)
    bar:SetFrameStrata("HIGH")
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1.0, 0.7, 0.0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    -- Movable configuration
    bar:SetMovable(true)
    bar:EnableMouse(false)
    bar:RegisterForDrag("LeftButton")

    if dbKey == "player_castbar_pos" then
        bar:SetScale(OzUF.GetPlayerCastbarScale and OzUF.GetPlayerCastbarScale() or 1.0)
    elseif dbKey == "target_castbar_pos" then
        bar:SetScale(OzUF.GetTargetCastbarScale and OzUF.GetTargetCastbarScale() or 1.0)
    else
        bar:SetScale(OzUF.GetFocusCastbarScale and OzUF.GetFocusCastbarScale() or 1.0)
    end

    bar.dbKey = dbKey
    bar.getUnit = getUnitFunc
    bar.defaultParent = defaultParent
    bar.defaultAnchor = defaultAnchor

    -- Background texture
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.75)
    bar.bg = bg

    -- Spark
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetWidth(20)
    spark:SetHeight(26)
    spark:SetBlendMode("ADD")
    bar.spark = spark

    -- Outer border (Matches standard UI-Tooltip-Border / unitframe style)
    local border = CreateFrame("Frame", nil, bar)
    border:SetFrameStrata("HIGH")
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    border:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.9)
    bar.border = border

    -- Spell Icon with border box
    local iconFrame = CreateFrame("Frame", nil, bar)
    iconFrame:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    iconFrame:SetWidth(18)
    iconFrame:SetHeight(18)
    iconFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    iconFrame:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.9)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    icon:SetWidth(14)
    icon:SetHeight(14)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.icon = icon

    -- Spell Name Text (Left / Center)
    local spellText = bar:CreateFontString(nil, "OVERLAY")
    spellText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    spellText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    spellText:SetPoint("RIGHT", bar, "RIGHT", -48, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetTextColor(1, 1, 1, 1)
    bar.spellText = spellText

    -- Remaining / Total Cast Time Text (Right)
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1, 1, 1, 1)
    bar.timeText = timeText

    -- Latency Bar (Visual network latency overlay indicator)
    local latency = bar:CreateTexture(nil, "ARTWORK")
    latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    latency:SetVertexColor(0.8, 0.0, 0.0, 0.65)
    latency:Hide()
    bar.latency = latency

    -- Drag / Move hint label
    local moveLabel = bar:CreateFontString(nil, "OVERLAY")
    moveLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    moveLabel:SetPoint("BOTTOM", bar, "TOP", 0, 6)
    moveLabel:SetTextColor(1, 0.82, 0, 1)
    moveLabel:SetText(L_DRAG_HINT)
    moveLabel:Hide()
    bar.moveLabel = moveLabel

    -- Position loading and saving
    bar.LoadPosition = function(self)
        OzUF_DB = OzUF_DB or {}
        local pos = OzUF_DB[self.dbKey]
        if pos and pos.x and pos.y then
            self:ClearAllPoints()
            if pos.point and pos.relPoint then
                self:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
            else
                self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
            end
            self.hasCustomPos = true
        else
            self.hasCustomPos = false
            self:ResetToDefaultPosition()
        end
    end

    bar.ResetToDefaultPosition = function(self)
        self:ClearAllPoints()
        local parent = self.defaultParent
        if type(parent) == "function" then parent = parent() end
        if parent and parent.GetPoint then
            local a = self.defaultAnchor
            self:SetPoint(a.point or "TOP", parent, a.relPoint or "BOTTOM", a.x or 0, a.y or 0)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    -- Drag scripts
    bar:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    bar:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        OzUF_DB = OzUF_DB or {}
        local point, _, relPoint, x, y = this:GetPoint()
        OzUF_DB[this.dbKey] = {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y
        }
        this.hasCustomPos = true
    end)

    return bar
end

-------------------------------------------------------------------------------
-- Player, Target and Focus Castbar Instances
-------------------------------------------------------------------------------
-- 1. Player Castbar: defaults to BOTTOM of PlayerFrame (x=20, y=-4)
local playerCastbar = CreateCastbar(
    "OzUFPlayerCastbar",
    PlayerFrame,
    "player_castbar_pos",
    function()
        return "player", nil
    end,
    { point = "TOP", relPoint = "BOTTOM", x = 20, y = -4 }
)

-- 2. Target Castbar: defaults to BOTTOM of TargetFrame (x=10, y=-4)
local targetCastbar = CreateCastbar(
    "OzUFTargetCastbar",
    TargetFrame,
    "target_castbar_pos",
    function()
        if SafeUnitExists("target") then
            return "target", get_unit_name("target")
        end
        return nil, nil
    end,
    { point = "TOP", relPoint = "BOTTOM", x = 10, y = -4 }
)

-- 3. Focus Castbar: defaults to BOTTOM of OzUFFocusFrame (x=-10, y=-4)
local focusCastbar = CreateCastbar(
    "OzUFFocusCastbar",
    function() return OzUF.FocusFrame or _G.OzUFFocusFrame end,
    "focus_castbar_pos",
    function()
        local fUnit = OzUF.Focus and OzUF.Focus.unit
        if fUnit and SafeUnitExists(fUnit) then
            return fUnit, (OzUF.Focus and OzUF.Focus.name) or get_unit_name(fUnit)
        end
        if SafeUnitExists("focus") then
            return "focus", (OzUF.Focus and OzUF.Focus.name) or get_unit_name("focus")
        end
        if OzUF.Focus and OzUF.Focus.name then
            return nil, OzUF.Focus.name
        end
        return nil, nil
    end,
    { point = "TOP", relPoint = "BOTTOM", x = -10, y = -4 }
)

OzUF.Castbars.Player = playerCastbar
OzUF.Castbars.Target = targetCastbar
OzUF.Castbars.Focus = focusCastbar

-------------------------------------------------------------------------------
-- Latency Cache (1Hz refresh)
-------------------------------------------------------------------------------
local lastNetUpdate = 0
local cachedLag = 0
local function GetCachedLag()
    local now = GetTime()
    if now - lastNetUpdate > 1.0 then
        lastNetUpdate = now
        local _, _, lag = GetNetStats()
        cachedLag = lag or 0
    end
    return cachedLag
end

-------------------------------------------------------------------------------
-- Update Tick Logic (Per-frame OnUpdate)
-------------------------------------------------------------------------------
local function UpdateSingleCastbar(bar, isUnlocked)
    local unit, fallbackName = bar.getUnit()

    -- In unlocked / moving mode: keep bar visible with demo content
    if isUnlocked then
        bar:Show()
        bar:SetAlpha(1.0)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.65)
        bar.spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * 0.65, 0)
        bar.spark:Show()
        local label = bar.dbKey == "player_castbar_pos" and L_PLAYER_CASTBAR or (bar.dbKey == "target_castbar_pos" and L_TARGET_CASTBAR or L_FOCUS_CASTBAR)
        if bar.currentSpell ~= label then
            bar.currentSpell = label
            bar.spellText:SetText(label)
        end
        bar.timeText:SetText("1.5 / 2.5s")
        if bar.currentIcon ~= "Interface\\Icons\\Spell_Fire_FlameBolt" then
            bar.currentIcon = "Interface\\Icons\\Spell_Fire_FlameBolt"
            bar.icon:SetTexture(bar.currentIcon)
            bar.icon:Show()
        end
        bar.moveLabel:Show()

        -- Latency indicator demo (150ms on a 2.5s cast)
        local latWidth = (0.15 / 2.5) * bar:GetWidth()
        if latWidth > bar:GetWidth() then latWidth = bar:GetWidth() end
        bar.latency:ClearAllPoints()
        bar.latency:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        bar.latency:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        bar.latency:SetWidth(latWidth)
        bar.latency:Show()
        return
    else
        bar.moveLabel:Hide()
    end

    -- Real unit cast data update
    local data = GetUnitCastData(unit, fallbackName)
    if data then
        local total = data.total
        local cur = data.cur
        local rem = data.rem
        if total <= 0 then total = 0.001 end

        bar:SetMinMaxValues(0, total)
        bar:SetValue(cur)

        -- Spark positioning
        local sparkPos = (cur / total) * bar:GetWidth()
        if sparkPos < 0 then sparkPos = 0 end
        if sparkPos > bar:GetWidth() then sparkPos = bar:GetWidth() end
        bar.spark:SetPoint("CENTER", bar, "LEFT", sparkPos, 0)
        bar.spark:Show()

        -- Spell text & Icon (with change detection)
        if bar.currentSpell ~= data.spell then
            bar.currentSpell = data.spell
            bar.spellText:SetText(data.spell)
        end
        if bar.currentIcon ~= data.icon then
            bar.currentIcon = data.icon
            if data.icon then
                bar.icon:SetTexture(data.icon)
                bar.icon:Show()
            else
                bar.icon:Hide()
            end
        end

        -- Remaining and Total time text: "1.2 / 2.5s"
        bar.timeText:SetText(string.format("%.1f / %.1fs", rem, total))

        -- Latency indicator: cached lag from GetCachedLag()
        local lag = GetCachedLag()
        local lagSeconds = lag / 1000
        if lagSeconds > 0 and total > 0 then
            local latRatio = lagSeconds / total
            if latRatio > 1 then latRatio = 1 end
            local latWidth = bar:GetWidth() * latRatio

            bar.latency:ClearAllPoints()
            if data.channel then
                -- For channeled spells, latency is at the start (LEFT side)
                bar.latency:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
                bar.latency:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            else
                -- For normal casts, latency is at the end (RIGHT side / spell-queue zone)
                bar.latency:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
                bar.latency:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            end
            bar.latency:SetWidth(latWidth)
            bar.latency:Show()
        else
            bar.latency:Hide()
        end

        bar:Show()
        bar:SetAlpha(1.0)
    else
        bar.currentSpell = nil
        bar.currentIcon = nil
        bar:Hide()
    end
end

-------------------------------------------------------------------------------
-- Controller Frame: Movable Unlocking & Global OnUpdate (Throttled to 20Hz)
-------------------------------------------------------------------------------
local controller = CreateFrame("Frame", "OzUFCastbarController", UIParent)
controller.isUnlocked = false
controller.lastUnlockState = nil

controller:RegisterEvent("VARIABLES_LOADED")
controller:RegisterEvent("PLAYER_ENTERING_WORLD")
controller:RegisterEvent("PLAYER_TARGET_CHANGED")

controller:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        HideBlizzardCastbar()
        playerCastbar:LoadPosition()
        targetCastbar:LoadPosition()
        focusCastbar:LoadPosition()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if not SafeUnitExists("target") then
            targetCastbar:Hide()
        end
    end
end)

local tick = 0
controller:SetScript("OnUpdate", function()
    tick = tick + arg1
    if tick < 0.05 then return end
    tick = 0

    -- Check if user is holding Shift+Ctrl to unlock castbars for dragging
    local shiftCtrl = IsShiftKeyDown() and IsControlKeyDown()

    if shiftCtrl then
        if not controller.isShiftCtrlUnlocked then
            controller.isShiftCtrlUnlocked = true
        end
    else
        if controller.isShiftCtrlUnlocked then
            controller.isShiftCtrlUnlocked = false
            playerCastbar:StopMovingOrSizing()
            targetCastbar:StopMovingOrSizing()
            focusCastbar:StopMovingOrSizing()
        end
    end

    local isUnlocked = controller.isUnlocked or controller.isShiftCtrlUnlocked or (OzUF.IsFramesUnlocked and OzUF.IsFramesUnlocked())

    if isUnlocked ~= controller.lastUnlockState then
        controller.lastUnlockState = isUnlocked
        playerCastbar:EnableMouse(isUnlocked)
        targetCastbar:EnableMouse(isUnlocked)
        focusCastbar:EnableMouse(isUnlocked)
    end

    UpdateSingleCastbar(playerCastbar, isUnlocked)
    UpdateSingleCastbar(targetCastbar, isUnlocked)
    UpdateSingleCastbar(focusCastbar, isUnlocked)
end)
