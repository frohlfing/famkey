<#
.SYNOPSIS
    Installiert eine bestimmte PHP-Version in eine bestehende XAMPP-Umgebung.

.EXAMPLE
    # Neueste PHP‑Version installieren:
    .\xampp_upgrade_php.ps1

    # PHP 8.4 installieren:
    .\xampp_upgrade_php.ps1 8.4
#>

param(
    [string]$PhpVersion
)

# ------------------------------------------------------------------------
# 1. PHP-Version bestimmen
# ------------------------------------------------------------------------

if (-not $PhpVersion) {
    Write-Host "Ermittle neueste PHP-Version..."
    $latest = Invoke-WebRequest -Uri "https://windows.php.net/download" -UseBasicParsing
    $match = ($latest.Content | Select-String -Pattern "php-(\d+\.\d+\.\d+)-Win32").Matches
    if ($match.Count -eq 0) {
        Write-Error "Konnte keine PHP-Version finden."
        exit 1
    }
    $PhpVersion = $match[0].Groups[1].Value
}

Write-Host "Verwende PHP-Version: $PhpVersion"

# ------------------------------------------------------------------------
# 2. PHP herunterladen
# ------------------------------------------------------------------------

$phpZip = "php-$PhpVersion-Win32-vs16-x64.zip"
$phpUrl = "https://windows.php.net/downloads/releases/$phpZip"

$downloadPath = "$env:TEMP\$phpZip"
$extractPath = "C:\xampp\php-new"
$backupPath  = "C:\xampp\php-backup"

# Herunterladen
Write-Host "Lade PHP herunter: $phpUrl"
Invoke-WebRequest -Uri $phpUrl -OutFile $downloadPath

# ------------------------------------------------------------------------
# 3. Entpacken
# ------------------------------------------------------------------------

Write-Host "Entpacke nach $extractPath..."
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $downloadPath -DestinationPath $extractPath

# ------------------------------------------------------------------------
# 4. XAMPP stoppen
# ------------------------------------------------------------------------

Write-Host "Stoppe Apache..."
Start-Process -FilePath "C:\xampp\xampp_stop.exe" -Wait

# ------------------------------------------------------------------------
# 5. Backup & Austausch
# ------------------------------------------------------------------------

Write-Host "Backup alter PHP-Version..."
if (Test-Path $backupPath) { Remove-Item $backupPath -Recurse -Force }
Rename-Item -Path "C:\xampp\php" -NewName "php-backup"

Write-Host "Neue PHP-Version aktivieren..."
Rename-Item -Path $extractPath -NewName "C:\xampp\php"

# ------------------------------------------------------------------------
# 6. php.ini übernehmen
# ------------------------------------------------------------------------

Write-Host "Übernehme php.ini..."
Copy-Item "C:\xampp\php-backup\php.ini" "C:\xampp\php\php.ini" -Force

# ------------------------------------------------------------------------
# 7. Apache starten
# ------------------------------------------------------------------------

Write-Host "Starte Apache..."
Start-Process -FilePath "C:\xampp\xampp_start.exe"

Write-Host "`nUpgrade abgeschlossen!"
Write-Host "PHP-Version: $PhpVersion"
Write-Host "Backup: $backupPath"
