# v0.6 platform baseline — 11 October 2026

## Scope and status

PC baseline and Windows-rendered touch simulation exercised the shared Godot game. No source changes were made by this QA pass. Existing and parallel development changes were preserved. Tests were executed while Chapter 1 work was underway; these results are a baseline, not certification of the final integrated v0.6 tree.

Godot: bundled `4.7.2.stable.official.ed1daf0bf`. Rendered backend: Vulkan 1.4.325, Intel Graphics. Saves use the existing tests' dedicated `.qa` fixtures; APPDATA was redirected to `.qa/v06-baseline-appdata` or `.qa/v06-baseline-rendered-appdata` for separate control/quality preferences and user-data isolation. No real player save was opened by the test Bootstrap instances.

## Results

| Existing test | Headless result | Windows rendered result |
| --- | --- | --- |
| Regression runner | 168 passed, 0 failed | Not rerun |
| Wild Atlas | 600 entries / 6 regions validated | Not rerun |
| Save recovery | 19 passed, 0 failed | Not rerun |
| Adventure acceptance (desktop) | 50 passed, 0 failed | Not rerun |
| Mobile acceptance | 55 passed, 0 failed | 63 passed, 0 failed |
| Mobile menus | 44 passed, 0 failed | 53 passed, 0 failed |
| Mobile battle | 34 passed, 0 failed | 37 assertions passed; startup runtime error, see below |
| RC1 touch HUD / lifecycle | 29 passed, 0 failed | 30 assertions passed; startup/runtime errors, see below |
| RC1 world / placement / landing | 23 passed, 0 failed | Not rerun |
| RC1 battle pause / resume | 5 passed, 0 failed | Not rerun |
| RC1 autosave write | 18 passed, 0 failed | Not rerun |
| RC1 separate-process reopen | 7 passed, 0 failed | Not rerun |

The gameplay paths cover movement/multitouch jump, riding/flight controls, resource gathering, construction and unsafe landing rejection, Backpack/Reserve callbacks, battle/Wildbond UI, suspension, portrait blocking, and real disk persistence with a separate-process reopen. This does not establish that a new player can complete the new chapter unaided or within 30–45 minutes.

Evidence: `.qa/v06_baseline_<test>_console.log` and `.qa/v06_rendered_<test>_console.log`; fresh process readback is `.qa/v06_baseline_reopen_console.log`. Initial menu/battle invocations correctly refused to run without `-- --mobile-preview`; corrected invocations are the recorded results. Save recovery deliberately produces a Cannot open save file diagnostic to prove failure handling.

### Concurrent-development runtime finding

Rendered battle and RC1 HUD logs show `JSON.parse_string` failing and a Nil-to-Dictionary assignment in `progression_manager.gd:17`, then repeated `get_stage` errors. At inspection, `res://data/story/chapter_01.json` was not yet present while the new manager already referenced it. Reported to the story owner; no overlapping source fix attempted. Passing assertions and exit code alone do not establish a clean runtime. These tests must be rerun after chapter data and story integration settle, scanning for `SCRIPT ERROR`, `Parse Error`, and unexpected `ERROR` in addition to assertion totals.

The rendered mobile landscape capture was visually inspected: compact objective/material panel, Menu/minimap, joystick and Interact/Jump/Sprint fit the 844×390 image. Phone hardware, actual viewing comfort, frame pacing and cutouts remain untested.

## Shared PC / Android architecture

`project.godot` uses one bootstrap and the same PartyManager, SaveManager, InventoryManager, ProgressionManager and HomesteadManager autoloads. Android exports all game resources, excluding tests/docs/tools; shared creature/story/world resources therefore come from the same tree. Touch controls dispatch shared actions. Core manager inspection found no separate Android save/progression/party implementation; battle mobile branches concern presentation. Native Android behavior still requires a device run.

## Android readiness and remaining acceptance

`adb devices -l` returned an empty device list. The local SDK, platform tools, JDK 17, Godot Android debug template, build-tools 36.1.0 and `tools/build_android_rc1.ps1` exist. No Android export was performed by this QA pass.

Current build tooling still exports package `com.wildbound.playtest`, version `0.4.0-mobile-rc1`, code 401, preset `Android RC1`, to `builds/WILDBOUND_Mobile_RC1_Debug.apk`; provenance is also hard-coded to RC1. Update the coordinated v0.6 version/code/name/output/provenance before making a v0.6 candidate. Preserve the package ID to keep Android upgrade/save continuity; use a greater version code.

Then import and export with the existing script or a coordinated v0.6 equivalent, verify APK signature and manifest, record SHA-256 and dirty source provenance, and install on a connected authorized device. Complete `tests/MOBILE_ACCEPTANCE_CHECKLIST.md` plus a fresh Chapter 1 playthrough and force-close/reopen. Record device/Android version, sustained FPS/frame spikes, heat/battery, native Back, interruptions, gesture/cutout fit, persistence and a complete touch-only chapter. Five unfamiliar-player sessions and observed completion timing remain human playtesting work. Do not label Android stable before physical-phone evidence exists.

## Reproduction

Set APPDATA to a dedicated `.qa` directory. Run the bundled console engine with `--headless --path . res://tests/<test>.tscn --log-file .qa/<run>.log -- --mobile-preview`. Omit `--headless` for rendering. Run `rc1_integration.tscn` once to write, then in a new engine process add `--rc1-read` to the user arguments to reopen. Existing save tests mutate only named `.qa` fixture files.
