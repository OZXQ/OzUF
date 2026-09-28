# OzUF (Oz Unit Frames) - Product Requirements Document (PRD)

## 1. Document Overview

| Attribute | Details |
| :--- | :--- |
| **Project Name** | **OzUF** (Oz Unit Frames) |
| **Target Client** | World of Warcraft 1.12.1 (Client Build 5875) / Turtle WoW / SuperWoW |
| **Runtime Language** | Lua 5.0.2 (Pure Lua UI, Strict 1.12 Dialect) |
| **SavedVariables** | `OzUF_DB` |
| **Primary Philosophy** | **Simplicity First**: Lightweight, minimal resource footprint, modular, non-destructive to default FrameXML where possible, zero-dependency. |
| **Document Version** | 1.0.0 |
| **Status** | Approved for Implementation |

---

## 2. Product Goals & Design Principles

1. **Lightweight & High Performance**:
   - Zero memory leaks: no `CreateFrame` calls in loops or `OnUpdate`.
   - Frame scripts use efficient event-driven updates rather than aggressive polling.
   - Pure Lua UI: 100% created programmatically in Lua, avoiding XML caching bugs and template collisions.
2. **Minimalist Aesthetic & Enhanced Clarity**:
   - Enhances the default Blizzard unit frames or provides a sleek, clean alternative without the bulk and complexity of full UI overhauls.
   - Prominently increases health readability with 2x height health bars.
   - Removes visual clutter (e.g. "zzz" resting icon, redundant percentages on mob health).
3. **High Usability & Flexibility**:
   - Free positioning with a visual unlock grid and coordinate clamp.
   - Granular scaling per frame or frame group.
   - Clean portrait toggle that dynamically compacts frames when portraits are disabled.
   - Dedicated FocusFrame supporting both standard Vanilla (name/target tracking) and SuperWoW (`focus` unit token).

---

## 3. Scope of Features

| # | Feature | Summary |
| :-: | :--- | :--- |
| **1** | **Movable Unit Frames** | Player, Target, Target of Target, Pet, Party (1-4), and Focus frame can be unlocked, dragged, and locked. Positions persist in `OzUF_DB`. |
| **2** | **FocusFrame** | Full-featured focus frame styled consistently with Player/Target frames. Supports `/focus`, `/clearfocus`, and target clicking. Dual-engine compatibility (SuperWoW native `focus` unit token or Vanilla combat/target scanner). |
| **3** | **2x Health Bar Height & 2-Line Text** | Doubles the vertical height of health bars (from default 12px to 24px) to house 2 clean lines of text directly inside the health bar: Line 1 for Unit Name & Level, Line 2 for Unit Health value. |
| **4** | **Mob Health Display (No %)** | Displays mob health as raw/estimated numeric values (e.g. `1,420` or `1.4k / 3.2k`) while strictly suppressing percentage text on hostile/neutral mobs. |
| **5** | **Hide Rest Icon ("zzz")** | Permanently suppresses the animated "zzz" resting icon and glow on the PlayerFrame. |
| **6** | **Frame Scaling** | Allows scaling frames from 50% to 150% with clean anchor adjustment and screen clamping. |
| **7** | **Hide Portraits (All Frames)** | Option to hide 2D portraits across all frames (Player, Target, ToT, Pet, Party 1-4, Focus), with intelligent layout collapsing into compact bar mode. |

---

## 4. Visual UI Wireframes & Layout Mockups

> *In compliance with AGENT.MD Section 8: Mandatory UI Wireframes.*

### 4.1. Default vs. OzUF Player & Target Frame (Standard Mode with Portraits)

