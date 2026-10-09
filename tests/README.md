# Reproducible verification

Run these checks from `WILDBOUND_v0.4.0-3D-dev` using the bundled Godot 4.7.2 engine. Each invocation is a separate process; the game is never pointed at the user's save by these tests. QA files and captures stay under `.qa`, with an isolated APPDATA runtime.

```powershell
$env:APPDATA = Join-Path (Get-Location) '.tools\godot\editor_data'
$engine = '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'

& $engine --headless --path . res://tests/test_runner.tscn
& $engine --headless --path . --script res://tests/homestead_test.gd
& $engine --headless --path . --script res://tests/homestead_visual_test.gd
& $engine --headless --path . --script res://tests/movement_test.gd
& $engine --headless --path . res://tests/battle_mechanics_test.tscn
& $engine --headless --path . res://tests/battle_exit_test.tscn
& $engine --headless --path . res://tests/battle_visual_test.tscn
& $engine --headless --path . res://tests/encounter_pacing_test.tscn
& $engine --headless --path . res://tests/travel_transition_test.tscn
& $engine --headless --path . res://tests/save_recovery_test.tscn
& $engine --headless --path . --script res://tests/network_state_test.gd
& $engine --headless --path . res://tests/adventure_acceptance.tscn
& tests\network_integration.ps1
```

Use `test_runner.tscn`, not the old `--script test_runner.gd` command: the runner is a Node scene and needs initialized autoload managers. A nonzero process exit indicates failure. `network_integration.ps1` verifies both peers' completion markers, exit codes and timeout, and cleans up only its own processes.

## Rendered acceptance

```powershell
& $engine --path . --windowed --resolution 1280x720 --max-fps 60 res://tests/adventure_acceptance.tscn --log-file .qa/adventure_rendered_final.log
```

This uses the actual Vulkan renderer, actual Bootstrap/regions/HUD, physical player, building preview and disk save path. It exercises gathering, blocked and successful construction, equipment crafting, a save/reset/reopen cycle, real input dispatch, jumping, riding, flight and landing, and all three regions. A controlled Gazellor/Vulturon fixture supplies owned companions for the movement test; random battle capture is not claimed. Four real viewport images are written to `.qa/adventure_{route01,camp_menu,outpost,woodland}.png`. The rendered run has four additional screenshot checks compared with headless.

## Mobile input and interfaces

```powershell
& $engine --headless --path . res://tests/mobile_acceptance.tscn --log-file .qa/mobile_acceptance_headless.log -- --mobile-preview
& $engine --headless --path . res://tests/mobile_menu_test.tscn --log-file .qa/mobile_menu_test_headless.log -- --mobile-preview
& $engine --headless --path . res://tests/mobile_battle_test.tscn --log-file .qa/mobile_battle_test_headless.log -- --mobile-preview

& $engine --path . --rendering-method gl_compatibility --windowed --resolution 844x390 --max-fps 60 res://tests/mobile_acceptance.tscn --log-file .qa/mobile_acceptance_rendered.log -- --mobile-preview
& $engine --path . --rendering-method gl_compatibility --windowed --resolution 844x390 --max-fps 60 res://tests/mobile_menu_test.tscn --log-file .qa/mobile_menu_test_final.log -- --mobile-preview
& $engine --path . --rendering-method gl_compatibility --windowed --resolution 844x390 --max-fps 60 res://tests/mobile_battle_test.tscn --log-file .qa/mobile_regression_mobile_battle_final.log -- --mobile-preview
```

The `--mobile-preview` argument prevents these runs from changing the saved interface preference. Keep the isolated APPDATA assignment shown above. Run rendered suites separately, so another window cannot interrupt a held-input test.

Mobile acceptance passes 55 headless / 63 rendered checks; menus pass 44 / 53, and battles pass 34 / 37. The real Bootstrap test blocks portrait input, freezes player physics, clears a held joystick on rotation and resumes play in landscape. It also round-trips gathering and construction through its own JSON save. Independent menu/battle fixtures retain portrait geometry checks; no actual game is attached to the menu fixture. The menu scene verifies real roster swaps and healing/consumption. See [MOBILE_MENU_TEST.md](MOBILE_MENU_TEST.md) for the full menu fixture.

RC1 adds the following checks. Keep the isolated APPDATA setting and run write/reopen in this order:

```powershell
& $engine --headless --path . res://tests/rc1_touch_hud.tscn -- --mobile-preview
& $engine --headless --path . res://tests/rc1_world.tscn -- --mobile-preview
& $engine --headless --path . res://tests/rc1_battle_pause.tscn -- --mobile-preview
& $engine --headless --path . res://tests/rc1_integration.tscn -- --mobile-preview
& $engine --headless --path . res://tests/rc1_integration.tscn -- --mobile-preview --rc1-read
```

Results: touch/HUD/lifecycle 29 headless / 30 rendered; construction/landing 23; battle pause/resume 5; autosave 18 then fresh-process reopen 7; all zero failures. Details and exact final logs are in [the RC1 implementation report](../docs/MOBILE_IMPLEMENTATION_REPORT.md). Real-device checks remain in [MOBILE_ACCEPTANCE_CHECKLIST.md](MOBILE_ACCEPTANCE_CHECKLIST.md).

Rendered verification covers Windows Godot at phone-sized resolutions. It does not prove performance or finger scrolling on a physical phone, or browser export compatibility. See [mobile implementation and limits](../docs/MOBILE_CONTROLS.md).

## Real ENet and Friends controls

The integration script starts two actual Godot processes on loopback. Both instantiate the actual Bootstrap with their own unique `.qa` save, then drive real Friends controls. It checks Host/Join, invitation/consent, typed two-digit trade quantities across live presence packets, stable form identity, `Update My Offer`, animal selection, both confirmations, friendly battle actions and results, returning to lobby, and Leave/disconnect cleanup. It also sends an invalid over-offer RPC and a stale confirmation replay, and proves that both solo save files remain byte-identical.

These are real GUI objects and callbacks in headless Godot, not native mouse automation or proof of two physical devices. No mocked transport or NetworkManager is used. Logs: `tests/network_host_output.log`, `tests/network_client_output.log` and corresponding stderr logs.

## Current results

166 existing regression, 63 homestead, 47 structure visual/physics, 62 movement/input, 34 combat, 19 save recovery, 48 network validation and 54 rendered adventure checks passed locally. The real two-process ENet/Friends test passed. Details and scope are in `docs/HOMESTEAD_AND_FRIENDS.md`.

The gameplay recording follow-up passed 39 headless / 41 rendered encounter checks, 104 headless and rendered region-travel checks, 24 battle-exit checks, and 12 rendered battle-art/layout checks. The existing movement, combat, building, save recovery, rendered adventure and two-process ENet checks were rerun successfully. See `docs/GAMEPLAY_REVIEW_2026-10-08.md` for exact logs and limits. Run the new visual scenes without `--headless` to produce their viewport images; `battle_visual_test` has an additional screenshot assertion when rendered.

Godot in the sandbox can log a root certificate-store error; local gameplay and ENet do not require TLS. The save recovery test deliberately generates a damaged-save warning and an unwritable-path error. Treat script errors or failed assertions separately from these expected diagnostics.
