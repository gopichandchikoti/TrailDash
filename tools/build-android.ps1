param(
    [string]$Godot = $env:GODOT_BIN,
    [string]$Adb = (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'),
    [string]$Device = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
        throw 'Set GODOT_BIN to the matching Godot 4.7.2 console executable.'
    }
    New-Item -ItemType Directory -Path 'builds' -Force | Out-Null
    $version = (Select-String -LiteralPath 'project.godot' -Pattern '^config/version="(.*)"$').Matches[0].Groups[1].Value
    $apk = "builds/traildash-$version-debug.apk"
    $output = & $Godot --headless --path . --export-debug Android $apk 2>&1
    $exitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath 'builds/export.log'
    if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:')) {
        throw 'Android export failed; see builds/export.log.'
    }
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $projectRoot "$apk.sha256"), "$hash  $(Split-Path -Leaf $apk)`n")
    Write-Output "Built $apk"
    if ($Device) {
        $waiter = Start-Process -FilePath $Adb -ArgumentList @('-s', $Device, 'wait-for-device') `
            -PassThru -WindowStyle Hidden
        if (-not $waiter.WaitForExit(30000)) {
            $waiter.Kill()
            throw 'The selected Android device did not become ready within 30 seconds.'
        }
        & $Adb -s $Device install -r $apk
        if ($LASTEXITCODE -ne 0) { throw 'APK install failed.' }
        & $Adb -s $Device shell am start -n 'com.portfolio.traildash/com.godot.game.GodotAppLauncher'
        if ($LASTEXITCODE -ne 0) { throw 'APK launch failed.' }
    }
} finally {
    Pop-Location
}
