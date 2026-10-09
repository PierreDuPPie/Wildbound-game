# WILDBOUND 0.1 RC1 — Scope & Source of Truth

## 1. Species Data & Signature Mechanics

### Ratelit 🦡
* **Aspect**: Earth
* **Instinct**: **Defiance**
* **Trigger**: Vitality strictly below 30% of max (`< 0.30`).
* **Effect**: **+25% Power boost** (`power_modifier_percent = 0.25`) and **Immunity to Fear** (`grants_fear_immune = true`). Does NOT prevent knockout.
* **Encounter Weight**: 15% (Route 01)
* **Base Bond Difficulty**: 68 (Challenging)

### Meerkit 🐾
* **Aspect**: Solar
* **Instinct**: **Sentry**
* **Trigger**: Turn 1 opening of battle (`once_per_battle = true`, `hook_id = &"sentry_opening_priority"`).
* **Effect**: **+2 Priority bonus on Turn 1** and superior base agility (55) to seize initiative.
* **Encounter Weight**: 50% (Route 01)
* **Base Bond Difficulty**: 35 (Accessible)

### Pangolet 🦔 (Starter)
* **Aspect**: Stone
* **Instinct**: **Armor**
* **Trigger**: Vitality strictly below 50% of max (`< 0.50`).
* **Effect**: **+30% Guard boost** (`guard_modifier_percent = 0.30`) to mitigate incoming physical impact.
* **Encounter Weight**: 35% (Route 01)
* **Base Bond Difficulty**: 50 (Moderate)

---

## 2. Core Systems & Technical Truths

* **Battle Commands**: 6 commands in a structured 3×2 GridContainer:
  1. `[Z] STRIKE` (Primary move)
  2. `[X] SKILLS` (Submenu of learned moves)
  3. `[C] GUARD` (Damage mitigation)
  4. `[V] WILDBOND` (Capture attempt with resonance pulses)
  5. `[A] CREATURES` (Party switch & replacement menu)
  6. `[B] RUN` (Flee combat)
* **Actual Save Filename**: `user://wildbound_01_save.json`
* **Demo Ending Trigger**: Form a Wildbond with any wild creature, then **walk back to the Ranger Supply Hut** on Route 01 (within 95px).
* **Maximum Party Size**: **6 creatures** (`MAX_PARTY_SIZE = 6` in `party_manager.gd`).
* **Actual Controls**:
  * **Overworld**: `WASD` or `Arrow Keys` to move; `Q` (or HUD button) to toggle Backpack; `1–6` to inspect party slots; `ESC` to close.
  * **Battle**: `Z, X, C, V, A, B` for commands; `1–6` for creature selection; `B` or `ESC` to go Back.
* **Visual Status**: Procedural vector canvas art drawn via GDScript `_draw()` in `creature_portrait.gd` at 3.5× scale.
