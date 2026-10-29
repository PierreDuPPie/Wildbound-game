param(
    [switch]$Rendered,
    [string[]]$Only,
    [int]$TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$auditRoot = Join-Path $projectRoot '.qa/audit-2026-10-27'
$originalAppData = $env:APPDATA
New-Item -ItemType Directory -Force $auditRoot | Out-Null
$env:APPDATA = Join-Path $auditRoot 'appdata'
$results = [System.Collections.Generic.List[object]]::new()
$scenes = @('test_runner', 'homestead_test', 'homestead_visual_test', 'movement_test',
    'battle_mechanics_test', 'battle_exit_test', 'battle_visual_test', 'encounter_pacing_test',
    'travel_transition_test', 'save_recovery_test', 'network_state_test', 'adventure_acceptance',
    'mobile_acceptance', 'mobile_menu_test', 'mobile_battle_test', 'rc1_touch_hud', 'rc1_world',
    'rc1_battle_pause', 'rc1_integration', 'rc1_reopen', 'first_expedition_test',
    'exploration_abilities_test', 'sanctuary_test', 'wild_atlas_test', 'atlas_swipe_test',
    'atlas_hud_presentation_test', 'touch_customization_and_task_popup_test',
    'playtester_remediation_rc1_test', 'audit_regression_test', 'creature_tier_expansion_test', 'portrait_play_test')
if ($Rendered -and -not $Only) {
    $Only = @('adventure_acceptance', 'mobile_acceptance', 'mobile_menu_test', 'mobile_battle_test',
        'first_expedition_test', 'playtester_remediation_rc1_test')
}
if ($Only) { $scenes = @($scenes | Where-Object { $Only -contains $_ }) }
Push-Location $projectRoot
$fingerprintBefore = (& node tools/source_fingerprint.mjs).Trim()
try {
    foreach ($suite in $scenes) {
        $fixture = if ($suite -eq 'rc1_reopen') { 'rc1_integration' } else { $suite }
        $label = $suite + $(if ($Rendered) { '_rendered' } else { '_headless' })
        $stdout = Join-Path $auditRoot ($label + '.out.log')
        $stderr = Join-Path $auditRoot ($label + '.err.log')
        $engineLog = Join-Path $auditRoot ($label + '.engine.log')
        $arguments = @('--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $engineLog + '"'))
        if ($Rendered) {
            $arguments += @('--rendering-method', 'gl_compatibility', '--windowed', '--resolution',
                $(if ($suite -eq 'adventure_acceptance') { '1280x720' } else { '844x390' }), '--max-fps', '60')
        } else { $arguments += '--headless' }
        if (Test-Path -LiteralPath "tests/$fixture.tscn") { $arguments += "res://tests/$fixture.tscn" }
        else { $arguments += @('--script', "res://tests/$fixture.gd") }
        $userArgs = @()
        if ($suite -match '^(mobile_|rc1_|touch_customization)') { $userArgs += '--mobile-preview' }
        if ($suite -eq 'rc1_reopen') { $userArgs += '--rc1-read' }
        if ($userArgs.Count) { $arguments += @('--') + $userArgs }
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        while (-not $process.HasExited -and $timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds 100
        }
        $timedOut = -not $process.HasExited
        if ($timedOut) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
        $process.Refresh()
        $output = (Get-Content -Raw -LiteralPath $stdout) + "`n" + (Get-Content -Raw -LiteralPath $stderr)
        $errors = @($output -split "`r?`n" | Where-Object {
            $_ -match 'SCRIPT ERROR:|Parse Error:|Compile Error:|\[FAIL\]|^FAIL:|^ERROR:' -and
            $_ -notmatch 'Error obtaining system certs|Cannot open save file:.*missing_directory'
        })
        # Recovery deliberately attempts one unwritable save and verifies failure handling.
        if ($suite -eq 'save_recovery_test') { $errors = @($errors | Where-Object { $_ -notmatch 'Cannot open save file:' }) }
        $summaries = @($output -split "`r?`n" | Where-Object { $_ -match 'SUMMARY:|SUITE:|TESTS:|TEST:|ACCEPTANCE:|passed.*failed|passed.*failures|PASS.*FAIL|TEST PASSED' })
        $ok = -not $timedOut -and $process.ExitCode -eq 0 -and $errors.Count -eq 0
        $result = [ordered]@{ suite=$suite; rendered=[bool]$Rendered; passed=$ok; exit_code=$process.ExitCode;
            timed_out=$timedOut; seconds=[Math]::Round($timer.Elapsed.TotalSeconds,2); errors=$errors; summary=$summaries }
        $results.Add($result)
        $verdict = if ($ok) { 'PASS' } else { 'FAIL' }
        Write-Output ($verdict + " $label ($($result.seconds)s) " + ($summaries -join ' | '))
        if ($errors.Count) { $errors | ForEach-Object { Write-Output "  $_" } }
        $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $auditRoot $(if ($Rendered) { 'rendered-results.json' } else { 'headless-results.json' }))
    }
} finally {
    $env:APPDATA = $originalAppData
    Pop-Location
}
$failed = @($results | Where-Object { -not $_.passed })
$fingerprintAfter = (& node (Join-Path $projectRoot 'tools/source_fingerprint.mjs')).Trim()
$stable = $fingerprintBefore -eq $fingerprintAfter
@{before=$fingerprintBefore; after=$fingerprintAfter; stable=$stable} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot $(if ($Rendered) { 'rendered-source.json' } else { 'headless-source.json' }))
Write-Output "AUDIT: $($results.Count - $failed.Count)/$($results.Count) suites passed"
if (-not $stable) { Write-Output 'SOURCE CHANGED DURING AUDIT: repeat checks against a stable checkpoint.' }
if ($failed.Count -or -not $stable) { exit 1 }
