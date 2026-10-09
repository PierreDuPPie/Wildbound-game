# Homestead & Friends implementation

The game now has a second progression loop alongside creature bonding: gather → establish a hut → build companion facilities → craft travel gear → explore faster → expand a home. These are working gameplay systems in the existing project, rather than separate demonstration scenes.

## Components

| Component | Responsibility |
| --- | --- |
| `HomesteadManager` | Canonical resources, renewable site timers, recipes, construction identities, equipment and objectives; transactional load validation. |
| `exploration_layer.gd` | Actual world resource sites, proximity actions, physics-based build previews, collision checks, saved construction, rest, avatars and integration with the three regions. |
| `player_3d.gd` / `camera_rig.gd` | Smooth movement, buffered jumping, land mounts, bounded flight, safe landing and ownership checks; camera follow and per-object occlusion. |
| `build_visual.gd` / `resource_visual.gd` | Procedural meshes, furnished structures, physical doors and walls, travel facilities, renewable resource visuals and reusable preview materials. |
| `frontier_hud.gd` / `frontier_map.gd` | Construction/crafting, objectives, material counts, minimap, contextual controls, save feedback and direct friend session controls. |
| `SaveManager` / `Bootstrap` | Compatible solo snapshot, confirmed temporary-file replacement, recovery copies, damage-safe loading and coherent region/menu state. |
| `NetworkManager` / `session_state.gd` | Real ENet connection and cosmetic presence; host-owned session trading and friendly combat. |

The existing backpack, sanctuary, party and solo battle system remain in use. Nested inventory restoration, reserve reset, menu wiring, actor initial placement, flight encounter distance, scene cleanup and camera material cleanup were repaired where integration exposed existing defects. Authored support moves and Opportunist/Pursuit battle effects now resolve.

## Verified locally, 8 October 2026

Godot 4.7.2 on Windows. Final suites cover:

| Suite | Evidence |
| --- | --- |
| Existing regression | 166 checks; species/moves, party, inventory, instincts and serialization. `.qa/regression_battle_fix.log` |
| Homestead | 63 checks; spending, regrowth, prerequisites, rejected placement and real JSON round-trip. `.qa/homestead_test-final.log` |
| Structure visuals and physics | 47 checks; physical doorway/walls, nonblocking harvest sites, preview material reuse and actor movement/encounter guards. `.qa/homestead_visual_test-final.log` |
| Movement and input | 62 checks; actual jump/flight physics, safety limits, ownership, actual GUI text input, input isolation and occlusion cleanup. `.tools/godot/movement_test.log` |
| Combat resolution | 34 checks; actual asynchronous attack/support resolution, damage, healing, debuffs, turn order, critical strikes and one-time survival. `.qa/battle_mechanics.log` |
| Save recovery | 19 checks; confirmed writes, disk backup fallback including invalid construction, preserved damaged originals, blocked writes and unwritable-path failure. `.qa/save_recovery_final.log` |
| Network validation | 48 checks; consent, ownership, atomic trade, offer revisions, battle secrecy, expiry, limits and replay rejection. `.qa/network_state_test-final.log` |
| Rendered adventure acceptance | 54 checks, running the actual Bootstrap/regions/HUD/physics; gather, preview, build, craft, serialize, reset/reopen, jump, ride, fly, menus and four viewport captures. `.qa/adventure_rendered_final.log` |
| Two-process network | Real ENet host/client over loopback and actual Friends controls; host/join, invitations, typed trade quantities stable across presence packets, offer update/confirmation, animal transfer, battle actions/results, hostile over-offer and replay rejection, leaving/disconnect cleanup, and byte-identical solo saves. `tests/network_host_output.log` and `tests/network_client_output.log` |

The travel acceptance test adds controlled owned Gazellor/Vulturon fixtures to isolate movement from random capture. It does not claim that a randomized capture workflow was tested. Screenshots capture the actual rendered world and UI; they are not image-generation mockups. Save tests select isolated `.qa` paths before Bootstrap performs its first write. After the final save-validator change, the existing regression passed again (166/166, `.qa/regression_final.log`) and integrated headless adventure passed (50/50, `.qa/adventure_headless_final.log`).

The actual Windows game window also loaded the existing saved camp successfully. Native keyboard C/Escape opened and closed Construction, and M opened Friends; these were checked through the computer-use surface. That additional UI check did not build, spend materials, reset progress or start an external connection. `.qa/native_final_game.log` records a clean Vulkan startup/exit.

Sandboxed Godot runs emit a root certificate-store error unrelated to local gameplay or ENet. The save test deliberately produces an unwritable-path error and a damaged-save warning to verify failure handling. Those expected diagnostics are distinct from script errors and failed assertions.

## Current boundaries

The gameplay recording follow-up added deliberate grass searches, encounter recovery, travel continuity across borders, faint-modal escape and battle-art/layout corrections. Current behavior, logs and rendered evidence are recorded in [GAMEPLAY_REVIEW_2026-10-08.md](GAMEPLAY_REVIEW_2026-10-08.md).

Construction is recipe-based with six physical structures and two equipment recipes. It does not offer unrestricted terrain editing, arbitrary block construction or demolition. Flying is low-altitude travel inside the existing reserve boundaries. Companion mounts use the existing species and procedurally rendered models.

Friend sessions are temporary sandboxes. Their goods, animals and equal-stat friendly battle system are separate from the solo inventory, caught animals and tactical BattleManager. The host is trusted. Each player retains their own local wildlife and structures; shared simulation and shared building are not synchronized. Four-player capacity is implemented; actual integration was tested with two processes.

Public matchmaking, relays, authenticated identity and permanent online goods/animal trading require a hosted authoritative backend. No public deployment, account provisioning, paid infrastructure, router or firewall changes were performed. LAN and external internet reachability remain unverified. The next multiplayer release should establish server identities and transactional inventory ownership before connecting permanent solo collections to trading.

Poison-over-time, battle stamina expenditure and expanded move-specific effects remain future combat work. This release resolves the currently authored support/debuff hooks and named instinct fixes, rather than claiming every possible combat mechanic is complete.