```
================================================================================
                          DEFAULT BLIZZARD UNIT FRAMES
================================================================================

  PLAYER FRAME:
  +--------+------------------------------------+
  | (zzz)  | PlayerName                   Lvl 60 |
  | [Port- |+----------------------------------+|
  |  rait] || Health: 3450 / 3450        (12px)|  <-- Thin health bar
  |        |+----------------------------------+|
  |        || Mana:   4120 / 4120        (10px)|
  +--------++----------------------------------++

  TARGET FRAME (MOB):
  +------------------------------------+--------+
  | MobName                      Lvl 62| [Port- |
  |+----------------------------------+|  rait] |
  || Health: 100%                 (12px)||        |  <-- Only shows % by default
  |+----------------------------------+|        |
  || Mana:   2400 / 2400         (10px)||        |
  ++----------------------------------++--------+


================================================================================
             OzUF ENHANCED FRAMES (2x Health, 2-Line Text, No Rest, No %)
================================================================================

  PLAYER FRAME:
  +--------+------------------------------------+
  |        |+==================================+|  <-- Rest icon ("zzz") REMOVED
  | [Port- || PlayerName                 Lvl 60||  <-- LINE 1: Name & Level
  |  rait] || Health: 3,450 / 3,450      (24px)||  <-- LINE 2: Health (No divider)
  |        |+==================================+|
  +--------++----------------------------------++
            | Mana:   4,120 / 4,120       (10px)|
            +------------------------------------+

  TARGET FRAME (MOB):
  +------------------------------------+--------+
  |+==================================+| [Port- |
  || Felhound                   Lvl 62||  rait] |  <-- LINE 1: Mob Name & Level
  || Health: 4,820 / 4,820       (24px)||        |  <-- LINE 2: Mob Health (No %)
  |+==================================+|        |
  +------------------------------------+|        |
  | Mana:   1,540 / 1,540         (10px)|        |
  +------------------------------------++--------+
```

---

### 4.2. Compact Bar Mode (Portraits Hidden on All Frames)

When `hide_portraits = true`, frames seamlessly collapse and retract the circular portrait frame, aligning health and power bars flush against the frame edge:

```
================================================================================
                    COMPACT BAR MODE (PORTRAITS HIDDEN)
================================================================================

  PLAYER FRAME (COMPACT):
  +=============================================+
  | PlayerName                           Lvl 60 |  <-- LINE 1: Name & Level
  | Health: 3,450 / 3,450                 (24px)|  <-- LINE 2: Health (No divider)
  +=============================================+
  | Mana:   4,120 / 4,120                 (10px)|
  +---------------------------------------------+

  TARGET FRAME (COMPACT):
  +=============================================+
  | Archimonde                           Lvl ?? |  <-- LINE 1: Name & Level
  | Health: 1,420,500                     (24px)|  <-- LINE 2: Mob Health (No %)
  +=============================================+
  | Mana:   850,200 / 850,200             (10px)|
  +---------------------------------------------+

  PARTY MEMBER (1 to 4) (COMPACT):
  +====================================+
  | PartyMember1                Lvl 60 |  <-- LINE 1: Name & Level
  | Health: 2,890 / 3,100        (20px)|  <-- LINE 2: Health (No divider)
  +====================================+
  | Mana:   1,800 / 2,400         (8px)|
  +------------------------------------+
```

---

### 4.3. FocusFrame Visual Specification

The FocusFrame provides vital situational awareness for crowd control, boss casts, and secondary targeting.

```
================================================================================
                             OzUF FOCUS FRAME
================================================================================

  FOCUS FRAME (WITH PORTRAIT):
  +------------------------------------+--------+
  |+==================================+| [Port- |
  || FocusTargetName            Lvl 60||  rait] |  <-- LINE 1: Name & Level
  || Health: 5,120 / 5,120       (24px)||        |  <-- LINE 2: Health (No divider)
  |+==================================+|        |
  +------------------------------------+|        |
  | Mana:   2,400 / 2,400         (10px)|        |
  +------------------------------------++--------+
    [Buff 1][Buff 2][Buff 3]   [Debuff 1][Debuff 2]

  FOCUS FRAME (PORTRAIT HIDDEN):
  +=============================================+
  | FocusTargetName                      Lvl 60 |  <-- LINE 1: Name & Level
  | Health: 5,120 / 5,120                 (24px)|  <-- LINE 2: Health (No divider)
  +=============================================+
  | Mana:   2,400 / 2,400                 (10px)|
  +---------------------------------------------+
    [Buff 1][Buff 2][Buff 3]   [Debuff 1][Debuff 2]
```

