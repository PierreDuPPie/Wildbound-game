# WILDBOUND Mobile — Android Playtest RC1

Date: 9 October 2026. **Unverified on real Android hardware.** Implementation, Windows engine tests and a signed debug APK are available. This is an untested Android release candidate, not a certified mobile release.

## Delivery and provenance

- Project: `WILDBOUND_v0.4.0-3D-dev`; branch: `feature/mobile-experience-rc1`.
- Preserved baseline: `51e2fe7`. Frozen older release folders were not edited.
- Engine: Godot `4.7.2.stable.official.ed1daf0bf`.
- APK: `builds/WILDBOUND_Mobile_RC1_Debug.apk`.
- SHA-256, byte size and exact source commit: `builds/RC1_BUILD_INFO.json`.
- Package `com.wildbound.playtest`, code 401, version `0.4.0-mobile-rc1`.
- One shared game: desktop/mobile use the same worlds, creatures, battle logic, managers and save schema.
- Debug signing only; no Google Play publication or production key changes.

## Implemented

### HUD and controls

`MobileControls` selects explore, riding, flying, build, dialogue, menu and battle contexts. Gameplay managers remain authoritative. Touch dispatches existing actions/callbacks; construction steering uses the dedicated cursor.

The phone HUD has region/expandable mission top left, minimap/Menu top right, joystick bottom left and contextual actions bottom right. Resources/save notifications are temporary; resources remain visible while building. Menu contains Backpack, Camp & Build, Friends, Save & Settings and Camera View. Long menus scroll.

Analog input preserves partial and diagonal stick strength. Adjustable deadzone is 5–30%. Separate finger ownership supports moving while jumping/rising. Release, focus loss, menus, transitions, rotation and suspension clear held input.

Landscape is requested in the manifest and runtime. The portrait fallback pauses gameplay. Native safe-area bounds are used. Windows layouts were checked at phone-sized dimensions including 844 × 390; physical cutouts, gesture areas and Android density remain unverified.

### Camera, riding and flight

The existing automatic camera follows walking/riding/flight, pulls back with speed/altitude and exposes follow response in Settings. Camera View retains perspective/orthographic selection. Existing per-instance obstruction fading and ground position feedback are preserved.

Mounted movement accelerates/decelerates smoothly. Flight replaces ground actions with Rise, Descend and Land. Altitude/status and a green/red landing ring are visible. Ground raycasts, hazard checks and capsule clearance reject unsafe landing; unsafe terrain cancels automatic descent.

Drag-to-orbit, pinch zoom, sensitivity and inversion are not implemented. Follow response is the available camera preference.

### Battle and creature management

Touch battle retains separate HP/XP, messages, Strike, Skills, Guard, Items, Wildbond, Creatures and Flee. Combat formulas are preserved. Resolution blocks duplicate commands; faint replacement validates state and party membership.

Party uses six compact cards with a separate details page for stats, moves, lead and favorite actions. Reserve remains scrollable with preview, favorites and transfers. Transfers retain location restrictions, prevent removal of the last/last conscious companion and debounce repeated taps. Successful lead/favorite/transfer callbacks autosave through Bootstrap.

Native Back closes an active submenu/detail/menu, dialogue or construction; from exploration it opens Settings. Battles retain explicit on-screen Back/Flee controls; system Back does not quit.

### Building

The placement pad moves a dedicated target while the keeper remains still. Rotate/Place/Cancel replace exploration controls. One compact instruction strip leaves the preview clear.

Validation checks footprint support, level ground, collision, hazards, structures, boundaries and materials. A 0.45-second cooldown prevents repeated placement. Failed placement does not charge. Undo lasts 12 seconds and only succeeds if the post-placement resource/structure/equipment/harvest/milestone state is unchanged. It refunds once and saves; IDs and time are not rolled back.

### Lifecycle and saves

Native pause checkpoints stable exploration, releases touches and pauses the scene tree. Resume clears only the lifecycle pause reason; portrait or an existing unrelated pause remains active. Focus loss releases input without adding a conflicting lifecycle pause.

Battle/evolution/UI delay timers honor scene pause. Mid-action combat is not serialized; termination during battle restores the most recent completed checkpoint. Existing battle/Wildbond save paths remain authoritative.

SaveManager retains `wildbound_v04_save.json`, existing schema and temporary-file/flush/backup/replacement recovery. Preferences use separate `interface.cfg` and `mobile_settings.cfg` files. There is no cloud or cross-device save sync.

### Graphics and network

| Preset | Frame cap | Sun shadows | Decorative grass |
| --- | --- | --- | --- |
| Low | 30 | Off | 40% |
| Medium | 30 | Original enabled state, distance 32 | 70% |
| High | 60 | Original settings | Original count |
| Auto | Platform default | Platform default | Platform default |

Auto selects Medium on native mobile/mobile preview and original desktop settings otherwise. Low/Medium disable MSAA; High uses 2× MSAA. Optional SSAO/glow follow the preset and renderer capability. Environment edits use private copies and preserve original values. Grass reduction does not alter encounters. Mobile uses the Compatibility renderer and ETC2/ASTC texture imports.

These are configured budgets, not measured phone performance. Water, creatures, particles and physics were inspected without speculative rewrites.

Friends is labeled experimental and explains loopback is this device only. Existing ENet is preserved with no public game server. Same-machine two-process coverage does not prove multiplayer between phones; browser online sessions need a compatible transport/service.

## Verification

Counts are completed assertions. Rendered evidence is actual Windows Godot viewports with dispatched engine touch input, not Android hardware. Tests use isolated application data and `.qa` save fixtures.

