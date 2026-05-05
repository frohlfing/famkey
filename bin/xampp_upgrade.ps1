<#
 * Aktualisiert PHP in XAMPP und installiert Xdebug automatisch.
 *
 * Dieses Skript führt folgende Schritte aus:
 *   1. Lädt neueste PHP-Version herunter (oder nutzt vorhandene)
 *   2. Installiert PHP in XAMPP (übersprungen wenn bereits installiert)
 *   3. Korrigiert php.ini automatisch
 *   4. Installiert passende Xdebug-Version
 *   5. Testet die Installation
 *
 * Neueste PHP-Version installieren:
 *   .\xampp_upgrade_php.ps1
 *
 * Bestimmte PHP-Version installieren:
 *   .\xampp_upgrade_php.ps1 -PhpVersion 8.5.5
 #>

param(
    [string]$PhpVersion
)

$ErrorActionPreference = "Stop"

# ========================================================================
# HILFSFUNKTIONEN
# ========================================================================

function Test-ApacheRunning {
    return (Get-Process -Name "httpd" -ErrorAction SilentlyContinue) -ne $null
}

function Stop-XamppApache {
    Write-Host ""
    Write-Host ">>> Stoppe Apache..." -ForegroundColor Cyan

    if (Test-ApacheRunning) {
        if (Test-Path "C:\xampp\xampp_stop.exe") {
            Start-Process -FilePath "C:\xampp\xampp_stop.exe" -Wait -NoNewWindow
        } else {
            Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
    }

    if (Test-ApacheRunning) {
        Write-Error "Apache konnte nicht gestoppt werden!"
    }
    Write-Host "[OK] Apache gestoppt" -ForegroundColor Green
}

function Test-Port80Listening {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $tcp.Connect("127.0.0.1", 80)
        return $tcp.Connected
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

function Start-XamppApache {
    Write-Host ""
    Write-Host ">>> Starte Apache..." -ForegroundColor Cyan

    if (Test-Path "C:\xampp\xampp_start.exe") {
        Start-Process -FilePath "C:\xampp\xampp_start.exe" -NoNewWindow
    } else {
        Start-Process -FilePath "C:\xampp\apache\bin\httpd.exe" -NoNewWindow
    }

    # Warte bis Port 80 antwortet (max. 10 Sekunden)
    $waited = 0
    while ($waited -lt 10) {
        Start-Sleep -Seconds 1
        $waited++
        if (Test-Port80Listening) {
            Write-Host "[OK] Apache gestartet" -ForegroundColor Green
            return $true
        }
    }

    Write-Warning "Apache konnte nicht gestartet werden! Pruefe C:\xampp\apache\logs\error.log"
    return $false
}

function Repair-PhpIni {
    param(
        [string]$PhpIniPath
    )
    
    Write-Host "Pruefe und korrigiere php.ini..." -ForegroundColor Yellow
    
    if (-not (Test-Path $PhpIniPath)) {
        Write-Host "  Erstelle php.ini aus Vorlage..." -ForegroundColor Gray
        if (Test-Path "C:\xampp\php\php.ini-development") {
            Copy-Item "C:\xampp\php\php.ini-development" $PhpIniPath
        } elseif (Test-Path "C:\xampp\php\php.ini-production") {
            Copy-Item "C:\xampp\php\php.ini-production" $PhpIniPath
        } else {
            Write-Error "Keine php.ini-Vorlage gefunden!"
        }
    }
    
    $iniLines = Get-Content $PhpIniPath
    $modified = $false
    $phpExtPath = "C:\xampp\php\ext"
    $foundExtDir = $false

    for ($i = 0; $i -lt $iniLines.Count; $i++) {
        $line = $iniLines[$i]

        # 1. Extension Directory korrigieren
        if ($line -match '^\s*;?\s*extension_dir\s*=') {
            $foundExtDir = $true
            if ($line -notmatch 'extension_dir\s*=\s*"C:\\xampp\\php\\ext"') {
                $iniLines[$i] = 'extension_dir = "C:\xampp\php\ext"'
                $modified = $true
                Write-Host "  - Extension Directory korrigiert" -ForegroundColor Gray
            }
        }
        
        # 2. Browscap deaktivieren
        if ($line -match '^\s*browscap\s*=' -and -not (Test-Path "C:\xampp\php\extras\browscap.ini")) {
            $iniLines[$i] = "; $line  ; Datei fehlt"
            $modified = $true
            Write-Host "  - Browscap deaktiviert (Datei fehlt)" -ForegroundColor Gray
        }
        
        # 3. Extension-Namen prüfen und fehlende DLLs deaktivieren
        if ($line -match '^\s*extension\s*=\s*([^\s;]+)') {
            $extValue = $matches[1].Trim()
            
            # Extrahiere Extension-Namen
            $extName = $extValue -replace '^php_', '' -replace '\.dll$', ''
            $expectedDll = "php_$extName.dll"
            $dllPath = Join-Path $phpExtPath $expectedDll
            
            # Wenn DLL nicht existiert, auskommentieren
            if (-not (Test-Path $dllPath)) {
                $iniLines[$i] = "; $line  ; DLL nicht vorhanden"
                $modified = $true
                Write-Host "  - Extension $extName deaktiviert (DLL fehlt)" -ForegroundColor Gray
            }
            # Wenn Format falsch ist (z.B. "extension=curl" statt "extension=php_curl.dll")
            elseif ($extValue -ne $expectedDll) {
                $iniLines[$i] = "extension=$expectedDll"
                $modified = $true
                Write-Host "  - Extension $extName korrigiert" -ForegroundColor Gray
            }
        }
        
        # 4. Timezone setzen
        if ($line -match '^\s*;\s*date\.timezone\s*=') {
            $iniLines[$i] = 'date.timezone = Europe/Berlin'
            $modified = $true
            Write-Host "  - Timezone gesetzt" -ForegroundColor Gray
        }
    }
    
    # Extension Directory hinzufügen falls komplett fehlend (PHP würde sonst C:\php\ext als Compiled-in-Default nutzen)
    if (-not $foundExtDir) {
        $iniLines += 'extension_dir = "C:\xampp\php\ext"'
        $modified = $true
        Write-Host "  - Extension Directory hinzugefuegt" -ForegroundColor Gray
    }

    if ($modified) {
        $iniLines | Set-Content $PhpIniPath
        Write-Host "[OK] php.ini korrigiert" -ForegroundColor Green
    } else {
        Write-Host "[OK] php.ini ist bereits korrekt" -ForegroundColor Green
    }
}

# ========================================================================
# SCHRITT 1: PHP-VERSION BESTIMMEN
# ========================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "XAMPP PHP UPGRADE + XDEBUG INSTALLATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not $PhpVersion) {
    Write-Host ""
    Write-Host "[1/9] Ermittle neueste PHP-Version..." -ForegroundColor Cyan
    try {
        $latest = Invoke-WebRequest -Uri "https://windows.php.net/download" -UseBasicParsing
        $match = ($latest.Content | Select-String -Pattern "php-(\d+\.\d+\.\d+)-Win32").Matches
        if ($match.Count -eq 0) {
            Write-Error "Konnte keine PHP-Version finden."
        }
        $PhpVersion = $match[0].Groups[1].Value
    } catch {
        Write-Error "Fehler beim Abrufen der PHP-Version: $_"
    }
} else {
    Write-Host ""
    Write-Host "[1/9] Verwende angegebene PHP-Version..." -ForegroundColor Cyan
}

Write-Host "Ziel-Version: $PhpVersion" -ForegroundColor Yellow

# Prüfe ob PHP bereits in dieser Version installiert ist
$phpExe = "C:\xampp\php\php.exe"
$skipPhpInstall = $false

if (Test-Path $phpExe) {
    # WICHTIG: php.ini VOR dem ersten PHP-Aufruf reparieren
    $phpIniPath = "C:\xampp\php\php.ini"
    if (Test-Path $phpIniPath) {
        Write-Host "Repariere php.ini vor Version-Check..." -ForegroundColor Gray
        
        $iniLines = Get-Content $phpIniPath
        $modified = $false
        $phpExtPath = "C:\xampp\php\ext"
        
        # Durchlaufe alle Zeilen und deaktiviere fehlende Extensions
        for ($i = 0; $i -lt $iniLines.Count; $i++) {
            $line = $iniLines[$i]
            
            # Suche nach "extension=..." Zeilen
            if ($line -match '^\s*extension\s*=\s*(?:php_)?([a-z0-9_]+)(?:\.dll)?\s*$') {
                $extName = $matches[1]
                $dllPath = Join-Path $phpExtPath "php_$extName.dll"
                
                # Wenn DLL nicht existiert, Zeile auskommentieren
                if (-not (Test-Path $dllPath)) {
                    $iniLines[$i] = "; $line  ; DLL nicht gefunden"
                    $modified = $true
                }
            }
        }
        
        if ($modified) {
            $iniLines | Set-Content $phpIniPath
            Write-Host "  - Fehlende Extensions deaktiviert" -ForegroundColor Gray
        }
    }
    
    # Xdebug-Mode deaktivieren, damit kein IDE-Verbindungsversuch und kein Pipe-Blockieren
    $ErrorActionPreference = "SilentlyContinue"
    $currentVersion = & $phpExe -d xdebug.mode=off -r "echo PHP_VERSION;" 2>$null | Select-Object -First 1
    $ErrorActionPreference = "Stop"
    
    if (-not $currentVersion) {
        Write-Warning "Konnte aktuelle PHP-Version nicht ermitteln"
        $currentVersion = "unknown"
    }
    
    $currentVersion = $currentVersion.Trim()
    
    if ($currentVersion -eq $PhpVersion) {
        Write-Host "[OK] PHP $PhpVersion ist bereits installiert" -ForegroundColor Green
        $skipPhpInstall = $true
    } elseif ($currentVersion -eq "unknown") {
        Write-Host "PHP-Installation gefunden, Version unbekannt (wird aktualisiert)" -ForegroundColor Yellow
    } else {
        Write-Host "Aktuelle Version: $currentVersion (Upgrade erforderlich)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Keine PHP-Installation gefunden" -ForegroundColor Yellow
}

# ========================================================================
# SCHRITT 2: PHP HERUNTERLADEN (wenn nötig)
# ========================================================================

$downloadPath = ""

if (-not $skipPhpInstall) {
    Write-Host ""
    Write-Host "[2/9] Pruefe PHP-Download..." -ForegroundColor Cyan

    $phpZip = "php-$PhpVersion-Win32-vs17-x64.zip"
    $phpUrl = "https://windows.php.net/downloads/releases/$phpZip"
    $downloadPath = "$env:TEMP\$phpZip"

    # Prüfe ob bereits heruntergeladen
    if (Test-Path $downloadPath) {
        $fileSize = (Get-Item $downloadPath).Length
        if ($fileSize -gt 1MB) {
            Write-Host "[OK] Verwende bereits heruntergeladene Datei: $downloadPath" -ForegroundColor Green
            Write-Host "    Groesse: $([math]::Round($fileSize / 1MB, 2)) MB" -ForegroundColor Gray
        } else {
            Write-Host "Vorhandene Datei ungueltig, lade neu herunter..." -ForegroundColor Yellow
            Remove-Item $downloadPath -Force
        }
    }

    # Download nur wenn nicht vorhanden
    if (-not (Test-Path $downloadPath)) {
        Write-Host "Lade herunter: $phpUrl" -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri $phpUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
            Write-Host "[OK] Download abgeschlossen" -ForegroundColor Green
        } catch {
            Write-Error "Download fehlgeschlagen. Pruefe ob PHP $PhpVersion verfuegbar ist: https://windows.php.net/download`nFehler: $_"
        }
    }
} else {
    Write-Host ""
    Write-Host "[2/9] PHP-Download uebersprungen (bereits installiert)" -ForegroundColor Green
}

# ========================================================================
# SCHRITT 3: APACHE STOPPEN
# ========================================================================

if (-not $skipPhpInstall) {
    Stop-XamppApache
} else {
    Write-Host ""
    Write-Host "[3/9] Apache-Stop uebersprungen" -ForegroundColor Green
}

# ========================================================================
# SCHRITT 4: PHP ENTPACKEN UND INSTALLIEREN
# ========================================================================

if (-not $skipPhpInstall) {
    Write-Host ""
    Write-Host "[4/9] Installiere PHP..." -ForegroundColor Cyan

    $extractPath = "C:\xampp\php-new"
    $backupPath = "C:\xampp\php-backup"

    # Entpacken
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath

    # Prüfe ob PHP in Unterverzeichnis entpackt wurde
    $phpExtractRoot = $extractPath
    $subDirs = Get-ChildItem -Path $extractPath -Directory
    if ($subDirs.Count -eq 1 -and (Test-Path "$($subDirs[0].FullName)\php.exe")) {
        $phpExtractRoot = $subDirs[0].FullName
        Write-Host "  PHP in Unterverzeichnis gefunden: $($subDirs[0].Name)" -ForegroundColor Gray
    }

    # Backup erstellen
    if (Test-Path "C:\xampp\php") {
        if (Test-Path $backupPath) {
            Remove-Item $backupPath -Recurse -Force
        }
        Rename-Item -Path "C:\xampp\php" -NewName "php-backup"
        Write-Host "  Backup erstellt: $backupPath" -ForegroundColor Gray
    }

    # Neue Version installieren
    if ($phpExtractRoot -ne $extractPath) {
        New-Item -Path "C:\xampp\php" -ItemType Directory -Force | Out-Null
        Copy-Item "$phpExtractRoot\*" "C:\xampp\php\" -Recurse -Force
        Remove-Item $extractPath -Recurse -Force
    } else {
        Rename-Item -Path $extractPath -NewName "php"
    }

    Write-Host "[OK] PHP $PhpVersion installiert" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[4/9] PHP-Installation uebersprungen" -ForegroundColor Green
}

# ========================================================================
# SCHRITT 5: PHP.INI KONFIGURIEREN
# ========================================================================

Write-Host ""
Write-Host "[5/9] Konfiguriere PHP..." -ForegroundColor Cyan

$phpIniPath = "C:\xampp\php\php.ini"
$backupPath = "C:\xampp\php-backup"

# Alte php.ini übernehmen falls vorhanden und noch keine existiert
if (-not $skipPhpInstall -and (Test-Path "$backupPath\php.ini") -and -not (Test-Path $phpIniPath)) {
    Copy-Item "$backupPath\php.ini" $phpIniPath -Force
    Write-Host "  Alte php.ini uebernommen" -ForegroundColor Gray
}

# php.ini reparieren
Repair-PhpIni -PhpIniPath $phpIniPath

# ========================================================================
# SCHRITT 6: PHP TESTEN
# ========================================================================

Write-Host ""
Write-Host ""
Write-Host "[6/9] Teste PHP-Installation..." -ForegroundColor Cyan

$ErrorActionPreference = "SilentlyContinue"
$phpVersionActual = & $phpExe -d xdebug.mode=off -r "echo PHP_VERSION;" 2>$null | Select-Object -First 1
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -ne 0 -or -not $phpVersionActual) {
    Write-Error "PHP-Test fehlgeschlagen!"
}