---

### 4.4. Movable Overlay & Positioning HUD (Unlock Mode)

When unlocked via `/ozuf unlock` or `/ozuf move`:

```
================================================================================
                        UNLOCKED / MOVE MODE OVERLAY
================================================================================

               [ 10% Opacity Alignment Grid across screen ]

    +--[ DRAG HANDLE: PlayerFrame ]-------------+
    | [Drag here to reposition]                 |
    | Scale: 1.00  | Pos: X=250, Y=700          |
    +-------------------------------------------+

                             +--[ DRAG HANDLE: TargetFrame ]-------------+
                             | [Drag here to reposition]                 |
                             | Scale: 1.00  | Pos: X=600, Y=700          |
                             +-------------------------------------------+

    +--[ DRAG: PetFrame ]---+
    | Pos: X=250, Y=620     |
    +-----------------------+

                             +--[ DRAG HANDLE: FocusFrame ]--------------+
                             | [Drag here to reposition]                 |
                             | Scale: 0.90  | Pos: X=600, Y=520          |
                             +-------------------------------------------+

  BOTTOM SCREEN CONTROL BAR:
  +----------------------------------------------------------------------------+
  |  OzUF: Frames Unlocked. Drag to position.      [ Lock Frames ]  [ Reset ]  |
  +----------------------------------------------------------------------------+
```

---

### 4.5. Minimal In-Game Configuration Dialog (`/ozuf`)

```
================================================================================
                         OzUF CONFIGURATION PANEL
================================================================================

  +--[ OzUF Settings ]--------------------------------------------------[X]-+
  |                                                                         |
  |  [X] Lock Frames                                                        |
  |  [ ] Show Alignment Grid in Unlock Mode                                 |
  |                                                                         |
  |  --- Display & Layout ------------------------------------------------  |
  |  [X] Double Health Bar Height (24px, 2-Line: Name+Lvl / Health)         |
  |  [X] Hide Rest Icon ("zzz") on Player Frame                             |
  |  [X] Show Numeric Mob Health Only (Hide %)                              |
  |  [X] Hide Portraits on All Frames (Compact Bar Mode)                    |
  |                                                                         |
  |  --- Frame Scaling ---------------------------------------------------  |
  |  Player Frame Scale:       [--------O-----------]  100%                 |
  |  Target Frame Scale:       [--------O-----------]  100%                 |
  |  Focus Frame Scale:        [------O-------------]   90%                 |
  |  Party Frames Scale:       [--------O-----------]  100%                 |
  |                                                                         |
  |  --- Focus Target Controls -------------------------------------------  |
  |  Keybind / Slash Command: /focus (set current target)                   |
  |                          /clearfocus (dismiss focus)                    |
  |                                                                         |
  |  [ Reset All Positions ]                             [ Close / Save ]   |
  +-------------------------------------------------------------------------+
```

---

## 5. Detailed Functional Specifications

### 5.1. Feature 1: Movable Unit Frames
- **Frames Supported**:
  - `PlayerFrame`
  - `TargetFrame`
  - `TargetofTargetFrame`
  - `PetFrame`
  - `PartyMemberFrame1` through `PartyMemberFrame4`
  - `OzUFFocusFrame`
- **Unlock Mechanics**:
  - Toggled via `/ozuf unlock` or `/ozuf lock`, or Shift+Ctrl drag.
  - When unlocked:
    - Frames are set to `SetMovable(true)`, `EnableMouse(true)`.
    - Translucent colored highlight boxes with anchor titles overlay each frame.
    - An optional alignment grid renders on `WorldFrame`.
  - When dragged and released:
    - Positions are saved relative to `UIParent` using `GetPoint()` or `GetLeft()`, `GetBottom()`.
    - Coordinates are stored in `OzUF_DB.positions[frameName]`.
    - `SetClampedToScreen(true)` is strictly maintained to prevent frames from getting lost off-screen.