| Suite | Passed / failed | Evidence in .qa |
| --- | --- | --- |
| Desktop baseline | 166 / 0 | rc1_final_test_runner.log |
| Homestead | 63 / 0 | rc1_homestead_test.log |
| Structure/physics | 47 / 0 | rc1_homestead_visual_test.log |
| Movement | 62 / 0 | rc1_movement_test.log |
| Combat | 34 / 0 | rc1_final_battle_mechanics_test.log |
| Battle exit | 24 / 0 | rc1_final_battle_exit_test.log |
| Travel | 104 / 0 | rc1_travel_transition_test.log |
| Encounters | 39 / 0 | rc1_encounter_pacing_test.log |
| Save recovery | 19 / 0 | rc1_save_recovery_test.log |
| Network state | 48 / 0 | rc1_network_state_test.log |
| Adventure | 50 headless, 54 rendered / 0 | rc1_adventure_acceptance_{headless,rendered}.log |
| Mobile acceptance | 55 headless, 63 rendered / 0 | rc1_mobile_acceptance_{headless,rendered}.log |
| Mobile menus | 44 headless, 53 rendered / 0 | rc1_mobile_menu_test_{headless,rendered}.log |
| Mobile battle | 34 headless, 37 rendered / 0 | rc1_mobile_battle_test_{headless,rendered}.log |
| RC1 HUD/lifecycle | 29 headless, 30 rendered / 0 | rc1_touch_hud_headless.log; rc1_rc1_touch_hud_rendered.log |
| RC1 construction/landing | 23 / 0 | rc1_rc1_world_headless.log |
| Battle pause/resume | 5 / 0 | rc1_rc1_battle_pause_headless.log |
| Autosave/fresh-process reopen | 18 write + 7 reopen / 0 | rc1_integration_{write,reopen}.log |
| Real two-process ENet | Host + client PASS | rc1_final_network.log |

The fresh-process test preserves Outpost location, lead, Reserve identity/favorite, supplies and inventory. Actual resolving combat stays frozen during suspension and resumes once. Network coverage includes trade, battle, disconnect and solo-save integrity over actual loopback ENet.

Early failed logs are retained. Construction fixtures now wait for context changes; desktop adventure explicitly chooses desktop mode and respects placement cooldown. Battle exit waits for the actual initial transition instead of assuming 0.9 seconds. Final logs above supersede early attempts. Deliberate save-damage/unwritable-path diagnostics belong to recovery tests; earlier sandbox certificate warnings are separate from script/assertion errors.

Screenshots in `.qa`: `mobile_landscape_objective.png`, `mobile_building.png`, `menu_party_landscape.png`, `menu_reserve_landscape.png`, `menu_system_landscape.png`, `mobile_battle_landscape.png`, `mobile_battle_faint.png`, `mobile_rotation_required.png`.

## Android pipeline

Isolated installed tools: OpenJDK 17.0.20.1+1; Android command-line tools 22; platform-tools; build-tools 36.1.0; platform android-36. Official download hashes were checked. Matching Godot debug template: `.tools/android-templates/android_debug.apk`.

The prebuilt-template route needs no Gradle/NDK/CMake. The actual manifest supplies min SDK 24, target SDK 36, landscape, ARMv7/ARM64, debuggable=true and backup=false. Internet is the only requested permission. No x86 emulator ABI is packaged.

Rebuild on this checkout:

```powershell
& tools/build_android_rc1.ps1
```

The script imports/exports, checks script errors, verifies apksigner and package/orientation, and writes source/hash evidence. Logs: `.qa/rc1_import_console.log`, `.qa/rc1_android_export_console.log`, `.qa/rc1_apk_signature.txt`, `.qa/rc1_apk_manifest.txt`.

For a fresh machine, initialize the same self-contained Godot editor and install its matching debug template, then:

```powershell
python tools/setup_android_tools.py
$env:JAVA_HOME = (Get-ChildItem .tools/android-rc1/java -Directory -Filter 'jdk-*' | Select-Object -First 1).FullName
& .tools/android-rc1/sdk/cmdline-tools/latest/bin/sdkmanager.bat --sdk_root=.tools/android-rc1/sdk --licenses
& .tools/android-rc1/sdk/cmdline-tools/latest/bin/sdkmanager.bat --sdk_root=.tools/android-rc1/sdk 'platform-tools' 'platforms;android-36' 'build-tools;36.1.0'
& tools/build_android_rc1.ps1
```

Setup retrieves the current official JDK 17 patch; record its actual version for a rebuild. Tools/keys are ignored by Git, and machine PATH/production keys are untouched.

## Install and remaining acceptance

Copy the APK to an Android phone and open it from Files. Allow that Files/browser app to install this APK when prompted. Alternatively use `adb install -r builds/WILDBOUND_Mobile_RC1_Debug.apk` with an explicitly authorized USB-debugging phone. An update install preserves app data; uninstalling clears local progress.

No Android phone was connected. Installation, finger scrolling, audio interruptions, native Back delivery, cutout/gesture areas, lock/resume, low-memory termination, sustained FPS, memory, heat and battery remain unverified. Follow [the phone acceptance checklist](../tests/MOBILE_ACCEPTANCE_CHECKLIST.md), including a 30-minute touch-only session and 20-minute performance sample.

The earlier [public browser preview](https://wildbound-play.pierre-dupie2007.chatgpt.site) is a separate pre-RC1 artifact. Sites deployment/public access completed earlier; hosted gameplay verification was interrupted by automatic approval-review usage limits. It has not been refreshed with Android RC1. Prior local browser evidence does not certify the hosted RC1 build.
