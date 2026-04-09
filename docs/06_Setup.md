# 06 Setup

Dieses Dokument führt durch die Installation der Entwicklungsumgebung.

---

## 1. Technologie-Stack

### 1.1 Entwicklungsumgebung

- **Framework:** Flutter (dart) mit Riverpod, drift für Datenbank
- **IDE:** Android Studio ab 2025 (und PHPStorm ab 2025 für das Backend)
- **Datenbank (Lokal):** SQLite 3
- **DB-Verschlüsselung:** SQLCipher
- **SDK:** Flutter SDK (beinhaltet das Dart SDK), die jeweils neueste stabile Version wird empfohlen.
- **Android-Entwicklung:**
  - JDK: OpenJDK 17 (wird von Flutter für Android-Builds benötigt).
  - Android SDK: API-Level 34 (Android 14.0) als compileSdkVersion und targetSdkVersion.
  - Emulator: Pixel 5 (API 34) wird als Standard-Testgerät empfohlen.
- **Testumgebung:** Das integrierte Dart/Flutter Test-Framework:
  - Unit-Tests: package:test
  - Widget-Tests: package:flutter_test
- **Lokaler Test-Server**:** Laragon mit Xdebug, PHP 8.4 oder aktueller
- **VCS:** Git, Repository auf GitHub

### 1.2 Server (Backend)

- **Host:** Hetzner Webspace
- **Sprache:** PHP 8.4 oder aktueller
- **Datenbank:** MySQL 8.4.3 / MariaDB (Table Type: InnoDB)
- **DB Charset:** UTF-8 Unicode (utf8mb4_unicode_ci)
- **API:** JSON REST über HTTPS
- **SSL:** Let's Encrypt Zertifikats

### 1.3 Kryptografie

- Hashing: Argon2id
- Symmetrisch: AES-256-GCM (`System.Security.Cryptography`)
- Asymmetrisch: RSA-4096 (`System.Security.Cryptography`)

---

## 2. Setup für Flutter (dart) unter Windows

### 2.1 Flutter SDK installieren

Falls noch nicht geschehen, installiere das Flutter SDK. Es beinhaltet auch das notwendige Dart SDK.
1. Lade das aktuelle Flutter SDK (Stable Channel) von der offiziellen Webseite herunter
2. Entpacke die ZIP-Datei in einen permanenten Ordner, z.B. `C:\flutter`.
3. Füge das bin-Verzeichnis des Flutter SDK zu deinem Path in den Windows-Umgebungsvariablen hinzu (z.B. `C:\flutter\bin`).

### 2.2 Flutter-Installation prüfen

Flutter bietet ein Kommandozeilen-Tool, um deine Entwicklungsumgebung zu überprüfen.
1. Öffne eine neue PowerShell oder CMD.
2. Führe folgenden Befehl aus, um zu sehen, ob alle Komponenten korrekt eingerichtet sind:
  ```shell
  flutter doctor
  ```
`flutter doctor` zeigt dir an, ob Android Studio, das Android SDK oder andere benötigte Tools fehlen oder konfiguriert werden müssen.

### 2.3 Windows Developer Mode aktivieren

Damit du die App auf deinem eigenen Windows-PC testen/ausführen kannst, musst du Windows in den Entwicklermodus
schalten.
1. Windows-Einstellungen öffnen -> **System** -> **Für Entwickler**.
2. Schalter **"Entwicklermodus"** auf **Ein**.

### 2.4 Projekt in Android Studio öffnen

1. Starte Android Studio.
2. Wähle "Open an Existing Project".
3. Navigiere zum Root-Verzeichnis deines Projekts (z.B. `C:/Users/frank/Source/AndroidStudio/privault`) und öffne es.
4. Android Studio erkennt das Flutter-Projekt und fragt eventuell, ob du die Dart- und Flutter-Plugins installieren möchtest. Bestätige dies.

### 2.5 Verwendete Abhängigkeiten (die Dart/Flutter-Pakete)

Alle Abhängigkeiten werden in der Datei pubspec.yaml im Projektstamm verwaltet.
- `flutter_riverpod`: State-Management
- `sqflite_sqlcipher`: Datenbank inkl. Verschlüsselung
- `argon2_ffi`: Für das sichere Hashen des Master-Passworts
- `local_auth`: Für den Zugriff auf FaceID und Fingerabdruck

