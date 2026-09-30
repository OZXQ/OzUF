# OzUF (Oz Unit Frames) - Product Requirements Document (PRD)

## 1. Document Overview

| Attribute | Details |
| :--- | :--- |
| **Project Name** | **OzUF** (Oz Unit Frames) |
| **Target Client** | World of Warcraft 1.12.1 (Client Build 5875) / Turtle WoW / SuperWoW |
| **Runtime Language** | Lua 5.0.2 (Pure Lua UI, Strict 1.12 Dialect) |
| **SavedVariables** | `OzUF_DB` (Optional mob health cache) |
| **Primary Philosophy** | **Faithful Feature Cloning & Minimalist Simplicity**: Direct clone of the 6 core ShaguTweaks / ShaguTweaks-more-mods unit frame features, sorted cleanly into 4 modular unit frame files (`playerframe.lua`, `targetframe.lua`, `focusframe.lua`, `partyframe.lua`). No extra defensive code beyond original implementations. |
| **Document Version** | 2.0.0 |
| **Status** | Approved for Implementation |

---

## 2. Product Goals & Architectural Principles

1. **Direct Feature Parity**:
   - Clone the exact functionality of the reference implementations from ShaguTweaks and ShaguTweaks-more-mods:
     - `health-numbers.lua`
     - `unitframe-energytick.lua`
     - `unitframes-classcolor.lua`
     - `unitframes-classportrait.lua`
     - `unitframes-morebuffs.lua`
     - `unitframes-bighealth-new.lua`
2. **Modular File Organization**:
   - Instead of fragmented generic tweak modules, features are logically grouped by unit frame:
     - `playerframe.lua`: Player frame & pet frame enhancements.
     - `targetframe.lua`: Target frame & target-of-target enhancements.
     - `focusframe.lua`: Focus frame (full-featured clone with matching visuals and `/focus` controls).
     - `partyframe.lua`: Party members 1–4 enhancements.
     - `OzUF.lua`: Shared helpers (number abbreviation, mob health estimation cache, class texture coordinates).
3. **No Extra Defensive Code**:
   - Follow the simple, direct pattern of the original ShaguTweaks source. No bloated abstraction layers, redundant sanity wrappers, or complex multi-tiered fallbacks unless present in the original code.
4. **Enhanced Visual Presentation**:
   - 30px height health bars for Player, Target, and Focus.
   - Textures:
     - `UI-TargetingFrame2.blp` (Normal)
     - `UI-TargetingFrame-Elite.blp` (Elite / RareElite / WorldBoss)
     - `UI-TargetingFrame-Elite-Rare.blp` (Rare)
   - Texture orientation:
     - TargetFrame & FocusFrame: standard orientation (`SetTexCoord(0, 1, 0, 1)`).
     - PlayerFrame: flipped left-to-right (`SetTexCoord(1, 0, 0, 1)`).

---

## 3. Scope of Features & Module Matrix

| Feature | Reference Source | Target Module(s) | Description |
| :--- | :--- | :--- | :--- |
| **Big Health Bar & New Textures** | `unitframes-bighealth-new.lua` | `playerframe.lua`<br>`targetframe.lua`<br>`focusframe.lua` | 30px height health bar; custom background textures (`UI-TargetingFrame2`, `UI-TargetingFrame-Elite`, `UI-TargetingFrame-Elite-Rare`); flipped horizontally for player; health bar status bar color matches class/faction reaction; ToT and Pet repositioning. |
| **Health & Mana Numbers** | `health-numbers.lua` | `playerframe.lua`<br>`targetframe.lua`<br>`focusframe.lua` | Status bar text strings (`cur - percent%` when damaged, `cur` when full) with outline font; mob health estimation via LibHealth cache. |
| **Energy & Mana Ticks** | `unitframe-energytick.lua` | `playerframe.lua` | Moving spark ticker on player mana/energy bar: 2s energy tick for Rogue/Druid, 5s rule and 2s tick for mana classes. Automatically hidden when full out of combat. |
| **Unit Frame Class Colors** | `unitframes-classcolor.lua` | `playerframe.lua`<br>`targetframe.lua`<br>`partyframe.lua` | Class-colored name backgrounds and health bars; NPC reaction-colored name backgrounds; party member names colored by class (`RAID_CLASS_COLORS`). |
| **Unit Frame Class Portraits** | `unitframes-classportrait.lua` | `playerframe.lua`<br>`targetframe.lua`<br>`focusframe.lua`<br>`partyframe.lua` | Circular class icons (`UI-Classes-Circles.tga`) replace unit portraits for player characters across all frames. |
| **More Buffs & Debuffs** | `unitframes-morebuffs.lua` | `targetframe.lua`<br>`focusframe.lua` | Expands target (and focus) to display up to 64 buffs and 128 debuffs with dynamic multi-row arrangement (friendly: buffs first; hostile: debuffs first). |

