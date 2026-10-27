# WILDBOUND — Playtester Remediation RC1 Report

**Milestone:** Playtester Remediation RC1  
**Source:** Brother-in-law and Aiden's initial playtesting (Mobile phones & Linux PC/browser)  
**Scope Lock:** Strict stabilization & player-experience pass (zero new creatures, continents, crafting systems, or multiplayer expansions).

---

## 1. Executive Summary & Issue Disposition Register

| ID | Finding | Priority | Root Cause Status | Disposition | Automated Verification |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **WB-101** | Severe mobile slowdown after constructing buildings | **P1** | **CONFIRMED** | **FIXED BUT NEEDS DEVICE VERIFICATION** | `playtester_remediation_rc1_test.tscn`, `homestead_visual_test.gd` |
| **WB-102** | Large empty overlay obscures gameplay | **P1** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `mobile_acceptance.tscn` |
| **WB-103** | Combat effects are too brief or unclear / unexplained blue flash | **P1** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `battle_mechanics_test.tscn` |
| **WB-104** | Missing Linux icons/glyphs in combat & menus | **P1** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `mobile_battle_test.tscn` |
| **WB-105** | PC construction controls feel inconsistent/sluggish | **P2** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `adventure_acceptance.tscn` |
| **WB-106** | Desktop HUD and menus are overly intrusive | **P2** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `atlas_hud_presentation_test.tscn` |
| **WB-107** | Skills and abilities lack useful explanations | **P2** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `mobile_battle_test.tscn` |
| **WB-108** | Creature nickname functionality is missing or inaccessible (Aiden's request) | **P2** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `mobile_menu_test.tscn` |
| **WB-109** | Camp/building menu is difficult to discover | **P2** | **CONFIRMED** | **FIXED AND VERIFIED** | `playtester_remediation_rc1_test.tscn`, `adventure_acceptance.tscn` |

---

## 2. Detailed Root Cause Analysis & Engineering Fixes

### WB-101 (P1) — Severe Mobile Slowdown After Constructing Buildings
- **Root Cause (`CONFIRMED`)**:
  1. **Real-Time `OmniLight3D` Multi-Pass Draw Multiplication on `gl_compatibility`**: `project.godot` uses `renderer/rendering_method.mobile="gl_compatibility"`. In Godot 4's Compatibility renderer, every real-time `OmniLight3D` (`LanternLight` on every shelter/hut/house/stable and `CampfireLight` on every campfire) forces an additional additive rendering pass for every illuminated `MeshInstance3D`. Because each procedural building consists of 55–96 `MeshInstance3D` nodes, placing structures multiplied per-frame draw calls on mobile GPUs.
  2. **Uncached Material, Mesh, and Collision Shape Allocations**: `scripts/world3d/build_visual.gd` allocated 12 new `StandardMaterial3D` instances, 55–96 new `BoxMesh`/`CylinderMesh` resources, and 16–25 separate `StaticBody3D` physics bodies **per building**, preventing batching and fragmenting `PhysicsServer3D` broadphase.
  3. **Per-Frame Physics & Canvas Polling**:
     - `scripts/world3d/exploration_layer.gd` ran 5 physics raycasts + 1 `intersect_shape` query every single `_physics_process` frame during build preview even when the player/cursor had not moved, and allocated a new `BoxShape3D` and `PhysicsShapeQueryParameters3D` every frame.
     - `scripts/world3d/sanctuary_residents.gd` polled `JSON.stringify(shelters)` every `1.0s` and moved `CharacterBody3D` actors with active `CollisionShape3D` nodes every frame, dirtying the 3D physics broadphase continuously.
     - `scripts/ui/frontier_map.gd` allocated a new `StyleBoxFlat` on every `_draw()` call (60 times/sec).
- **Fixes Applied**:
  - [`scripts/world3d/build_visual.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/world3d/build_visual.gd):
    - Added static resource pools (`_cached_palette`, `_mesh_cache`, `_shape_cache`) so all structures across the game share the same 13 `StandardMaterial3D` instances and reuse identical `BoxMesh`, `CylinderMesh`, `BoxShape3D`, and `CylinderShape3D` resources.
    - Consolidated all collision shapes of each building into **1 single `StaticBody3D` (`CollisionBody`)** per structure instead of 16–25 separate `StaticBody3D` nodes.
    - Disabled real-time shadow casting (`SHADOW_CASTING_SETTING_OFF`) on small non-solid decorative trim/rafters while preserving shadows on structural walls and roofs.
    - Disabled real-time `OmniLight3D` nodes when running under `gl_compatibility` / mobile / web while keeping emissive `LanternGlow` and `FlameCore` materials.
  - [`scripts/world3d/exploration_layer.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/world3d/exploration_layer.gd):
    - Preloaded `BUILD_VISUAL` and `RESOURCE_VISUAL`, cached `_placement_box` and `_placement_query`, and added dirty-checking (`_update_preview_if_needed()`) so placement physics queries only run when candidate position, rotation, or player position changes.
  - [`scripts/world3d/sanctuary_residents.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/world3d/sanctuary_residents.gd):
    - Connected `HomesteadManager.changed` for event-driven resident updates, reduced fallback timer frequency from `1.0s` to `4.0s`, replaced `JSON.stringify` with a lightweight key, and disabled `CollisionShape3D` on resident actors during ambient motion.
  - [`scripts/ui/frontier_map.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/frontier_map.gd):
    - Cached `_panel_style: StyleBoxFlat` in `_ready()`.
- **Profiling Benchmark Results (`playtester_remediation_rc1_test.tscn`)**:

| Placed Structures | Total Scene Nodes | `StaticBody3D` Bodies (Before -> After) | Unique `StandardMaterial3D` (Before -> After) | Unique `Mesh` Resources |
| :---: | :---: | :---: | :---: | :---: |
| **0** | 0 | 0 -> **0** | 0 -> **0** | 0 |
| **1** | 59 | 18 -> **1** | 12 -> **10** | 28 |
| **5** | 331 | ~95 -> **5** | ~60 -> **13** | 93 |
| **10** | 645 | ~185 -> **10** | ~120 -> **13** | 105 |

---

### WB-102 (P1) — Large Empty Overlay Obscures Gameplay
- **Root Cause (`CONFIRMED`)**:
  1. In `scripts/ui/frontier_hud.gd`, `header_details.modulate.a` faded to `0.0` after 5 seconds of idle exploration on desktop, leaving `_header` (`1864×92` opaque dark `PanelContainer`) as a large empty dark rectangle across the top of the screen while also hiding the navigation buttons.
  2. `prompt_label` and `toast_label` used `AUTOWRAP_WORD_SMART` with `custom_minimum_size.x = 0`, causing hidden text updates to wrap at `1px` width (~1,700px minimum height) and inflate `toast_panel` and `prompt_panel`. Desktop never reset `toast_panel.size.y`, `prompt_panel.size.y`, or `_objective_panel.size.y` in `_process()`.
  3. In `scripts/ui/mobile_dialogue_layout.gd`, `text_label.reparent(_scroll)` defaulted to `keep_global_transform = true`, shifting `text_label.position` to `(360, 860)` outside the visible scroll area and leaving the mobile dialogue panel completely blank (`mobile_dialogue_landscape.png`).
- **Fixes Applied**:
  - [`scripts/ui/mobile_dialogue_layout.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/mobile_dialogue_layout.gd): Used `text_label.reparent(_scroll, false)` and reset `text_label.position = Vector2.ZERO`.
  - [`scripts/ui/frontier_hud.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/frontier_hud.gd): Kept `header_details.modulate.a = 1.0` so desktop navigation buttons remain visible (only fading `resources_label.modulate.a` when idle), enforced explicit `custom_minimum_size.x` on wrapped labels, refitted `toast_panel.size.y`, `prompt_panel.size.y`, and `_objective_panel.size.y` on both desktop and mobile, and guarded `toast()` / `tick()` so empty strings immediately hide their panel.

---

### WB-103 (P1) — Combat Effects Are Too Brief or Unclear / Unexplained Blue Flash
- **Root Cause (`CONFIRMED`)**:
  1. When Pangolet's `"Armor"` instinct triggered below 50% HP, `scripts/battle/battle_effects.gd` displayed a steel-blue banner (`Color("#4682B4", 0.85)`) with slate-grey text (`Color("#708090")`) that had a relative luminance contrast of **1.01 : 1** (virtually invisible) and relied on tweening `"theme_override_colors/font_color"` from an alpha-0 override set in `_ready()`, producing an unexplained blank blue rectangle flashing across the screen.
  2. Rapid per-hit messages (`"%s used %s!"`, `"%d damage!"`, `"The Aspect hits hard!"`, `"+%d XP"`) each pushed a new line into `recent_log` (capped at 3 lines), immediately pushing the attack and instinct messages off the combat log within `0.35s`.
- **Fixes Applied**:
  - [`scripts/battle/battle_effects.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/battle/battle_effects.gd):
    - Replaced the unreadable grey-on-blue `"armor"` banner with high-contrast bright gold-cream text (`#FFF3B0` with dark outline) on deep slate-navy (`#163A59`, alpha `0.94`) stating `"PANGOLET'S ARMOR ACTIVATED — GUARD +30%!"` and `"Pangolet locks its scales! (Incoming damage reduced by 30%)"`.
    - Added explicit mechanical callouts for all instincts (`Defiance`, `Armor`, `Sentry`, `Grit`, `Pursuit`, `Opportunist`, `Pack Pressure`, `Flight Instinct`) and animated `modulate:a` cleanly.
    - Added `show_floating_text()` to spawn floating combat popups above creature portraits for HP damage (`-14 HP`), healing (`+20 HP`), Guard (`GUARD +55%!`), critical hits (`CRITICAL HIT! (1.5x)`), Aspect effectiveness (`SUPER EFFECTIVE! (1.25x)` / `RESISTED (0.8x)`), stat stage changes, and instinct activations.
  - [`scripts/battle/battle_arena.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/battle/battle_arena.gd):
    - Combined rapid per-hit sub-events (`damage`, `aspect effectiveness`, `attack XP`) onto the active attack line in `recent_log` so full turn history remains legible.

---

### WB-104 (P1) — Missing Linux Icons/Glyphs in Combat & Menus
- **Root Cause (`CONFIRMED`)**:
  - Color emojis (`⚠️`, `🦡`, `🐾`, `🦔`, `🏃`, `⭐`, `✨`, `🎒`, `⚙️`, `🎯`, `📖`, `🧪`, `🌿`, `💧`, `💎`, `🔑`, `📦`, `📡`, `🪪`, `➕`, `🔄`, `🧬`) in `battle_arena.gd`, `backpack_ui.gd`, `frontier_hud.gd`, `route_01_3d.gd`, `acacia_outpost_3d.gd`, and `route_02_3d.gd` are absent from the bundled fallback font and render as missing-glyph tofu boxes (`▯`) on Linux systems without Noto Color Emoji.
- **Fixes Applied**:
  - Replaced all Supplemental Multilingual Plane / color emojis across `battle_arena.gd`, `backpack_ui.gd`, `frontier_hud.gd`, `route_01_3d.gd`, `acacia_outpost_3d.gd`, and `route_02_3d.gd` with universal font-safe text badges and geometric symbols (`! CREATURE FAINTED !`, `[1] Send out ...`, `[B] Flee Battle (Run)`, `★`, `◆`, `+`, `[HEAL]`, `[CURE]`, `[BUFF]`, `[KEY]`, `[ITEM]`).

---

### WB-105 (P2) — PC Construction Controls Feel Inconsistent/Sluggish
- **Root Cause (`CONFIRMED`)**:
  - Desktop construction previously ignored the mouse entirely: the ghost preview was locked `3.4m` in front of the player's facing direction, required walking with `WASD` to aim, only accepted `T` to rotate, and showed `"E Gather / interact"` in the bottom bar while requiring `Enter` to place.
- **Fixes Applied**:
  - [`scripts/world3d/exploration_layer.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/world3d/exploration_layer.gd):
    - Added desktop mouse raycasting onto the ground plane (`_update_mouse_build_cursor()`) within build reach (`2.2m–9.5m`) with automatic fallback to player-front positioning when moving with `WASD` or running headless tests.
    - Supported **Left Mouse Click**, **`E`**, and **`Enter`** to confirm placement.
    - Supported **`R`**, **`T`**, and **Mouse Wheel Up/Down** to rotate (`90°` increments).
    - Supported **Right Mouse Click** and **`Esc`** to cancel build mode.

---

### WB-106 (P2) — Desktop HUD and Menus Are Overly Intrusive
- **Root Cause (`CONFIRMED`)**:
  - Desktop HUD panels (`_header` at `1864×92`, `_objective_panel` at `570×250`, `prompt_panel` at `1140×58`, `toast_panel` at `1080×70`, `controls_panel` at `1864×66` staying up for `30s`) occupied a large portion of the 3D viewport.
- **Fixes Applied**:
  - [`scripts/ui/frontier_hud.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/frontier_hud.gd):
    - Reduced desktop `_header` height to `68px`, `_objective_panel` width to `410px` (auto-fitted height `~96px`), `prompt_panel` and `toast_panel` max width to `680px`, and `controls_panel` height to `48px` with a `12s` auto-fade timer.

---

### WB-107 (P2) — Skills and Abilities Lack Useful Explanations
- **Root Cause (`CONFIRMED`)**:
  - Support moves (`Curl Up`, `Howl`, `Morning Light`) have `power = 0`, so battle skill buttons displayed `"Pwr 0 · Acc 100%"` without explaining their effect (`+25% Guard`, `+25% Power`, `Heal 40% HP`), and several `.tres` move resources had empty `description` strings.
- **Fixes Applied**:
  - [`scripts/data/move_data.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/data/move_data.gd): Added `get_aspect_name()`, `get_category_name()`, `get_effect_summary()`, `get_short_button_subtitle()`, and `get_full_description()`.
  - [`scripts/battle/battle_arena.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/battle/battle_arena.gd) & [`scripts/ui/backpack_ui.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/backpack_ui.gd): Updated battle skill buttons, combat log skill previews, tooltips, and Backpack Party details to display full skill, instinct, and field ability explanations.

---

### WB-108 (P2) — Creature Nickname Functionality (Aiden's Request)
- **Root Cause (`CONFIRMED`)**:
  - `CreatureInstance.nickname` existed in the data model and save serializer, but no UI existed anywhere in the game for a player to set, edit, or reset a creature's nickname.
- **Fixes Applied**:
  - [`scripts/data/creature_instance.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/data/creature_instance.gd): Added `set_nickname()`, `has_custom_nickname()`, and `display_name_with_species()` (`"Nickname (Species)"`, max 18 chars, whitespace-sanitized).
  - [`scripts/ui/backpack_ui.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/backpack_ui.gd): Added `RENAME COMPANION` button in the Party tab and `RENAME` button in the Reserve tab, opening `rename_modal` with `SAVE NAME`, `RESET DEFAULT`, and `CANCEL`, emitting `progress_changed` to autosave immediately.

---

### WB-109 (P2) — Camp/Building Menu Is Difficult to Discover
- **Root Cause (`CONFIRMED`)**:
  - On desktop, `header_details.modulate.a` faded to `0.0` after 5 seconds, making the `C  CAMP` button invisible during normal exploration!
- **Fixes Applied**:
  - [`scripts/ui/frontier_hud.gd`](file:///c:/Users/pierr/OneDrive/wildbound%20game/WILDBOUND_v0.4.0-3D-dev/scripts/ui/frontier_hud.gd):
    - Kept `C  CAMP` permanently visible in the desktop header (`header_details.modulate.a = 1.0`).
    - Added `_update_camp_highlight()` to highlight `C  CAMP` (and `CAMP & BUILD` in the mobile navigation menu) in gold when the Creature Shelter can be built or is the active objective.
    - Added a one-time contextual guidance toast when the player first gathers materials (`"Materials gathered! Press C (or tap MENU → CAMP & BUILD) to open the Camp & Build menu."`).
