param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
    $sdkRoot = Join-Path $projectRoot '.tools/android-rc1/sdk'
    $javaRoot = (Get-ChildItem (Join-Path $projectRoot '.tools/android-rc1/java') -Directory -Filter 'jdk-*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
    if (-not $javaRoot -or -not (Test-Path "$sdkRoot/build-tools/36.1.0/apksigner.bat")) { throw 'Run tools/setup_android_tools.py, then install the SDK packages documented in docs/MOBILE_IMPLEMENTATION_REPORT.md.' }
    $env:JAVA_HOME = $javaRoot
    $env:APPDATA = Join-Path $projectRoot '.tools/godot/editor_data'
    $settingsPath = Join-Path $env:APPDATA 'editor_settings-4.7.tres'
    $settings = Get-Content -Raw -LiteralPath $settingsPath
    $settings = $settings -replace 'export/android/java_sdk_path = ".*"', ('export/android/java_sdk_path = "' + $javaRoot.Replace('\','/') + '"')
    $settings = $settings -replace 'export/android/android_sdk_path = ".*"', ('export/android/android_sdk_path = "' + $sdkRoot.Replace('\','/') + '"')
    Set-Content -LiteralPath $settingsPath -Value $settings
    New-Item -ItemType Directory -Force builds,.qa | Out-Null
    & $engine --headless --editor --path . --import --log-file .qa/rc1_import.log *> .qa/rc1_import_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed; see .qa/rc1_import_console.log.' }
    if (Select-String -Path .qa/rc1_import_console.log -Pattern 'SCRIPT ERROR:|Parse Error:') { throw 'Godot reported a script error during import.' }
    $apk = Join-Path $projectRoot 'builds/WILDBOUND_Mobile_RC1_Debug.apk'
    & $engine --headless --path . --export-debug 'Android RC1' $apk --log-file .qa/rc1_android_export.log *> .qa/rc1_android_export_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed; see .qa/rc1_android_export_console.log.' }
    if (Select-String -Path .qa/rc1_android_export_console.log -Pattern 'SCRIPT ERROR:|Parse Error:') { throw 'Godot reported a script error during export.' }
    & "$sdkRoot/build-tools/36.1.0/apksigner.bat" verify --verbose $apk | Set-Content .qa/rc1_apk_signature.txt
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & "$sdkRoot/build-tools/36.1.0/aapt.exe" dump badging $apk | Set-Content .qa/rc1_apk_manifest.txt
    if ($LASTEXITCODE -ne 0) { throw 'APK manifest verification failed.' }
    $manifest = Get-Content -Raw .qa/rc1_apk_manifest.txt
    if ($manifest -notmatch "package: name='com.wildbound.playtest'" -or $manifest -notmatch "android.hardware.screen.landscape") { throw 'Unexpected APK identity/orientation.' }
    $info = [ordered]@{
        file = 'WILDBOUND_Mobile_RC1_Debug.apk'
        sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = (Get-Item -LiteralPath $apk).Length
        sourceCommit = (git rev-parse HEAD)
        sourceDirty = [bool](git status --porcelain)
        godot = '4.7.2.stable.official.ed1daf0bf'
        package = 'com.wildbound.playtest'
        version = '0.4.0-mobile-rc1'
        realAndroidDeviceTested = $false
    }
    $info | ConvertTo-Json | Set-Content builds/RC1_BUILD_INFO.json
    $info | ConvertTo-Json
} finally { Pop-Location }