### 5.2. Feature 2: FocusFrame
- **Architecture**:
  - Pure Lua frame creation named `OzUFFocusFrame`.
  - Reuses Blizzard TargetFrame textures or clean status bar textures to ensure high aesthetic consistency.
- **Unit Resolution Strategy**:
  - **SuperWoW Detection**: If SuperWoW is active, `UnitExists("focus")` is supported natively by the engine. OzUF sets `this.unit = "focus"` and registers standard unit events (`UNIT_HEALTH`, `UNIT_MANA`, `PLAYER_FOCUS_CHANGED`).
  - **Standard Vanilla / Turtle WoW Fallback**: If SuperWoW native focus is not present, OzUF tracks the focus unit by GUID/name:
    - Scanning `target`, `targettarget`, `party1..4`, `partypet1..4`, `raid1..40`, `mouseover`.
    - Combat log event tracking for health updates of the focused entity.
- **User Actions**:
  - `/focus`: Sets current target as focus.
  - `/clearfocus`: Clears current focus frame.
  - Clicking `OzUFFocusFrame`: Targets the focused unit (`TargetByName` or `TargetUnit("focus")`).
  - Right-clicking `OzUFFocusFrame`: Opens unit dropdown or clears focus.

### 5.3. Feature 3: Twice the Height of Healthbar & Dual-Line Text Structure
- **Dimension Changes**:
  - Default Blizzard HealthBar: Height = 12px.
  - OzUF HealthBar: Height = 24px (Double Height).
- **Dual-Line Typography Structure Inside Healthbar**:
  - By doubling healthbar height to 24px, the bar accommodates two distinct, cleanly stacked lines of information:
    - **Line 1 (Top Half of HealthBar, ~11px vertical slice)**:
      - **Unit Name**: Left-aligned font string (e.g. `PlayerName`, `TargetName`). Truncated cleanly with ellipsis if exceeding available width.
      - **Unit Level**: Right-aligned font string (color-coded by difficulty delta vs. player level, e.g. red, yellow, green, gray, or skull/`??` for world boss).
    - **Line 2 (Bottom Half of HealthBar, ~11px vertical slice)**:
      - **Unit Health Value**: Centered or right-aligned font string.
      - Displays formatted current/max health (`3,450 / 3,450`) for players and friendly units.
      - Displays pure numeric health (`4,820 / 4,820` or raw points) for hostile mobs, strictly suppressing `%`.
  - **Single Unified Bar (No Internal Border or Dash)**:
    - The health bar is a single continuous status bar fill.
    - There is strictly **no internal border, line, or dash** separating Line 1 and Line 2. Both lines render cleanly as floating text overlays directly within the single bar surface.
- **Layout & Object Integration**:
  - External Blizzard name and level text objects (`PlayerName`, `TargetFrameTextureFrameName`, `TargetLevelText`) are hidden or their text cleared to avoid redundant duplicates outside the bar.
  - Text Layering: Both font strings are instantiated on the healthbar's `OVERLAY` strata using `OUTLINE` styling so they remain razor sharp and readable against any class or faction health bar color.
  - Player frame: `PlayerFrameHealthBar:SetHeight(24)`.
  - Target frame: `TargetFrameHealthBar:SetHeight(24)`.
  - Party frames: `PartyMemberFrameXHealthBar:SetHeight(20)` (scaled to cleanly fit 2 lines).
  - Focus frame: Height = 24px with identical dual-line layout.
  - Mana bars: Repositioned directly below the expanded health bar (`TOPLEFT` anchor adjusted by -12px offset).
  - Background texture & artwork: Adjusted to prevent bar clipping. Border and background textures re-anchored to encapsulate the 24px health bar cleanly.

