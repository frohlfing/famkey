#Requires -Version 5.1
<#
.SYNOPSIS
    Schnürt das FamKey-Server-Release-Paket als ZIP-Archiv.

.DESCRIPTION
    Liest die zu packenden Dateien aus manifest.txt (im selben Ordner).
    Die Zielstruktur im ZIP ist:

        server-root/   →  eine Ebene OBERHALB des Web-Root hochladen
        web-root/      →  Inhalt direkt in den Web-Root hochladen

.PARAMETER Version
    Versionsnummer (Standard: wird aus pubspec.yaml im Projekt-Root gelesen).

.PARAMETER OutDir
    Ausgabe-Verzeichnis für das ZIP (Standard: <Projekt-Root>/dist/).

.EXAMPLE
    .\build-server-release.ps1
    .\build-server-release.ps1 -Version 1.2.0
    .\build-server-release.ps1 -Version 1.2.0 -OutDir C:\Releases
#>
param(
    [string]$Version = '',
    [string]$OutDir  = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Pfade ──────────────────────────────────────────────────────────────────────
$setupDir   = $PSScriptRoot                          # host/setup/
$hostDir    = Split-Path $setupDir -Parent           # host/
$projectDir = Split-Path $hostDir  -Parent           # Projekt-Root
$manifestFile = Join-Path $setupDir 'manifest.txt'

if ($OutDir -eq '') { $OutDir = Join-Path $projectDir 'dist' }

# ── Version ermitteln ──────────────────────────────────────────────────────────
if ($Version -eq '') {
    $pubspec = Join-Path $projectDir 'pubspec.yaml'
    if (Test-Path $pubspec) {
        $match = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)' | Select-Object -First 1
        if ($match) {
            $Version = $match.Matches[0].Groups[1].Value -replace '\+.*$', ''
        }
    }
    if ($Version -eq '') { $Version = '0.0.1' }
}

Write-Host "FamKey Server Release Builder" -ForegroundColor Cyan
Write-Host "Version  : $Version"
Write-Host "Manifest : $manifestFile"
Write-Host "Ausgabe  : $OutDir"

# ── Manifest einlesen ─────────────────────────────────────────────────────────
if (-not (Test-Path $manifestFile)) {
    Write-Error "manifest.txt nicht gefunden: $manifestFile"
    exit 1
}

$entries = @()
foreach ($line in Get-Content $manifestFile -Encoding UTF8) {
    $line = $line.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }
    $parts = $line -split '\|', 2
    if ($parts.Count -ne 2) {
        Write-Warning "Ungültige Zeile in manifest.txt (übersprungen): $line"
        continue
    }
    $entries += [PSCustomObject]@{
        Dest = $parts[0].Trim()
        Src  = $parts[1].Trim()
    }
}

Write-Host "Einträge : $($entries.Count)`n"

# ── Temp-Verzeichnis vorbereiten ──────────────────────────────────────────────
$tmpDir  = Join-Path $OutDir "FamKey-server-$Version"
$zipName = "FamKey-server-v$Version.zip"
$zipPath = Join-Path $OutDir $zipName

if (Test-Path $tmpDir)  { Remove-Item $tmpDir  -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

# ── Dateien kopieren ──────────────────────────────────────────────────────────
Write-Host "Kopiere Dateien..."

foreach ($entry in $entries) {
    $srcPath  = Join-Path $hostDir $entry.Src
    $destPath = Join-Path $tmpDir  $entry.Dest

    if (-not (Test-Path $srcPath)) {
        Write-Warning "  ! NICHT GEFUNDEN: $($entry.Src)  →  übersprungen"^^
        continue
    }

    $destParent = Split-Path $destPath -Parent
    if (-not (Test-Path $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    if (Test-Path $srcPath -PathType Container) {
        Copy-Item $srcPath -Destination $destPath -Recurse -Force
    } else {
        Copy-Item $srcPath -Destination $destPath -Force
    }

    Write-Host "  + $($entry.Dest)"
}

# ── ZIP erstellen ──────────────────────────────────────────────────────────────
Write-Host "`nErstelle ZIP: $zipName ..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmpDir, $zipPath)

# ── Temp aufräumen ─────────────────────────────────────────────────────────────
Remove-Item $tmpDir -Recurse -Force

# ── Ergebnis ───────────────────────────────────────────────────────────────────
$size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host "`nFertig!  $zipName  ($size KB)" -ForegroundColor Green
Write-Host "Pfad: $zipPath"
