<#
 * Erstellt das Deployment-Paket für den Server
 *
 * Dieses Skript sammelt alle notwendigen Dateien aus dem Host-Verzeichnis,
 * bereinigt sie um unnötige Entwicklungs-Dateien und schnürt ein ZIP-Archiv.
 *
 * Ziel-Struktur im Archiv:
 * /server
 *   /migrations
 *   /public
 *   /src
 *   config.example.php
 *   LICENSE
 #>

$projectRoot = Split-Path -Parent $PSScriptRoot
$stagingDir = Join-Path $projectRoot "build_server"
$famKeyDir = Join-Path $stagingDir "famkey"
$zipFile = Join-Path $projectRoot "famkey_server_setup.zip"

# ------------------------------------------------------------------------
# 1. Vorbereitung
# ------------------------------------------------------------------------

Write-Host "Bereite Build-Verzeichnis vor..." -ForegroundColor Cyan
if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }

New-Item -ItemType Directory -Path $famKeyDir | Out-Null

# ------------------------------------------------------------------------
# 2. Kopierbefehle
# ------------------------------------------------------------------------

Write-Host "Kopiere Komponenten..." -ForegroundColor Cyan

# Migrations
Write-Host "  [+] migrations"
Copy-Item -Path "$projectRoot/host/migrations" -Destination "$famKeyDir/migrations" -Recurse

# Public
Write-Host "  [+] public"
Copy-Item -Path "$projectRoot/host/public/api" -Destination "$famKeyDir/public/api" -Recurse

# DEV kopieren, aber .htaccess und .htpasswd ausschließen
Get-ChildItem "$projectRoot/host/public/dev" -Recurse |
    Where-Object {
        $_.FullName -notlike "*\.htaccess" -and
        $_.FullName -notlike "*\.htpasswd"
    } |
    Copy-Item -Destination "$famKeyDir/public/dev" -Recurse -Force

Copy-Item -Path "$projectRoot/host/public/setup" -Destination "$famKeyDir/public/setup" -Recurse
Copy-Item -Path "$projectRoot/host/public/.htaccess" -Destination "$famKeyDir/public/.htaccess"
Copy-Item -Path "$projectRoot/host/public/favicons.php" -Destination "$famKeyDir/public/favicons.php"
Copy-Item -Path "$projectRoot/host/public/index.html" -Destination "$famKeyDir/public/index.html"

# Source
Write-Host "  [+] src"
Copy-Item -Path "$projectRoot/host/src" -Destination "$famKeyDir/src" -Recurse

# Einzeldateien

Write-Host "  [+] config.example.php"
Copy-Item -Path "$projectRoot/host/config.example.php" -Destination "$famKeyDir/config.example.php"

Write-Host "  [+] routes.php"
Copy-Item -Path "$projectRoot/host/routes.php" -Destination "$famKeyDir/routes.php"

Write-Host "  [+] LICENSE"
Copy-Item -Path "$projectRoot/LICENSE" -Destination "$famKeyDir/LICENSE"

# ------------------------------------------------------------------------
# 3. Archivierung
# ------------------------------------------------------------------------

Write-Host "Erstelle ZIP-Archiv: $zipFile" -ForegroundColor Cyan
Compress-Archive -Path $famKeyDir -DestinationPath $zipFile

# Aufräumen
Remove-Item $stagingDir -Recurse -Force

Write-Host "`nBuild erfolgreich abgeschlossen!" -ForegroundColor Green
