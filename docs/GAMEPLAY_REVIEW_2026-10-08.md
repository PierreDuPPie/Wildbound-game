# Gameplay recording review — 8 October 2026

The supplied `20261008-1747-43.7320004.mp4` is 5 minutes 23 seconds, 1916×1126 at 30 FPS. Review used visual frames across the recording plus two-second samples of the opening; audio was not reviewed. The source recording was read without modification. Review frames and metadata are under `.qa/gameplay-review-20261008/`.

## Findings and changes

| Evidence | Finding | Implemented change |
| --- | --- | --- |
| Opening frames: Lionet battle at 0:08, overworld at 0:10, battle again at 0:12, overworld at 0:14, battle again at 0:18 | Flee returned correctly, but immediate repeat encounters made exploration feel stuck. Both hidden grass rolls and visible wildlife could start battles. | Walking in grass no longer rolls hidden encounters in Homestead exploration. E deliberately searches grass after gathering, resting and nearby NPC interaction priorities. Visible animals still encounter keepers on the ground. Region entry and battle return give eight seconds of playable recovery time; menus and construction do not consume it. Building, menus and flight pause ground encounters before an actor becomes permanently ENCOUNTERED. |
| Flight shown around 2:45–2:55; foot travel after a region change around 3:04. Another crossing returns to foot travel around 4:18. | Region loaders recreated the keeper without its travel mode. | All four ordinary region borders carry the same owned, conscious companion, equipment, heading and relative flight height. Destination physics, hazards and capsule clearance are rechecked before restoration. Missing prerequisites fall back to foot travel. An Outpost arrival was moved away from the gate scout's collider. Saves and battle returns use the destination's safe ground position. Load/New Game/battle return start on foot. |
| Vulturon battle around 1:14 | Its battle sprite was a black placeholder. | Added an illustrated vector bird with wings, feather details, beak and feet. Existing facing, caching and battle animation still apply. Shared Sentry text now fits any species. |
| Battle UI and field dialogue | The XP strip expanded into the HP text; the frontier footer and prompts overlapped dialogue. Welcome text repeated whenever a world was recreated. | Corrected XP ProgressBar layout. Dialogue hides the overlapping footer, toast and gather prompt. Welcome tutorial appears once per application session. |
| Adjacent reproduction while testing the battle path; not established from the video | Flee on the forced replacement modal hid that modal, then attempted an action rejected by the manager's RESOLVING lock. | An explicit pending faint replacement can now escape through its Flee button, B or Escape. Rejected escape keeps the modal. Ordinary attacks/items remain locked during resolution, and a defeat with no replacement cannot be overridden. |

## Verification

These are actual Godot scenes, physics, GUI callbacks, input dispatch, disk writes and Vulkan captures. QA selected project-local save fixtures before creating Bootstrap and used isolated APPDATA. The user's gameplay save was not opened or changed by these runs.

| Check | Result | Evidence |
| --- | --- | --- |
| Encounter pacing and deliberate search | 39 headless / 41 rendered passed | `.qa/encounter_pacing.log`, `.qa/encounter_pacing_rendered.log`; both actual routes, real grass volumes, E into a battle and Flee back, construction/menu/flight guards and dialogue layout |
| Region travel | 104 passed in headless and rendered runs | `.qa/travel-transition-headless.log`, `.qa/travel-transition-rendered.log`; all borders, repeated flight/riding crossings, prerequisite loss during fade, invalid arrival, ground save/load, battle return and New Game |
| Battle exit and fainting | 24 passed | `.qa/battle_exit_fixed.log`; actual Bootstrap normal flee plus button/B/Escape during forced replacement, defeat and action-lock cases |
| Battle artwork and layout | 12 rendered passed | `.qa/vulturon_battle_render.log`; illustration, mirroring, animation, generic Sentry text, XP strip and HP separation |
| Existing regression / combat / movement | 166 / 34 / 62 passed | `.qa/regression_after_battle_exit.log`, `.qa/battle_mechanics_after_exit.log`, `.tools/godot/movement_test.log` |
| Homestead / structure physics / save recovery | 63 / 47 / 19 passed | `.qa/video_review_homestead.log`, `.qa/video_review_visuals.log`, `.qa/video_review_save_recovery.log` |
| Full rendered adventure | 54 passed | `.qa/video_review_adventure.log`; gather, build, craft, save/reopen, jump, mount, fly, menus and three regions |
| Two-process friend session | Passed | `tests/network_host_output.log`, `tests/network_client_output.log`; real loopback ENet, goods/animal exchange, battle, replay rejection, leaving and unchanged solo save bytes |

Normal fleeing through Bootstrap closed in about 1.1 seconds in both immediate-entry and settled-entry tests. The recording's repeated encounters were not reported as a stalled exit after the denser review resolved them.

## Rendered evidence

The screenshots below come from the running game with controlled QA companions/materials, not the user's inventory or generated mockups.

Flight survives the Outpost → Riverine Woodland border:

![Flying in Riverine Woodland after crossing regions](<C:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.4.0-3D-dev/.qa/travel_after_route02.png>)

Vulturon's battle artwork and the corrected XP strip:

![Actual Vulturon battle](<C:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.4.0-3D-dev/.qa/vulturon_battle_preview.png>)

Dialogue stays clear of the exploration controls:

![Actual field dialogue](<C:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.4.0-3D-dev/.qa/gameplay_fix_dialogue_route_02_3d.png>)

## Play and scope

Close the currently running game and reopen the parent folder's **Play Wildbound.cmd** to load these scripts. Your existing save remains compatible. Try flying through both Outpost gates, gathering near wildlife, and E in tall grass when you want another battle.

The recording confirms usable gathering, construction and flight. It does not establish multiplayer connectivity. Friend sessions remain temporary direct-host sessions, and external internet reachability, public matchmaking, permanent online trading and shared construction remain outside the verified release. The world still uses prototype procedural scenery and mixed creature-art styles; these fixes do not claim a complete visual overhaul.
