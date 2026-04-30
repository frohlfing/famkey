<#
.SYNOPSIS
    Installiert Xdebug in eine bestehende XAMPP-Umgebung.

.DESCRIPTION

# Manuelle Installation:

## XAMPP herunterladen
- XAMPP herunterladen:
   https://www.apachefriends.org/download.html
- Installation starten → **alle Default‑Einstellungen übernehmen**
   Zielverzeichnis: `C:\xampp`

## Xdebug installieren
- PHP‑Info erzeugen:
  Datei C:\xampp\htdocs\info.php:
  ```
  <?php phpinfo();
  ```
- Browser öffnen:
    http://localhost/info.php
- phpinfo‑Output kopieren.
- Xdebug Wizard öffnen:
    https://xdebug.org/wizard
- Output einfügen → Analyse starten.
- Empfohlene DLL herunterladen (z.B. `php_xdebug-3.x.x-8.4-vs16-x86_64.dll`).
- Datei speichern nach:
    C:\xampp\php\ext\php_xdebug.dll
- In php.ini am Ende einfügen:
    ```
    [Xdebug]
    zend_extension = "C:\xampp\php\ext\php_xdebug.dll"
    xdebug.mode = debug
    xdebug.start_with_request = yes
    xdebug.client_port = 9003
    xdebug.client_host = 127.0.0.1
    ```

## Apache starten & testen
  - XAMPP öffnen → Apache starten.
  - http://localhost/info.php öffnen.
  - Prüfen:
    - Xdebug‑Block sichtbar

.EXAMPLE
    .\xampp_install_xdebug.ps1
#>

# ------------------------------------------------------------------------
# 1. XAMPP stoppen (falls laufend)
# ------------------------------------------------------------------------

Write-Host "Stoppe Apache..."
Start-Process -FilePath "C:\xampp\xampp_stop.exe" -Wait

# ------------------------------------------------------------------------
# 2. PHP-Version ermitteln
# ------------------------------------------------------------------------

Write-Host "Ermittle PHP-Konfiguration..."
# Nutze CLI um phpinfo zu erhalten, damit Apache nicht laufen muss
$phpinfo = & "C:\xampp\php\php.exe" -i

# ------------------------------------------------------------------------
# 3. Xdebug-DLL herunterladen
# ------------------------------------------------------------------------

# Wizard POST
Write-Host "Kontaktiere Xdebug Wizard..."
$response = Invoke-WebRequest -Uri "https://xdebug.org/wizard" `
    -Method POST `
    -Body @{ data = $phpinfo }

# DLL-Link extrahieren
$dllUrl = ($response.Content | Select-String -Pattern "https://.*?dll").Matches.Value
if (-not $dllUrl) {
    Write-Error "Konnte Xdebug-DLL nicht finden."
    exit 1
}

# Herunterladen
Write-Host "Lade Xdebug herunter: $dllUrl"
$xdFile = "$env:TEMP\xdebug.dll"
Invoke-WebRequest -Uri $dllUrl -OutFile $xdFile

Copy-Item $xdFile "C:\xampp\php\ext\php_xdebug.dll" -Force

# ------------------------------------------------------------------------
# 4. php.ini erweitern
# ------------------------------------------------------------------------

$phpIniPath = "C:\xampp\php\php.ini"
$phpIniContent = Get-Content $phpIniPath -Raw

if ($phpIniContent -notlike "*php_xdebug.dll*") {
    Write-Host "Aktualisiere php.ini..."
    Add-Content $phpIniPath @"

[Xdebug]
zend_extension = "C:\xampp\php\ext\php_xdebug.dll"
xdebug.mode = debug
xdebug.start_with_request = yes
xdebug.client_port = 9003
xdebug.client_host = 127.0.0.1
"@
} else {
    Write-Host "Xdebug-Eintrag bereits in php.ini vorhanden."
}

# ------------------------------------------------------------------------
# 5. Apache starten
# ------------------------------------------------------------------------

Write-Host "Starte Apache..."
Start-Process -FilePath "C:\xampp\xampp_start.exe"

Write-Host "`nXdebug Installation abgeschlossen!"
