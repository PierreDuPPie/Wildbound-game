# WILDBOUND Changelog

## [0.4.0 3D — Homestead & Friends] — 2026-10-08

- Added buffered jumping, smooth travel, bonded land mounts, low-altitude Vulturon flight, gear requirements and safe landing.
- Added renewable gathering in all three regions, huts, houses, campfires, fences, stables, flight perches, riding saddles and flight harnesses.
- Added physical construction previews, placement validation, furnished homes, rest/healing and persisted construction progression.
- Added a forest-and-gold HUD, material counts, objectives, minimap, contextual controls, construction/crafting and Friends panels; refined terrain/light readability.
- Added real four-player-capacity private ENet sessions, cosmetic keeper avatars, consent-based friendly battles and atomically confirmed session goods/animal trades.
- Fixed nested backpack restoration, reserve reset, region menu wiring, save state consistency, scene/occlusion cleanup, actor spawn and flight encounter behavior, GUI input leaks and text-field shortcut conflicts.
- Fixed authored battle support/debuff moves and Opportunist/Pursuit effects; repaired six invalid instinct resources.
- Added confirmed temporary-file saves, recovery backups, preserved damaged originals, safe airborne positions and protection against silently overwriting unreadable progress.
- Added a bundled-engine double-click launcher and reproducible gameplay, physics, combat, recovery and real two-process ENet/Friends verification. See `docs/HOMESTEAD_AND_FRIENDS.md`.

Private-session inventories are temporary and separate from solo progress. Shared worlds/building, permanent trading and public matchmaking require further backend work. Nothing was published or provisioned.

## [0.2.0-RC1] — 2026-08-20 (Presentation Pass & Stabilization)

### Added
- **Production Starter Art**: Handcrafted stylized battle sprites for Ratelit (mascot), Meerkit, and Pangolet in `assets/sprites/creatures/`.
- **Instinct Audiovisual Spectacles**:
  - **Defiance (Ratelit)**: Overlay darken (`0.7`), creature scale-up (`1.15x`), violent screen shake, 24 gold particles, and custom sound design (`defiance.wav`: low impact -> bass swell -> gravel growl).
  - **Armor (Pangolet)**: 3-beat *CHK-CHK-CHK* scale hardening, slate-blue palette, guard symbol flash, downward defensive shimmer, and metallic sound (`armor.wav`).
  - **Sentry (Meerkit)**: 5px alert upward sprite snap, rapid yellow/white `+2 PRIORITY` flash, yellow sparks, and crystal chime (`sentry.wav`).
- **Dynamic Move Discovery**: `PartyManager.move_lookup()` automatically scans `res://data/moves/` via `DirAccess` and caches the 10 core moves dynamically.
- **Enhanced UI & Environment Presentation**:
  - Backpack UI with distinct per-stat colors (Vitality/Green, Power/Red, Guard/Blue, Agility/Yellow, Focus/Purple).
  - Route 01 tree drop shadows, dirt path edge accents, wood plank detailing on the Ranger Hut, crisp encounter transition flash.
  - Acacia Outpost clinic awnings, rest cabin log textures, fountain ripple animation, lantern glow, and smooth sine/quad easing on healing and rest sequences.
- **Acceptance Checklist**: `tests/ACCEPTANCE_RUNS_v0.2.0.md` detailing the 5 core playtest runs.

### Fixed
- Fixed unhooked `BattleEffects` integration, wiring attack lunges, white hit flashes, and camera shakes into combat resolution.
- Fixed Sentry priority activating only on global turn 1; now tracks per-creature entrance instances across mid-battle swaps and faint replacements.
- Fixed UI input locking during action resolution across all nested submenus (`command_grid`, `skills_grid`, `party_grid`).
- Fixed visual node position drift during animations and ensured opacity/position clean reset on faint revival in `creature_visual.gd`.
- Consolidated duplicate battle scenes to `res://scenes/battle/battle_arena.tscn` and standardized `bootstrap.gd` spawn mapping with dictionary lookups.

## [0.1.0-RC1] — 2026-08-19

### Added
- **Route 01 Environment**: Southern African bushveld / savannah map with runtime `TileMapLayer` grass generation, dirt path, acacia trees, rock obstacles, and the Ranger Supply Hut.
- **Three Core Wildlife Species**:
  - **Ratelit 🦡** (Earth / Defiance): Low HP (<30%) triggers +25% Power and Fear immunity.
  - **Meerkit 🐾** (Solar / Sentry): Turn 1 opening priority +2 and high agility.
  - **Pangolet 🦔** (Stone / Armor): Low HP (<50%) triggers +30% Guard scale hardening.
- **Combat State Machine**: Explicit state transitions (`INTRO`, `PLAYER_TURN`, `RESOLVING`, `ENEMY_TURN`, `VICTORY`, `DEFEAT`, `BONDED`, `ESCAPED`, `ENDED`).
- **6-Slot Command Grid**: Strike, Skills, Guard, Wildbond, Creatures, Run with keyboard shortcuts (`Z, X, C, V, A, B`).
- **Party Switching & Faint Handling**: Voluntary creature swap during player turns and forced replacement modal with Run option upon active creature knockout.
- **Wildkeeper Backpack (`[Q]`)**: Overworld overlay to inspect creature dossier cards, learned skills, stat matrix, active battle lead selector, and field gear inventory.
- **Ranger Onboarding & Demo Ending**: Opening ranger briefing, dynamic objective indicator (`Form Wildbond` → `Return to Ranger`), and food-stealing Ratelit narrative cutscene with mystery beat and title card.
- **Deterministic Persistence**: Save/load system writing to `user://wildbound_01_save.json`.

### Fixed
- Fixed wrong instinct name presentation by decoupling instinct data and passing caller context.
- Fixed initial HP load triggering hit impact animations and screen shake.
- Fixed party switch text clipping by transitioning from horizontal row to 3×2 GridContainers.
- Fixed battle state desync by locking turn inputs permanently on terminal combat states.
- Fixed demo ending cutscene re-triggering upon reloading save near the ranger hut.
- Fixed overworld return coordinates desync after battle exits.
