<#
 * build_server_setup.ps1 – Erstellt das Deployment-Paket für den Self-Hosted-Server
 *
 * Dieses Skript sammelt alle notwendigen Dateien aus dem Host-Verzeichnis,
 * bereinigt sie um Entwicklungs-Dateien (.htaccess/.htpasswd im dev-Ordner)
 * und schnürt ein ZIP-Archiv, das Nutzer zum Selbst-Hosten herunterladen können.
 *
 * Wird aufgerufen von: bin/deploy.ps1 (Schritt 4/4)
 * Kann aber auch eigenständig ausgeführt werden:
 *   .\bin\build_server_setup.ps1
 *   .\bin\build_server_setup.ps1 -ZipFile "C:\Pfad\zur\ausgabe.zip"
 *
 * Parameter:
 *   -ZipFile  (optional) Zielpfad der ZIP-Datei.
 *             Standard: <projektRoot>/famkey_server.zip
 *
 * Ziel-Struktur im Archiv:
 * /famkey
 *   /migrations      – Datenbankmigrationen
 *   /public
 *     /api           – REST-API-Endpunkte
 *     /dev           – Entwicklungs-Hilfswerkzeuge (ohne Auth-Dateien)
 *     /setup         – Ersteinrichtungs-Assistent
 *     .htaccess
 *     favicons.php
 *     index.html
 *   /src             – PHP-Bibliotheken und Klassen
 *   config.example.php
 *   routes.php
 *   LICENSE
 #>

param(
    [string]$ZipFile  # Zielpfad der ZIP-Datei; Standard: <projektRoot>/famkey_server.zip
)

$projectRoot = Split-Path -Parent $PSScriptRoot  # Wurzel des famkey-Projekts (Elternverzeichnis von bin/)
$stagingDir  = Join-Path $projectRoot "build_server"         # Temporäres Arbeitsverzeichnis; wird nach dem Build gelöscht
$famKeyDir   = Join-Path $stagingDir  "famkey"               # Unterverzeichnis im Staging, das direkt ins ZIP gepackt wird
$zipFile     = if ($ZipFile) { $ZipFile } else { Join-Path $projectRoot "famkey_server.zip" }  # Pfad der fertigen ZIP-Datei

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
