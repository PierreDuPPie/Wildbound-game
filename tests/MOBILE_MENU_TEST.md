# Mobile menu regression test

Run these commands from the `WILDBOUND_v0.4.0-3D-dev` project directory. The bundled Godot runtime is used below.

```powershell
$menuTestAppDataOriginal = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Get-Location) '.qa/mobile-menu-appdata'
    & '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . tests/mobile_menu_test.tscn --resolution 844x390 --log-file .qa/mobile_menu_test_headless.log -- --mobile-preview
} finally {
    $env:APPDATA = $menuTestAppDataOriginal
}
```

For screenshots and a rendered check, replace `--headless` with `--rendering-method gl_compatibility`, and use `.qa/mobile_menu_test.log` as the log path. Screenshots appear at `.qa/menu_*.png`.

The test requires `--mobile-preview` so changing touch mode never writes control preferences. It uses an isolated save path, attaches no game save handler, and does not launch Bootstrap. It constructs six party members, a full species roster in the reserve, and six item types in memory.

Checks cover safe bounds and touch target sizes, rotation without losing selections, modal cancellation, scrolling to the sixth swap/item target, real party and inventory changes, and the retained system menu signal contracts. Input dispatch uses `InputEventScreenTouch`, including Save, Load, New Game confirmation/cancellation, Close, and Backpack.

The rendered run includes nine screenshot-write checks. The headless run skips those checks. This verifies engine behavior and phone-sized layouts; physical phone and browser tests remain separate.
