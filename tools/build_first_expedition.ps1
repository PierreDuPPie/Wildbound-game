param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$originalAppData = $env:APPDATA
$originalJava = $env:JAVA_HOME
Push-Location $projectRoot

function Assert-EngineLog([string]$LogPath) {
    if (Select-String -LiteralPath $LogPath -Pattern 'SCRIPT ERROR:|Parse Error:|Compile Error:|^ERROR:') {
        throw "Godot reported errors; inspect $LogPath"
    }
}

function Get-SourceManifest {
    $excluded = @('.git', '.godot', '.tools', '.qa', 'builds')
    $directories = [System.Collections.Generic.Stack[string]]::new()
    $directories.Push($projectRoot)
    $entries = [System.Collections.Generic.List[object]]::new()
    while ($directories.Count -gt 0) {
        $directory = $directories.Pop()
        foreach ($child in Get-ChildItem -LiteralPath $directory -Force) {
            if ($child.PSIsContainer) {
                if ($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                if ($excluded -notcontains $child.Name) { $directories.Push($child.FullName) }
            } else {
                $relative = $child.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
                $entries.Add([ordered]@{ path = $relative; bytes = $child.Length; sha256 = (Get-FileHash -LiteralPath $child.FullName -Algorithm SHA256).Hash.ToLowerInvariant() })
            }
        }
    }
    $ordered = @($entries | Sort-Object { $_.path })
    $canonical = ($ordered | ForEach-Object { $_.sha256 + '  ' + $_.path }) -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $treeHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
    return @{ sha256 = $treeHash; files = $ordered }
}

try {
    $engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
    $sdkRoot = Join-Path $projectRoot '.tools/android-rc1/sdk'
    $javaRoot = (Get-ChildItem (Join-Path $projectRoot '.tools/android-rc1/java') -Directory -Filter 'jdk-*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
    foreach ($required in @($engine, '.tools/android-templates/android_debug.apk', '.tools/windows-templates/windows_debug_x86_64.exe', "$sdkRoot/build-tools/36.1.0/apksigner.bat", "$sdkRoot/build-tools/36.1.0/aapt.exe")) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Missing local export dependency: $required" }
    }
    if (-not $javaRoot) { throw 'Missing isolated JDK17.' }
    New-Item -ItemType Directory -Force builds,.qa | Out-Null
    $env:JAVA_HOME = $javaRoot
    # Portable editor settings remain under .tools; runtime APPDATA is isolated.
    $env:APPDATA = Join-Path $projectRoot '.qa/first-expedition-runtime-appdata'
    $settingsPath = Join-Path $projectRoot '.tools/godot/editor_data/editor_settings-4.7.tres'
    $originalSettings = Get-Content -Raw -LiteralPath $settingsPath
    $settings = $originalSettings
    foreach ($setting in @{ 'export/android/java_sdk_path' = $javaRoot; 'export/android/android_sdk_path' = $sdkRoot }.GetEnumerator()) {
        $line = $setting.Key + ' = "' + $setting.Value.Replace('\', '/') + '"'
        if ($settings -match [regex]::Escape($setting.Key) + ' = ".*"') {
            $settings = $settings -replace ([regex]::Escape($setting.Key) + ' = ".*"'), $line
        } else { $settings += "`n$line`n" }
    }
    Set-Content -LiteralPath $settingsPath -Value $settings
    & $engine --headless --editor --path . --import --quit --log-file .qa/first_expedition_import.log *> .qa/first_expedition_import_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Import process failed.' }
    Assert-EngineLog '.qa/first_expedition_import_console.log'
    $source = Get-SourceManifest
    $sourceCommit = (git rev-parse HEAD).Trim()
    $gitStatus = @(git status --porcelain=v1 --untracked-files=all)
    $apk = Join-Path $projectRoot 'builds/WILDBOUND_First_Expedition_Android_Debug.apk'
    $windows = Join-Path $projectRoot 'builds/WILDBOUND_First_Expedition_Windows_Debug.exe'
    & $engine --headless --path . --export-debug 'Android First Expedition' $apk --log-file .qa/first_expedition_android_export.log *> .qa/first_expedition_android_export_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
    Assert-EngineLog '.qa/first_expedition_android_export_console.log'
    & $engine --headless --path . --export-debug 'Windows First Expedition' $windows --log-file .qa/first_expedition_windows_export.log *> .qa/first_expedition_windows_export_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
    Assert-EngineLog '.qa/first_expedition_windows_export_console.log'
    & "$sdkRoot/build-tools/36.1.0/apksigner.bat" verify --verbose $apk *> .qa/first_expedition_apk_signature.txt
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & "$sdkRoot/build-tools/36.1.0/aapt.exe" dump badging $apk *> .qa/first_expedition_apk_manifest.txt
    if ($LASTEXITCODE -ne 0) { throw 'APK manifest inspection failed.' }
    $badging = Get-Content -Raw .qa/first_expedition_apk_manifest.txt
    if ($badging -notmatch "package: name='com.wildbound.playtest' versionCode='600' versionName='0.6.0-expedition-alpha'" -or $badging -notmatch 'android.hardware.screen.landscape') { throw 'Unexpected APK identity/version/orientation.' }
    & $windows --headless --quit-after 120 --log-file (Join-Path $projectRoot '.qa/first_expedition_windows_runtime.log') *> .qa/first_expedition_windows_runtime_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Exported Windows runtime failed.' }
    Assert-EngineLog '.qa/first_expedition_windows_runtime_console.log'
    Assert-EngineLog '.qa/first_expedition_windows_runtime.log'
    $sourceAfter = Get-SourceManifest
    if ($source.sha256 -ne $sourceAfter.sha256) { throw 'Source changed during export; rebuild after edits settle.' }
    $artifacts = @($apk, $windows) | ForEach-Object { [ordered]@{ file = [IO.Path]::GetFileName($_); bytes = (Get-Item -LiteralPath $_).Length; sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() } }
    $info = [ordered]@{
        version = '0.6.0-expedition-alpha'
        builtAtUtc = [DateTime]::UtcNow.ToString('o')
        sourceCommit = $sourceCommit
        sourceDirty = [bool]$gitStatus.Count
        gitStatus = $gitStatus
        sourceTreeSha256 = $source.sha256
        sourceFiles = $source.files
        sourceExclusions = @('.git', '.godot', '.tools', '.qa', 'builds')
        toolHashes = @($engine, '.tools/android-templates/android_debug.apk', '.tools/windows-templates/windows_debug_x86_64.exe') | ForEach-Object { [ordered]@{ file = $_; sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() } }
        godot = (& $engine --version | Select-Object -First 1)
        artifacts = @($artifacts)
        androidPackage = 'com.wildbound.playtest'
        androidVersionCode = 600
        windowsRuntimeSmokePassed = $true
        realAndroidDeviceTested = $false
        publiclyPublished = $false
    }
    $info | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath builds/FIRST_EXPEDITION_BUILD_INFO.json
    $artifacts | ConvertTo-Json
    Write-Output "Source tree SHA256: $($source.sha256)"
} finally {
    if ($null -ne $originalSettings) { Set-Content -LiteralPath $settingsPath -Value $originalSettings }
    $env:APPDATA = $originalAppData
    $env:JAVA_HOME = $originalJava
    Pop-Location
}