$phpVersionActual = $phpVersionActual.Trim()
Write-Host "Installierte Version: $phpVersionActual" -ForegroundColor Yellow

$ErrorActionPreference = "SilentlyContinue"
$testOutput = & $phpExe -d xdebug.mode=off -r "echo 'OK';" 2>$null
$ErrorActionPreference = "Stop"
$hasErrors = $testOutput | Where-Object { $_ -match "Fatal error" }

if ($testOutput -match "OK" -and -not $hasErrors) {
    Write-Host "[OK] PHP funktioniert einwandfrei" -ForegroundColor Green
} else {
    Write-Warning "PHP hat Warnungen (meist fehlende Extensions, nicht kritisch)"
}

# ========================================================================
# SCHRITT 7: XDEBUG-VERSION ERMITTELN
# ========================================================================

Write-Host ""
Write-Host "[7/9] Suche passende Xdebug-Version..." -ForegroundColor Cyan

$phpMajorMinor = $phpVersionActual -replace '^(\d+\.\d+).*', '$1'

# Prüfe ob Xdebug bereits installiert ist (trigger statt off: extension_loaded() soll true liefern)
$ErrorActionPreference = "SilentlyContinue"
$xdebugInstalled = & $phpExe -d xdebug.start_with_request=trigger -r "echo extension_loaded('xdebug') ? phpversion('xdebug') : 'NO';" 2>$null | Select-Object -First 1
$ErrorActionPreference = "Stop"