### 5.4. Feature 4: Display Mob Health Without Percentage
- **Formatting Rule**:
  - Displayed on **Line 2** of the 2-line health bar:
    - When target is an NPC / mob:
      - Displays raw health value: e.g. `4,820 / 4,820` or abbreviated `4.8k / 4.8k` (or current `4,820`).
      - **Never display the `%` character** or percentage ratio (e.g. `100%`) for mobs.
    - When target is a friendly player:
      - Shows `Current / Max` (e.g. `3,450 / 3,450`).
- **Data Acquisition**:
  - **Turtle WoW**: `UnitHealth("target")` natively returns accurate mob health.
  - **Vanilla / SuperWoW**: Checks for `MobHealth3`, `MobHealth2`, or internal MobHealth database cache. If unavailable, falls back to displaying clean numeric estimates or raw points without percentage clutter.

### 5.5. Feature 5: Hide Rest Icon ("zzz")
- **Target Elements**:
  - `PlayerRestIcon`
  - `PlayerRestGlow`
- **Suppression Logic**:
  - `PlayerRestIcon:Hide()` and `PlayerRestGlow:Hide()`.
  - Hook `PlayerFrame_UpdateStatus`:
    - Force-hide `PlayerRestIcon` and `PlayerRestGlow`.
    - Alternatively stub `PlayerRestIcon.Show = function() end` and `PlayerRestGlow.Show = function() end` to prevent FrameXML from toggling them visible when entering inns/cities.

### 5.6. Feature 6: Frame Scaling
- **Configuration**:
  - Granular scale values per frame in `OzUF_DB.scales`:
    - `player` (default: 1.0)
    - `target` (default: 1.0)
    - `focus` (default: 0.9)
    - `party` (default: 1.0)
    - `pet` (default: 0.85)
- **Scale Application**:
  - Uses `frame:SetScale(scale)`.
  - Position re-calculation: Scaling in WoW 1.12 alters effective coordinate offsets (`GetEffectiveScale()`). OzUF compensates anchor coordinates during scaling to ensure frames do not jump across the screen when scaled.

### 5.7. Feature 7: Hide Portraits on All Frames
- **Affected Frames**:
  - `PlayerFrame` (`PlayerPortrait`)
  - `TargetFrame` (`TargetPortrait`)
  - `TargetofTargetFrame` (`TargetofTargetPortrait`)
  - `PetFrame` (`PetPortrait`)
  - `PartyMemberFrame1` .. `PartyMemberFrame4` (`PartyMemberFrameXPortrait`)
  - `OzUFFocusFrame` (`OzUFFocusPortrait`)
- **Visual Handling**:
  - When `hide_portraits = true`:
    - Portrait textures are hidden (`portrait:Hide()`).
    - Portrait circular background / border textures are hidden or swapped with clean rectangular border lines.
    - Status bars (Health & Mana) are shifted left and widened to fill the vacated portrait space, resulting in a clean, modern "compact bar" aesthetic.
  - When `hide_portraits = false`:
    - Standard 2D unit portraits and circular frame artwork are restored to their standard positions.

---

## 6. Technical Architecture & Constraints (WoW 1.12 / Lua 5.0)

Per `AGENT.MD`, all implementation code must strictly satisfy the following runtime rules:

| Constraint | Enforcement in OzUF |
| :--- | :--- |
| **No XML UI** | 100% Pure Lua frame instantiation via `CreateFrame`. No `.xml` layout files. |
| **No `#` Operator** | Use `table.getn(tbl)` and `string.len(str)`. |
| **No `//` Operator** | Use `math.floor(a / b)`. |
| **No `string.gmatch`** | Use `string.gfind(str, pattern)`. |
| **No `string.lower` / `upper`**| Multibyte GBK/UTF-8 safety on Turtle WoW / zhCN: Use exact byte comparisons or plain substring matching (`string.find(s, p, 1, true)`). |
| **Script Context** | Script handlers strictly use `this`, `event`, `arg1`..`arg9` (never `self` or modern parameters). |
| **Closure Scoping** | Re-bind loop variables to explicit local variables before declaring closures. |
| **FontString Heights** | Never call `FontString:GetStringHeight()`. Use `fs:GetHeight()` or static metric values (12/14/16/24). |
| **Safe Hooking** | Hook standard Blizzard functions safely via standard secure interception patterns without destructive clobbering. |