Du fügst sie über die Kommandozeile hinzu:
```shell
flutter pub add flutter_riverpod
flutter pub add sqflite_sqlcipher
flutter pub add argon2_ffi
flutter pub add local_auth
```
Anschließend wird automatisch ein `flutter pub get` ausgeführt, um die Pakete herunterzuladen.

### 2.6 SQLCipher-DLL für Windows

SQLCipher (basiert auf SQLite 3.51.2) wird benötigt, um unter Windows die SQLite-DB verschlüsseln zu können.

- Download: https://github.com/utelle/SQLite3MultipleCiphers/releases/tag/v2.2.7 (`sqlite3mc-2.2.7-sqlite-3.51.2-win64.zip`)
- `sqlite3mc_x64.dll` aus dem Archiv nach `C:\Users\frank\Source\AndroidStudio\privault\` kopieren

### 2.7 Datenbank-Tool für Android Studio

Database Navigator 3.7.2.0 von Oracle 
https://docs.oracle.com/en/database/oracle/database-navigator/3.7/dbnug/introduction-oracle-database-navigator.html

Ein SQLCipher‑fähiger JDBC‑Treiber kann hier heruntergeladen werden:
https://github.com/Willena/sqlite-jdbc-crypt/releases/download/3.51.2.0/sqlite-jdbc-3.51.2.0.jar
Speicherort: C:\Users\frank\Source\AndroidStudio\privault\drivers\sqlite-jdbc-3.51.2.0.jar 

Als Client-DB wird diese SQLite-Datei verwendet:
`jdbc:sqlite:/Users/frank/AppData/Roaming/de.frohlfing.privault/privault/vaults/test1.db3`  
- Master-Passwort: 4711
- Parameter für Database Navigator:
  ```ini
  cipher=sqlcipher
  hexkey_mode=SSE
  key=65e4917e2035121562eba4b67827e3b5e21a6d10c01000d8354ae3c64f447f22
  ```
- oder per JDBC-URL mit Query-Parametern
  `/Users/frank/AppData/Roaming/de.frohlfing.privault/privault/vaults/test1.db3?cipher=sqlcipher&hexkey_mode=SSE&key=65e4917e2035121562eba4b67827e3b5e21a6d10c01000d8354ae3c64f447f22`
  
Die Eigenschaft `hexkey_mode` kann folgende Werte haben:
- `NONE`: Text-basiertes Passwort (Standard)
- `SSE`: SQLite3 Multiple Ciphers mit Hex-Schlüssel (nutzt `PRAGMA hexkey`)
- `SQLCIPHER`: SQLCipher-Modus (nutzt `PRAGMA key = "x'..'"`)

Für die Verbindung per JDBC wird der Hex-Code des Master-Keys benötigt. So kann er ermittelt werden:
```csharp
    // Den Master-Key aus eingegebenes Master-Passwort (4711) und Salt per Argon2id ableiten
    var saltBase64 = _configService.Vaults[VaultName]; 
    var salt = Convert.FromBase64String(saltBase64);
    masterKey = await _cryptoService.DeriveKeyAsync(Password, salt);
    
    // Hex-Code des Master-Keys ausgeben
    var keyHex = Convert.ToHexString(masterKey); 
    System.Diagnostics.Debug.WriteLine("MASTER KEY (HEX): " + keyHex);