if ($xdebugInstalled -and $xdebugInstalled -ne 'NO') {
    Write-Host "[OK] Xdebug $xdebugInstalled ist bereits installiert" -ForegroundColor Green
    $skipXdebug = $true
} else {
    # Architektur und Thread-Safety prüfen
    $ErrorActionPreference = "SilentlyContinue"
    $phpInfo = & $phpExe -d xdebug.mode=off -i 2>$null
    $ErrorActionPreference = "Stop"
    $isTS  = [bool]($phpInfo -match "Thread Safety\s+=>\s+enabled")
    $isX64 = [bool]($phpInfo -match "Architecture\s+=>\s+x64")

    if (-not $isTS) {
        Write-Warning "PHP ist nicht Thread-Safe! Xdebug funktioniert moeglicherweise nicht korrekt."
    }
    if (-not $isX64) {
        Write-Warning "PHP ist nicht x64! Xdebug funktioniert moeglicherweise nicht korrekt."
    }

    Write-Host "PHP: $phpVersionActual (TS: $isTS, x64: $isX64)" -ForegroundColor Yellow

    try {
        $xdebugPage = Invoke-WebRequest -Uri "https://xdebug.org/download" -UseBasicParsing
    } catch {
        Write-Error "Konnte Xdebug-Download-Seite nicht abrufen: $_"
    }

    # Suche nach passender Xdebug-Version.
    # Xdebug-Dateiname: php_xdebug-{ver}-{php}-ts-vs17-x86_64.dll (TS)
    #                   php_xdebug-{ver}-{php}-vs17-x86_64.dll    (NTS)
    $tsSuffix = if ($isTS) { "ts-" } else { "" }
    $patterns = @(
        "php_xdebug-([0-9.]+)-$phpMajorMinor-${tsSuffix}vs17-x86_64\.dll",
        "php_xdebug-([0-9.]+)-$phpMajorMinor-${tsSuffix}vs16-x86_64\.dll"
    )
    
    $xdebugFile = $null
    foreach ($pattern in $patterns) {
        $match = $xdebugPage.Content | Select-String -Pattern $pattern -AllMatches
        if ($match.Matches.Count -gt 0) {
            $xdebugFile = $match.Matches[0].Value
            break
        }
    }
    
    if (-not $xdebugFile) {
        Write-Warning "Keine passende Xdebug-Version fuer PHP $phpMajorMinor gefunden!"
        Write-Host "Ueberspringe Xdebug-Installation. Manuelle Installation moeglich: https://xdebug.org/wizard" -ForegroundColor Yellow
        $skipXdebug = $true
    } else {
        Write-Host "Gefunden: $xdebugFile" -ForegroundColor Yellow
        $skipXdebug = $false
    }
}

