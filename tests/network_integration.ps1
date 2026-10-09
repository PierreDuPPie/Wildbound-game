param(
    [string]$Godot = (Join-Path $PSScriptRoot '..\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'),
    [int]$Port = 27849
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$env:APPDATA = Join-Path $projectPath '.tools\godot\editor_data'
$hostLog = Join-Path $PSScriptRoot 'network_host_output.log'
$clientLog = Join-Path $PSScriptRoot 'network_client_output.log'
$hostErr = Join-Path $PSScriptRoot 'network_host_error.log'
$clientErr = Join-Path $PSScriptRoot 'network_client_error.log'
$hostProc = $null
$clientProc = $null
try {
    $hostProc = Start-Process -FilePath $enginePath -ArgumentList @('--headless', '--path', ('"' + $projectPath + '"'), '--script', 'res://tests/network_peer_test.gd', '--', 'host', $Port) -WindowStyle Hidden -PassThru -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr
    Start-Sleep -Milliseconds 800
    $clientProc = Start-Process -FilePath $enginePath -ArgumentList @('--headless', '--path', ('"' + $projectPath + '"'), '--script', 'res://tests/network_peer_test.gd', '--', 'client', $Port) -WindowStyle Hidden -PassThru -RedirectStandardOutput $clientLog -RedirectStandardError $clientErr
    $finished = $hostProc.WaitForExit(35000)
    $clientFinished = $clientProc.WaitForExit(5000)
    Get-Content -LiteralPath $hostLog
    Get-Content -LiteralPath $clientLog
    Get-Content -LiteralPath $hostErr
    Get-Content -LiteralPath $clientErr
    if (-not $finished -or -not $clientFinished -or $hostProc.ExitCode -ne 0 -or $clientProc.ExitCode -ne 0) {
        throw 'Real ENet integration did not pass. See network_*_output/error.log.'
    }
    if (-not (Select-String -LiteralPath $hostLog -SimpleMatch 'NETWORK ENET HOST: PASS') -or -not (Select-String -LiteralPath $clientLog -SimpleMatch 'NETWORK ENET CLIENT: PASS')) {
        throw 'Processes exited without both required completion markers.'
    }
    Write-Output 'NETWORK REAL TWO-PROCESS INTEGRATION: PASS'
} finally {
    foreach ($process in @($hostProc, $clientProc)) {
        if ($null -ne $process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