```

## 3. Setup für Android-Apps unter Windows

Flutter nutzt das native Android SDK. Die Einrichtung ist daher fast identisch.

### 3.1 Java (JDK) installieren

Flutter benötigt **OpenJDK 11** oder neuer. Android Studio bringt in der Regel eine passende Version mit. 
Falls nicht, kannst du sie hier herunterladen: [Microsoft Build of OpenJDK](https://learn.microsoft.com/en-us/java/openjdk/download).
[Direkter Download-Link](https://aka.ms/download-jdk/microsoft-jdk-17.0.18-windows-x64.msi)

### 3.2 Android SDK installieren

1. Öffne Android Studio.
2. Gehe zu `Tools` -> `SDK Manager`.
3. Wähle im Reiter **SDK Platforms** mindestens **Android 14.0 (API 34)** aus.
5. Wähle im Reiter **SDK Tools** folgende Haken:
    * `Android SDK Build-Tools`
    * `Android SDK Platform-Tools`
    * `Android Emulator`
    * `Android SDK Command-line Tools`

### 3.3 Hyper‑V aktivieren

Für schnelle Emulatoren wird "Hyper‑V" empfohlen, alternativ "Windows Hypervisor Platform".
So aktivierst du Hyper‑V:
1. Windows-Taste → „Windows-Features aktivieren oder deaktivieren“
2. Haken setzen bei:
    - Hyper‑V (nicht gefunden)
    - Windows Hypervisor Platform (gefunden!)
    - Virtual Machine Platform (optional, hab ich nicht gefunden)
3. Neustarten
  
### 3.4 Android-Emulator einrichten

1. In Android Studio: Gehe zu `Tools` -> `Device Manager`.
2. Erstelle ein neues virtuelles Gerät (z.B. "Pixel 5, API 34").
3. Du kannst den Emulator direkt aus dem Device Manager oder über die Toolbar in Android Studio starten.
4. **Logcat (Logfiles):** Öffne den Logcat-Tab am unteren Rand von Android Studio.

### 3.5 Troubleshooting

Android Studio und Flutter nutzen das Tool ADB (Android Debug Bridge), um deine‑App auf den Emulator zu deployen.

Es liegt hier: `C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe`
Das CLI-Tool kann dies:
- Emulatoren und echte Geräte verbinden
- APKs installieren und entfernen
- Logs liefern (Logcat, Linke Toolbar -> Logcat)

- Server neustarten:
  ```bash
  .\adb.exe kill-server
  .\adb.exe start-server
  ```

- Prüfen, ob der Emulator überhaupt erreichbar ist
  ```shell
  cd C:\Users\frank\AppData\Local\Android\Sdk\platform-tools                                                        
  .\adb.exe devices
  ```
    - Erwartete Ausgabe:
      ```shell
        List of devices attached
        emulator-5554   device
      ```

- APK auf Emulator deployen (siehe `/Privault/bin/deploy-privault.ps1`):
  ```shell
  C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe uninstall com.companyname.privault | Out-Null
  C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r C:\Users\frank\Source\Rider\Privault\Privault\bin\Debug\net8.0-android\android-x64\com.companyname.privault-Signed.apk
  ```

### 3.6 Auf einem physischen Gerät (Samsung Galaxy S25) testen

1) Am PC: Treiber `SAMSUNG_USB_Driver_for_Mobile_Phones_v1.9.0.0.exe` installieren
   - https://developer.samsung.com/android-usb-driver  
   - Installieren und PC neu starten

2) Am Smartphone: Entwickleroptionen auf dem Handy aktivieren
   - Einstellungen / Telefoninfo / Softwareinformationen  
   - Build‑Nummer 7× antippen  
   - "Entwicklermodus aktiviert" erscheint  

3) Handy per USB‑Datenkabel verbinden

4) Am Smartphone: USB‑Debugging aktivieren
   // nicht mehr notwendig
   // - Benachrichtigungsleiste runterziehen und auf die USB‑Benachrichtigung tippen
   //    - USB‑Optionen: "Übertragen von Dateien / Android Auto" auswählen
   //    - USB gesteuert von: "Verbundenes Gerät" (ändert sich automatisch)
   - Einstellungen / Sicherheit und Datenschutz / Auto-Sperre.
       - Deaktivieren (zumindest während der Entwicklung).
   - Einstellungen / Entwickleroptionen
       - USB‑Debugging aktivieren
  
5) Am PC: Prüfen, ob dein PC das Gerät sieht
   C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe devices
   <device-id>    device

6) In Rider: "Samsung Galaxy S25" als Target Device auswählen
   Run → Edit Configurations → Target Device

---

## 4. Setup für das Backend (PHP) unter Windows

Für die Entwicklung unter Windows dient **Laragon** als Server.

### 4.1 Lokalen Webserver einrichten

1. [Laragon](https://laragon.org/download) installieren.

2. Laragon konfigurieren:
   (Menü ist über rechte Maustaste erreichbar)
    * Menü -> Tools -> Quick add -> PHP 8.4
    * Menü -> PHP -> PHP 8.4.12
    * Menü -> Tools -> Quick add -> myPHPAdmin-6.0.snapshot
    * Dienste starten.
    * Schloss neben Apache anklicken, um SSL zu aktivieren.

### 4.2 VirtualHost hinzufügen

1. Neue Webseite erstellen -> Blank (Name: privault)
2. Apache -> sites-enabeled -> auto.privault.test.conf
   `define ROOT "C:/Users/frank/Source/Rider/Privault/Host/public"`
3. Apache neu starten

Webseite ist jetzt erreichbar unter: https://privault.test/

### 4.3 Datenbank anlegen

1. phpMyAdmin starten:
   https://localhost/phpmyadmin6/public/ (User: root, kein Passwort)
2. Datenbank hinzufügen
    * Database Name: privault
    * Server connection collation: utf8mb4_unicode_ci
3. SQL-Datei Host/migrations/001_initial_schema.sql importieren

### 4.4 Xdebug installieren

1. PHP-Info ausgeben: <?php phpinfo(); ?>
2. [Xdebug Wizard](https://xdebug.org/wizard) ausführen und ermittelte DLL nach `C:\laragon\bin\php\php_xdebug.dll` kopieren.
3. C:\laragon\bin\php\php-8.4.12-nts-Win32-vs17-x64\php.ini ergänzen um diesen Abschnitt:
   ```ini
   [Xdebug]
   zend_extension = xdebug
   xdebug.mode = debug,develop,coverage
   xdebug.start_with_request = yes
   xdebug.client_port = 9003
   xdebug.log = "C:/laragon/tmp/xdebug.log"
   ```
4. Apache neu starten
5. Im Browser Xdebug-Erweiterung installieren

### 4.5 WinSCP installieren

Wird für den Dateitransfer via FTP/SFTP auf das Produktivsystem benötigt.
Alternativ kann auch ein Git-Deployment eingerichtet werden.

---

## 6. Troubleshooting

- Fehlermeldung "Warnung beim Build: Dependency sqlite-net-sqlcipher 1.9.172 is vulnerable"
  - Das Paket ist verwundbar. Die gemeldete Schwachstelle ist CVE‑2022‑46908, ein Problem in SQLite 3.39.2. Behoben in SQLite 3.41.2.
  - Betrifft nur das SQLite‑Kommandozeilenprogramm. Anwendungen, die SQLCipher als Library nutzen (wie Flutter‑Apps), sind nicht betroffen.
  - **Lösung:**
    Betrifft nicht die App -> Warnung ignorieren (rechte Maustaste -> Ignore).

---

## 7. Ordnerstruktur
<pre>
privault/                                      # Projekt-Root (Monorepo)
 ├── apps/                                     # Enthält alle eigenständigen Flutter-Apps (Feature‑First)
 │    ├── privault/                            # Die eigentliche PriVault-App (Android/iOS/Windows/Web)
 │    │    ├── android/                        # Android-spezifische Dateien (Gradle, Manifest, Ressourcen)
 │    │    ├── lib/                            # App-spezifischer Flutter-Code
 │    │    │    ├── features/                  # Feature-Module (Screens + ViewModels + Widgets)
 │    │    │    │    ├── main/                 # Hauptseite 
 │    │    │    │    │    ├── main_screen.dart
 │    │    │    │    │    ├── main_viewmodel.dart
 │    │    │    │    │    └── widgets/
 │    │    │    │    ├── login/                # Loginseite
 │    │    │    │    ├── detail/               # Detailansicht
 │    │    │    │    ├── edit/                 # Editierseite
 │    │    │    │    └── settings/             # Setupseite
 │    │    │    ├── app.dart                   # App-Setup (Theme, Routing, Provider-Setup)
 │    │    │    └── main.dart                  # Einstiegspunkt der App
 │    │    ├── test/                           # Widget- und Unit-Tests der App
 │    │    ├── web/                            # Web-spezifische Dateien
 │    │    ├── windows/                        # Windows-spezifische Runner + CMake
 │    │    ├── pubspec.yaml                    # Dependencies der priVault-App
 │    │    └── .metadata                       # Flutter-Projekt-Metadaten
 │    │                                        
 │    └── admin/                               # Admin-App für Windows (in Planung)
 │         ├── lib/                            # Admin-spezifischer Flutter-Code
 │         │    ├── features/                  # Eigene Screens + ViewModels
 │         │    └── main.dart                  # Einstiegspunkt der Admin-App
 │         ├── windows/                        # Windows-spezifischer Runner
 │         ├── pubspec.yaml                    # Dependencies der Admin-App
 │         └── test/                            
 │                                             
 ├── docs/                                     # Projektdokumentation (Markdown)
 │
 ├── host/                                     # Backend (PHP)
 │    ├── coverage/                            # Automatisch generierte Code-Coverage-Daten
 │    │    ├── clover.xml                      # Clover-Report (XML) für IDE 
 │    │    └── data.json                       # Coverage-Rohdaten
 │    ├── docs/                                # Serverdokumentation
 │    ├── logs/                                # Log-Protokolle
 │    ├── migrations/                          # SQL-Skripte für Schema-Updates
 │    ├── public/                              # Web-Root (Ziel der Subdomain)
 │    │    ├── api/                            # Webservice (.htaccess-Routing)
 │    │    │    ├── .htaccess                  # Apache Rewrite-Regeln (Request an index.php weiterleiten)
 │    │    │    └── index.php                  # Front-Controller
 │    │    ├── dev/                            # Geschützter Bereich (Debug-/Admin-Skripte)
 │    │    │    ├── .htaccess                  # Apache Zugriffsschutz
 │    │    │    ├── .htpasswd                  # Apache Passwortdatei
 │    │    │    └── index.php                  # Adminseite
 │    │    ├── .htaccess                       # Apache Sicherheitsregeln
 │    │    └── index.html                      # Startseite
 │    ├── src/                                 # PHP-Quellcode (PSR-4-ähnlich)
 │    │    ├── Controller/                     # Controller-Klassen
 │    │    ├── Core/                           # Framework-Kern
 │    │    └── Middleware/                     # Request/Response-Middleware
 │    ├── routes.php                           # Zentrale Routenregistrierung
 │    ├── secrets.example.php                  # Beispiel-Konfiguration (dient als Vorlage für config.php)
 │    ├── config.php                           # Lokale Konfiguration mit Zugangsdaten/Secrets (nicht im Git-Repository)
 │    └── sqlca.pem                            # CA-Zertifikat für TLS zur DB (z.B. Hetzner), s. https://docs.hetzner.com/de/konsoleh/account-management/databases/mysql/
 │
 ├── native/                                   # Native Bibliotheken (z.B. SQLite3MC)
 │    └── sqlcipher/                           # SQLCipher (SQLite mit Verschlüsselungsfunktion)
 │         └── windows/
 │              ├── sqlite3mc_x64.dll          # SQLite3 Multiple Ciphers 2.2.7 (basiert auf SQLite 3.51.2) 
 │              └── sqlite-jdbc-3.51.2.0.jar   # SQLCipher‑fähiger JDBC‑Treiber (für Database Navigator)
 │
 ├── packages/                                 # Wiederverwendbare, plattformunabhängigen Flutter-/Dart-Pakete (Layer‑First)
 │    ├── core/                                # Basis-Funktionalität (UI-unabhängig)
 │    │    ├── lib/
 │    │    │    ├── app_version.dart           # Versionierung
 │    │    │    ├── base_view_model.dart       # Abstrakte ViewModel-Basis
 │    │    │    ├── service_locator.dart       # DI/Service-Locator
 │    │    │    └── core.dart                  # Barrel-File (optional)
 │    │    └── pubspec.yaml
 │    │
 │    ├── domain/                              # Datenmodelle (Entities, DTOs, Payloads, Exceptions)
 │    │    ├── lib/
 │    │    │    └── models/
 │    │    │         ├── dtos/
 │    │    │         ├── entities/
 │    │    │         ├── exceptions/
 │    │    │         └── payloads/
 │    │    └── pubspec.yaml
 │    │
 │    └── data/                                # Datenzugriff, DB, Repositories, Services
 │         ├── lib/
 │         │    ├── database/                  # SQLite3MC-Integration, DB-Adapter
 │         │    ├── services/                  # DB-Service, Sync-Service, Session-Service
 │         │    └── data.dart                  # Barrel-File (optional)
 │         └── pubspec.yaml
 │
 ├─ .analysis_options.yaml                     # Zentrale Linting-/Analyzer-Regeln für alle Apps/Packages
 ├─ .gitignore                                 # Vom Git-Repository auszuschließende Dateien
 ├─ .analysis_options.yaml                     # Konfiguration für den Analysator
 ├─ LICENSE                                    # Lizenzhinweis   
 ├─ pubspec.yaml                               # Paketinformation
 └─ README.md                                  # Landingpage für das Git-Repository
</pre>

---

## 8. Konfiguration / Preferences

Die Speicherorte hängen vom Betriebssystem ab, da Flutter die nativen Mechanismen nutzt.

### 8.1 Unter Windows (Entwicklungsumgebung)
- Basisverzeichnis: `%AppData%\Roaming\[Package]\privault`
 C:\Users\frank\AppData\Roaming\de.frohlfing.privault\privault\vaults
   - `%AppData%`: Z.B. `C:\Users\frank\AppData`
   - `[Package]`: Z.B. `de.frohlfing.privault`
- SQLite-Datei: `.\LocalState\Trresorname.db3`
- Konfiguration: `.\Settings\settings.dat`

**Wie man sie am schnellsten löscht (Empfohlen):**
Du musst nicht in den Dateien wühlen. Windows hat eine eingebaute Funktion dafür:
1.  Drücke `Windows-Taste`.
2.  Tippe den Namen deiner App (`Privault`).
3.  Rechtsklick auf das App-Icon -> **App-Einstellungen** (App settings).
4.  Scrolle runter und klicke auf den Button **Zurücksetzen** (Reset).
*   *Das löscht Preferences UND die lokale Datenbank.*

### 8.2 Unter Android (Emulator / Gerät)
Die Preferences liegen in einer XML-Datei im geschützten Speicher (SharedPreferences).
- Basisverzeichnis: `/data/data/com.companyname.privault/shared_prefs/com.companyname.privault.xml`

**Wie man sie löscht:**
1.  Im Emulator/Handy lange auf das App-Icon drücken.
2.  Auf das **(i)** (App Info) tippen.
3.  Gehe zu **Speicher & Cache** (Storage).
4.  Tippe auf **Speicherinhalt löschen** (Clear Storage / Clear Data).

### 8.3 Backend
Die Konfiguration wird in `config.php` gespeichert. Diese Datei darf nicht ins VCS eingecheckt werden!

---

## 9. Datenbankschema

- Das Schema nutzt UUIDs (v4) zur Identifikation von Objekten, um Konflikte beim Sync zwischen mehreren Geräten zu vermeiden.
- Der Server ist mandantenfähig (Multi-Tenant). Jeder Datensatz ist einer `vault_id` zugeordnet.

### 9.1 Tabellen auf dem Client (SQLite)
- **`settings`**: Enthält die privaten Schlüssel des Benutzers und die Konfigurationseinstellungen des Tresors (Singleton-Speicher).
- **`users`**: Speichert die öffentlichen Daten des Benutzers und dessen Freunde (inkl. unverschlüsselten Namen).
- **`entries`**: Speichert die verschlüsselten Einträge.
- **`permissions`**: Enthält die verschlüsselten `Entry-Keys`. Speichert, welcher Benutzer auf welchen Eintrag zugreifen kann.
- **`tombstones`**: Protokolliert gelöschte Einträge, damit Clients diese beim Pull-Sync entfernen können.
- **`attachments`**: Speichert die verschlüsselten Dateianhänge.

### 9.2 Tabellen auf dem Server (MySQL)
- **`vaults`**: Enthält die Tresornamen.
- **`users`**: Speichert Benutzernamen-Hashes, `Salts`, `Public-Keys` und den verschlüsselten `Private-Key`.
- **`entries`**: Speichert die verschlüsselten Einträge.
- **`permissions`**: Enthält die verschlüsselten `Entry-Keys`. Speichert, welcher Benutzer auf welchen Eintrag zugreifen kann.
- **`tombstones`**: Protokolliert gelöschte Einträge, damit Clients diese beim Pull-Sync entfernen können.
- **`attachments`**: Speichert die verschlüsselten Dateianhänge.
- **`version`**: Repräsentiert die Schema-Version.

---