# ========================================================================
# SCHRITT 8: XDEBUG INSTALLIEREN
# ========================================================================

if (-not $skipXdebug) {
    Write-Host ""
    Write-Host "[8/9] Installiere Xdebug..." -ForegroundColor Cyan

    $dllUrl = "https://xdebug.org/files/$xdebugFile"
    $xdFile = "$env:TEMP\xdebug.dll"
    $xdTarget = "C:\xampp\php\ext\php_xdebug.dll"

    # Prüfe ob bereits heruntergeladen
    $needDownload = $true
    if (Test-Path $xdFile) {
        $fileSize = (Get-Item $xdFile).Length
        if ($fileSize -gt 100KB) {
            Write-Host "Verwende bereits heruntergeladene Datei" -ForegroundColor Gray
            $needDownload = $false
        }
    }

    if ($needDownload) {
        Write-Host "Lade herunter: $dllUrl" -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri $dllUrl -OutFile $xdFile -UseBasicParsing
        } catch {
            Write-Warning "Xdebug-Download fehlgeschlagen: $_"
            $skipXdebug = $true
        }
    }

    if (-not $skipXdebug) {
        if (Test-Path $xdTarget) {
            $backup = "$xdTarget.backup"
            Copy-Item $xdTarget $backup -Force
            Write-Host "  Backup erstellt: $backup" -ForegroundColor Gray
        }

        Copy-Item $xdFile $xdTarget -Force

        Write-Host "[OK] Xdebug installiert" -ForegroundColor Green

        # php.ini für Xdebug konfigurieren
        Write-Host "Konfiguriere Xdebug..." -ForegroundColor Yellow

        $phpIniContent = Get-Content $phpIniPath -Raw

        # Entferne alte Xdebug-Konfiguration
        $phpIniContent = $phpIniContent -replace '(?ms)\[Xdebug\].*?(?=\n\[|\Z)', ''

        # Log-Verzeichnis erstellen
        $logDir = "C:\xampp\php\logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Füge neue Konfiguration hinzu.
        # start_with_request = trigger: Debugging nur bei explizitem XDEBUG_SESSION-Cookie / -Trigger,
        # nicht bei jedem CLI-Aufruf. Verhindert, dass das Skript selbst am IDE-Debugger hängt.
        $xdebugConfig = @"

[Xdebug]
zend_extension = "C:\xampp\php\ext\php_xdebug.dll"
xdebug.mode = debug
xdebug.start_with_request = trigger
xdebug.client_port = 9003
xdebug.client_host = 127.0.0.1
xdebug.log = "C:\xampp\php\logs\xdebug.log"
"@

        $phpIniContent = $phpIniContent.TrimEnd() + "`n" + $xdebugConfig
        $phpIniContent | Set-Content $phpIniPath -NoNewline

        Write-Host "[OK] Xdebug konfiguriert" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "[8/9] Xdebug-Installation uebersprungen (bereits installiert)" -ForegroundColor Green
}