---

## 7. Data Architecture & SavedVariables Schema

The addon stores user preferences in `OzUF_DB` (declared in `OzUF.toc`):

```lua
OzUF_DB = {
    locked = true,
    show_grid = true,
    double_health = true,
    hide_rest_icon = true,
    mob_health_numeric_only = true,
    hide_portraits = false,
    scales = {
        player = 1.0,
        target = 1.0,
        focus  = 0.9,
        party  = 1.0,
        pet    = 0.85,
    },
    positions = {
        ["PlayerFrame"] = { point = "TOPLEFT", relative = "UIParent", relPoint = "TOPLEFT", x = 20, y = -20 },
        ["TargetFrame"] = { point = "TOPLEFT", relative = "UIParent", relPoint = "TOPLEFT", x = 250, y = -20 },
        ["OzUFFocusFrame"] = { point = "TOPLEFT", relative = "UIParent", relPoint = "TOPLEFT", x = 250, y = -160 },
        ["PetFrame"] = { point = "TOPLEFT", relative = "UIParent", relPoint = "TOPLEFT", x = 20, y = -80 },
        ["PartyMemberFrame1"] = { point = "TOPLEFT", relative = "UIParent", relPoint = "TOPLEFT", x = 20, y = -160 },
        -- additional party frames...
    }
}
```

---

## 8. Slash Commands & User Interface

| Command | Action |
| :--- | :--- |
| `/ozuf` | Opens the OzUF settings dialog. |
| `/ozuf unlock` / `/ozuf move` | Unlocks all unit frames for mouse dragging, displays drag handles. |
| `/ozuf lock` | Locks all unit frames at their current positions and saves coordinates. |
| `/ozuf reset` | Resets all frame positions and scales to default Blizzard coordinates. |
| `/ozuf scale <frame> <val>` | Sets scale for a specific frame (e.g. `/ozuf scale player 1.1`). |
| `/focus` | Sets current target as the focus unit. |
| `/clearfocus` | Clears and hides the FocusFrame. |

---

## 9. Implementation Plan & Milestones

1. **Phase 1: Project Setup & Core Skeleton**
   - Create `OzUF.toc` and main Lua structure (`OzUF.lua`).
   - Implement `OzUF_DB` initialization, default table merging, and slash command dispatcher.
2. **Phase 2: Frame Modifications (Features 3, 4, 5)**
   - Double health bar height implementation on Player & Target frames.
   - Dual-line text system inside healthbar (Line 1: Name & Level, Line 2: Health value).
   - Mob health numeric display hook (filtering out `%` and showing pure numbers).
   - Rest icon suppression hook on `PlayerFrame_UpdateStatus`.
3. **Phase 3: Movability & Scaling Engine (Features 1, 6)**
   - Draggable unlock frame overlay with coordinate persistence.
   - Screen clamping and scale adjustment algorithms.
4. **Phase 4: FocusFrame (Feature 2)**
   - Pure Lua FocusFrame construction.
   - SuperWoW native `focus` hook + Vanilla combat/name scanner fallback.
   - Health bar, mana bar, and target click handling.
5. **Phase 5: Portrait Toggle Engine & Party Support (Feature 7)**
   - Dynamic portrait hiding across Player, Target, Pet, Focus, and Party 1-4.
   - Frame compaction logic to retract frames into sleek compact bar mode.
6. **Phase 6: In-Game Config Panel & Verification**
   - Pure Lua settings GUI (`/ozuf`).
   - Verification against Lua 5.0 compatibility rules.