---

## 4. Visual Layout & Texture Specifications

### 4.1. Frame Textures
- **Textures Path**: `Interface\AddOns\OzUF\texture\`
  - `UI-TargetingFrame2.blp`: Normal unit background.
  - `UI-TargetingFrame-Elite.blp`: Elite, RareElite, WorldBoss background (dragon adornment).
  - `UI-TargetingFrame-Elite-Rare.blp`: Rare unit background (silver dragon adornment).
  - `UI-Classes-Circles.tga`: Class circle portrait icons.
  - `UI-Player-Status.tga`: Rest/combat player status glow texture.

### 4.2. Texture Coordinate Flipping
- TargetFrame / FocusFrame:
  ```lua
  TargetFrameTexture:SetTexCoord(0, 1, 0, 1)
  ```
- PlayerFrame:
  ```lua
  PlayerFrameTexture:SetTexCoord(1, 0, 0, 1)
  ```

### 4.3. Dimensions & Offsets
- **PlayerFrame**:
  - `PlayerFrameHealthBar`: Anchor `TOPLEFT(106, -23)`, Width = `120`, Height = `30`.
  - `PlayerFrameManaBar`: Width = `120`.
  - `PlayerFrameBackground`: Width = `122`.
  - `PlayerFrameHealthBar.TextString`: Anchor `TOP` to `PlayerFrameHealthBar` `BOTTOM(0, 23)`.
  - `PetFrame`: Anchor `BOTTOM` to `PlayerFrame(-10, -30)`.
- **TargetFrame**:
  - `TargetFrameHealthBar`: Anchor `TOPRIGHT(-103, -23)`, Width = `123`, Height = `30`.
  - `TargetFrameManaBar`: Anchor `TOPRIGHT(-103, -52)`, Width = `123`.
  - `TargetFrameBackground`: Anchor `TOPRIGHT(-103, -22)`, Width = `123`.
  - `TargetFrameHealthBar.TextString`: Anchor `TOP` to `TargetFrameHealthBar` `BOTTOM(-2, 23)`.
  - `TargetofTargetFrame`: Anchor `BOTTOM` to `TargetFrame(38, -15)`.
- **FocusFrame**:
  - Structured identically to TargetFrame (width 232, height 100), with 30px health bar, 123px width, matching font strings, and up to 64 buffs / 128 debuffs.

---

## 5. Module Implementation Specifications

### 5.1. `OzUF.lua` (Common Utilities)
- `OzUF.Abbreviate(number, eachk)`: Formats numbers into `k` (thousands) or `m` (millions) with rounding.
- `OzUF.CLASS_ICON`: Table mapping class tokens to dedicated class portrait textures (`texture/class_<class>.blp`).

### 5.2. `playerframe.lua`
- **Big Health Bar**:
  - Re-anchors and resizes `PlayerFrameHealthBar` to (106, -23) 120x30.
  - Health bar status bar color permanently assigned to player's class color:
    ```lua
    PlayerFrameHealthBar._SetStatusBarColor = PlayerFrameHealthBar.SetStatusBarColor
    PlayerFrameHealthBar.SetStatusBarColor = function() end
    PlayerFrameHealthBar:_SetStatusBarColor(r, g, b, 1)
    ```
- **Flipped Background Texture**:
  - Checks classification (`UnitClassification("player")`), applies `UI-TargetingFrame2` or elite/rare textures with `SetTexCoord(1, 0, 0, 1)`.
- **Class Portrait**:
  - Hooks `UnitFrame_Update` and `UNIT_PORTRAIT_UPDATE` to assign `UI-Classes-Circles` with player's class tex coordinates.
- **Health & Mana Numbers**:
  - Formats `PlayerFrameHealthBar.TextString` and `PlayerFrameManaBar.TextString` via hooked `TextStatusBar_UpdateTextString`.
  - Uses `GameFontWhite`, font `STANDARD_TEXT_FONT, 10, "OUTLINE"`.
  - Shows `cur - percent%` when damaged, `cur` when full.
- **Energy & Mana Ticks**:
  - Frame attached to `PlayerFrameManaBar`.
  - Spark texture `Interface\CastingBar\UI-CastingBar-Spark`.
  - 2s energy cycle for energy units; 5s rule and 2s tick for mana units.
  - Automatically hidden when full and out of combat.
- **PetFrame Adjustments**:
  - Re-anchored to `PlayerFrame` `BOTTOM(-10, -30)`.
  - Health and mana numbers configured with font size 9 outline, left-aligned.

### 5.3. `targetframe.lua`
- **Big Health Bar & Classification Textures**:
  - Hooks `TargetFrame_CheckClassification` to assign `UI-TargetingFrame-Elite` (boss/elite/rareelite), `UI-TargetingFrame-Elite-Rare` (rare), or `UI-TargetingFrame2` (normal).
  - Positions `TargetFrameHealthBar` at `TOPRIGHT(-103, -23)`, 123x30.
- **Target Health Bar Color**:
  - In `TargetFrame_CheckFaction`, hooks `TargetFrameHealthBar` to use `TargetFrameNameBackground` vertex color (class color for players, reaction color for NPCs).
- **Target of Target**:
  - Repositioned at `BOTTOM(38, -15)` relative to `TargetFrame`.
  - Updates class portrait on `TargetofTargetFrame`.
- **Health & Mana Numbers**:
  - StatusTexts overlay frame created for `TargetFrame`.
  - Real mob health estimated via `OzUF.libhealth:GetUnitHealth("target")`.
  - Hidden when target is dead or ghost.
- **Class Portrait**:
  - Replaces `TargetFramePortrait` with class circle icon if target is player.
- **More Buffs & Debuffs**:
  - Expands target buffs up to 64 and debuffs up to 128.
  - `ArrangeButtonGroup` logic:
    - Buffs & debuffs are anchored above the frame (stacking upwards), leaving the bottom clear for castbars and target of target.
    - Friendly target: Buffs row displayed first, Debuffs above.
    - Hostile target: Debuffs row displayed first, Buffs above.

### 5.4. `focusframe.lua`
- **Frame Instantiation**:
  - Creates `OzUFFocusFrame` matching TargetFrame layout in pure Lua.
  - Big 30px health bar, 123px width, status bar text strings.
  - Movable by mouse drag (Shift-drag or unlocked) with screen clamping.
- **Textures & Visuals**:
  - Classification checking on focus unit: `UI-TargetingFrame2`, `UI-TargetingFrame-Elite`, `UI-TargetingFrame-Elite-Rare`.
  - Class circular portrait for player focus targets (`UI-Classes-Circles`).
  - Raid target, group leader, and PVP status icons.
  - Difficulty level text coloring and skull texture for high-level/boss mobs.
- **Focus Target (FocusTarget / Focus of Target)**:
  - Child frame `OzUFFocusTargetFrame` (93x45) positioned at `BOTTOM(38, -15)`.
  - Displays target of focus unit (`focustarget` or `<unit>target`).
  - Health and mana bars, name with class/reaction color, dead text, and circular class portrait.
  - Left-click targeting to select the focus' target.
- **Health & Mana Numbers**:
  - Displayed in `cur - percent%` and `cur` formats using `OzUF.Abbreviate`.
- **Buffs & Debuffs**:
  - Up to 16 buffs and 16 debuffs arranged dynamically above the frame.
- **Commands & Target Resolution**:
  - `/focus`: Sets current target as focus and plays creature/NPC selection sound.
  - `/clearfocus`: Clears focus and hides FocusFrame and FocusTarget.
  - Maintains full unit state caching (level, classification, skull, health/mana numbers, buffs, debuffs, portrait) so focus frame persists seamlessly when target changes.
  - Scans target/mouseover/party/raid, party/raid targets, and SuperWoW mark1-8 / GUIDs to update live data whenever observed.
  - Left-click `OzUFFocusFrame` targets the focused unit.

### 5.5. `partyframe.lua`
- **Class Colored Names**:
  - Hooks `PartyMemberFrame_UpdateMember` to color `PartyMemberFrameXName` with `RAID_CLASS_COLORS[class]`.
- **Class Portraits**:
  - Replaces `PartyMemberFrameXPortrait` with dedicated class portrait icon (`OzUF.CLASS_ICON[class]`) on `PLAYER_ENTERING_WORLD`, `UNIT_PORTRAIT_UPDATE`, and member update.

---

## 6. Technical Constraints & Code Quality Rules

1. **Strict Lua 5.0.2 Compatibility**:
   - No `#` operator (`table.getn` / `string.len`).
   - No `//` integer division (`math.floor`).
   - No `string.gmatch` (`string.gfind`).
   - Script handlers use `this`, `event`, `arg1`..`arg9`.
2. **No Extra Defensive Code**:
   - Keep logic concise, direct, and unbloated, identical to the reference ShaguTweaks scripts.
   - No unnecessary deep tables, complex option wrappers, or redundant nil checks where FrameXML guaranteed existence.
