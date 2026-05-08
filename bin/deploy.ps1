<#
 * deploy_all.ps1 – Automatischer Full-Build für alle Plattformen
 *
 * 1. Liest Version aus pubspec.yaml und die Umgebungsvariablen aus env.ps1.
 * 2. Baut Windows, Android (APK), Web und Server-Paket – jeweils nur wenn das Ziel-Artefakt für diese Version noch nicht existiert.
 * 3. Kopiert alle Artefakte nach $env:FAMKEY_HOME_PUBLIC/releases/<version>.
 * 4. Kopiert die Web-App zusätzlich nach $env:FAMKEY_HOME_PUBLIC/app, damit sie auf der Homepage direkt gestartet werden kann.
 #>

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$envFile = "$projectRoot/env.ps1"
if (Test-Path $envFile) { . $envFile }
if (-not $env:FAMKEY_HOME_PUBLIC) {
    Write-Error "FAMKEY_HOME_PUBLIC nicht gesetzt. Bitte env.ps1 anlegen (Vorlage: env.example.ps1)."
    exit 1
}

# 1. Version aus pubspec.yaml extrahieren
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "version:\s*([0-9.]+)\+([0-9]+)") {
    $versionName = $Matches[1]
    $buildNumber = $Matches[2]
    $fullVersion = "$versionName.$buildNumber"
} else {
    Write-Error "Konnte Version nicht in pubspec.yaml finden."
    exit 1
}

$releaseDir = "$env:FAMKEY_HOME_PUBLIC/releases/$fullVersion"
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

Write-Host "--- FamKey v$fullVersion ---" -ForegroundColor Cyan

# 2. Builds – jeweils überspringen wenn Artefakt bereits vorhanden

Write-Host "[1/4] Windows..." -ForegroundColor Yellow
if (Test-Path "$releaseDir/famkey_windows.zip") {
    Write-Host "      Bereits vorhanden, übersprungen." -ForegroundColor DarkGray
} else {
    flutter build windows --release | Out-Null
    $winSource = "$projectRoot/build/windows/x64/runner/Release"
    Copy-Item "$projectRoot/sqlite3mc_x64.dll" -Destination $winSource -Force
    Compress-Archive -Path "$winSource/*" -DestinationPath "$releaseDir/famkey_windows.zip" -Force
}

Write-Host "[2/4] Android APK..." -ForegroundColor Yellow
if (Test-Path "$releaseDir/famkey_android.apk") {
    Write-Host "      Bereits vorhanden, übersprungen." -ForegroundColor DarkGray
} else {
    flutter build apk --release | Out-Null
    Copy-Item "$projectRoot/build/app/outputs/flutter-apk/app-release.apk" -Destination "$releaseDir/famkey_android.apk" -Force
}

Write-Host "[3/4] Web..." -ForegroundColor Yellow
if (Test-Path "$releaseDir/famkey_web.zip") {
    Write-Host "      Bereits vorhanden, übersprungen." -ForegroundColor DarkGray
} else {
    flutter build web --release --base-href "/app/" | Out-Null
    Compress-Archive -Path "$projectRoot/build/web/*" -DestinationPath "$releaseDir/famkey_web.zip" -Force
}
$webDest = "$env:FAMKEY_HOME_PUBLIC/app"
if (Test-Path $webDest) { Remove-Item $webDest -Recurse -Force }
New-Item -ItemType Directory -Path $webDest -Force | Out-Null
if (Test-Path "$projectRoot/build/web/index.html") {
    Copy-Item "$projectRoot/build/web/*" -Destination $webDest -Recurse -Force
} else {
    Expand-Archive -Path "$releaseDir/famkey_web.zip" -DestinationPath $webDest -Force
}

Write-Host "[4/4] Server-Paket..." -ForegroundColor Yellow
if (Test-Path "$releaseDir/famkey_server.zip") {
    Write-Host "      Bereits vorhanden, übersprungen." -ForegroundColor DarkGray
} else {
    & "$PSScriptRoot/build_server_setup.ps1" -ZipFile "$releaseDir/famkey_server.zip" | Out-Null
}

Write-Host "`nOK Fertig! Artefakte in $env:FAMKEY_HOME_PUBLIC/releases/$fullVersion/" -ForegroundColor Green