# ========================================================================
# SCHRITT 9: APACHE STARTEN UND TESTEN
# ========================================================================

$apacheStarted = Start-XamppApache

Write-Host ""
Write-Host "[9/9] Teste Installation..." -ForegroundColor Cyan

if (-not $skipXdebug) {
    Start-Sleep -Seconds 2

    # Xdebug in CLI testen (-d verhindert IDE-Verbindung, falls start_with_request noch auf 'yes' steht)
    $xdebugTest = & $phpExe -d xdebug.start_with_request=trigger -r "echo extension_loaded('xdebug') ? 'LOADED' : 'NOT_LOADED';" 2>$null
    if ($xdebugTest -match "LOADED") {
        Write-Host "[OK] Xdebug in CLI geladen" -ForegroundColor Green
    } else {
        Write-Warning "Xdebug nicht in CLI geladen"
    }
}

# Test-Dateien erstellen
$infoFile = "C:\xampp\htdocs\info.php"
if (-not (Test-Path $infoFile)) {
    "<?php phpinfo();" | Set-Content $infoFile
    Write-Host "  info.php erstellt" -ForegroundColor Gray
}

if (-not $skipXdebug) {
    $xdebugTestFile = "C:\xampp\htdocs\xdebug_test.php"
    $testContent = @'
<?php
if (extension_loaded('xdebug')) {
    echo "Xdebug Version: " . phpversion('xdebug') . "\n";
    echo "Mode: " . ini_get('xdebug.mode') . "\n";
    echo "Port: " . ini_get('xdebug.client_port') . "\n";
    echo "\nSTATUS: OK";
} else {
    echo "STATUS: ERROR - Xdebug not loaded";
}
'@
    $testContent | Set-Content $xdebugTestFile
}

if ($apacheStarted) {
    Start-Sleep -Seconds 1

    # Test über Apache
    try {
        $webTest = Invoke-WebRequest -Uri "http://localhost/info.php" -UseBasicParsing -TimeoutSec 5
        if ($webTest.StatusCode -eq 200) {
            Write-Host "[OK] Apache liefert PHP-Seiten aus" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Apache-Test fehlgeschlagen: $_"
    }

    if (-not $skipXdebug) {
        try {
            $xdTest = Invoke-WebRequest -Uri "http://localhost/xdebug_test.php" -UseBasicParsing -TimeoutSec 5
            if ($xdTest.Content -match "STATUS: OK") {
                Write-Host "[OK] Xdebug ueber Apache aktiv" -ForegroundColor Green
            } else {
                Write-Warning "Xdebug ueber Apache nicht aktiv"
            }
        } catch {
            Write-Warning "Xdebug-Test fehlgeschlagen"
        }
    }
}

# ========================================================================
# ABSCHLUSS
# ========================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "INSTALLATION ABGESCHLOSSEN!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PHP-Version: $phpVersionActual" -ForegroundColor Yellow

if (-not $skipXdebug) {
    $xdVer = & $phpExe -d xdebug.start_with_request=trigger -r "echo extension_loaded('xdebug') ? phpversion('xdebug') : 'Nicht geladen';" 2>$null
    Write-Host "Xdebug: $xdVer" -ForegroundColor Yellow
} else {
    Write-Host "Xdebug: Bereits installiert" -ForegroundColor Yellow
}

if (Test-Path "C:\xampp\php-backup") {
    Write-Host "Backup: C:\xampp\php-backup" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Tests:" -ForegroundColor Cyan
Write-Host "  http://localhost/info.php" -ForegroundColor White
if (-not $skipXdebug) {
    Write-Host "  http://localhost/xdebug_test.php" -ForegroundColor White
}
Write-Host ""
Write-Host "Logs:" -ForegroundColor Cyan
Write-Host "  Apache: C:\xampp\apache\logs\error.log" -ForegroundColor White
if (-not $skipXdebug) {
    Write-Host "  Xdebug: C:\xampp\php\logs\xdebug.log" -ForegroundColor White
}
Write-Host ""