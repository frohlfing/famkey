# 06 Setup

Dieses Dokument führt durch die Installation der Entwicklungsumgebung.

---

## 1. Technologie-Stack

### 1.1 Entwicklungsumgebung
- **Framework:** .NET MAUI (C#)
- **Pattern:** MVVM (Model-View-ViewModel), Dependency Injection (DI)
- **IDE:** JetBrains Rider ab 2025 (und PHPStorm ab 2025 für das Backend)
- **SDK:** .NET 8.0 LTS (Upgrade auf .NET 10 geplant)
- **Datenbank (Lokal):** SQLite 3
- **DB-Verschlüsselung:** SQLCipher
- **Android-Entwicklung:**
   - **JDK:** OpenJDK 17
   - **Android SDK:** API Level 34 (Android 14.0) erforderlich
   - **Emulator:** Pixel 5 (API 34) wird als Standard-Testgerät empfohlen
- **Testumgebung:** xUnit
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

## 2. Setup für .NET MAUI (C#) unter Windows

### 2.1 .NET 8.0 SDK installieren

Falls noch nicht geschehen, lade das aktuelle **.NET 8.0 SDK (LTS)** herunter und installiere es.

* Quelle: [Microsoft .NET Download](https://dotnet.microsoft.com/download/dotnet/8.0)

### 2.2 Workloads installieren

Rider nutzt die im Hintergrund installierten Workloads. Diese müssen wir einmalig manuell über die Kommandozeile (CMD
oder PowerShell als Administrator) nachziehen.

1. Öffne **PowerShell** (als Administrator).
2. Führe folgenden Befehl aus, um MAUI komplett zu installieren:
   ```powershell
   dotnet workload install maui
   ```
   *Das installiert die nötigen Pakete für Windows, Android und iOS.*

Nachdem `dotnet workload install maui` durchgelaufen ist, starte Rider neu.

### 2.3 Windows Developer Mode aktivieren

Damit du die App auf deinem eigenen Windows-PC testen/ausführen kannst, musst du Windows in den Entwicklermodus
schalten.

1. Windows-Einstellungen öffnen -> **System** -> **Für Entwickler**.
2. Schalter **"Entwicklermodus"** auf **Ein**.

### 2.4 Solution in Jetbrains Rider erstellen

1. **New Solution**:
2. Wähle links **.NET / .NET MAUI**.
3. Wähle die Einstellungen:
    - **Solution name:** PriVault
    - **Project name:** PriVault
    - **Solution directory:** C:\Users\frank\Source\Rider
    - **Put solution and project in same directory:** **Nein**
    - **Target Framework:** .NET 8.0
    - **Language:** C#
    - **Target platform:** MAUI
    - **Type:** App
4. Klicke **Create**.

### 2.5 Verwendete NuGet-Pakete (die Bibliotheken)
- `CommunityToolkit.Maui` 9.1.1: UI-Funktionen und die Erweiterung für `MauiProgram.cs`)
- `CommunityToolkit.Mvvm` 8.4.0: Logik für ViewModels
- `sqlite-net-sqlcipher` 1.9.172: Datenbank inkl. Verschlüsselung
- `Konscious.Security.Cryptography.Argon2` 1.3.1: Für das sichere Hashen des Master-Passworts
- `Plugin.Fingerprint` 2.1.5: Für den Zugriff auf FaceID und Fingerabdruck

```powershell
dotnet add package CommunityToolkit.Maui --version 9.1.1
dotnet add package CommunityToolkit.Mvvm
dotnet add package sqlite-net-sqlcipher
dotnet add package Konscious.Security.Cryptography.Argon2
dotnet add package Plugin.Fingerprint
```

### 2.6 Material Icons / FontAwesome
1. TTF-Datei herunterladen und nach Resources/Fonts/ kopieren
   - Material Symbol Icons (Outlined, Regular):
      - https://fonts.google.com/icons?icon.style=Outlined
   - FontAwesome:
      - https://fonts.google.com/icons
      - https://fontawesome.com/search?ic=free-collection
2. In MauiProgram.cs eintragen

### 2.7 SQLCipher‑fähigen JDBC‑Treiber für Rider

Der Treiber kann hier heruntergeladen werden:
https://github.com/Willena/sqlite-jdbc-crypt/releases/download/3.51.2.0/sqlite-jdbc-3.51.2.0.jar  
RIDERs Speicherort für JDBC: `C:\Users\frank\AppData\Roaming\JetBrains\Rider2025.3\jdbc-drivers\sqlite-jdbc`

Als Client-DB wird diese SQLite-Datei verwendet:
`jdbc:sqlite:/Users/frank/AppData/Local/Packages/com.companyname.privault_9zz4h110yvjzm/LocalState/test.db3`  
Master-Passwort: 4711

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

**JDBC-Treiber in RIDER einrichten:**

1. Database Tool Window öffnen und die heruntergeladene `sqlite-jdbc-3.51.2.0.jar` auswählen
   → Data Source → Driver, Add Driver
    - **Class:** org.sqlite.JDBC
    - **JDBC‑URL:** jdbc:sqlite:/Users/frank/AppData/Local/Packages/com.companyname.privault_9zz4h110yvjzm/LocalState/test.db3
    - **Advanced:**
        - cipher=sqlcipher
        - kdf_iter=256000
        - key=x'B7C438860DD01B07B311E7CA2C951F6A774488B494DD6C0C923A0C435EBA8CD6'
        - legacy=4
        - page_size=4096

---

## 3. Setup für Android-Apps unter Windows

### 3.1 Java und Android SDK installieren

Damit Rider Android-Apps bauen kann, brauchst du Java und das Android SDK. Rider hilft dir dabei meistens, aber manuell
ist es sauberer.

### 3.1 Java (JDK) installieren

MAUI benötigt **OpenJDK 11** oder neuer (Empfohlen: Microsoft OpenJDK 17).
Rider prüft das normalerweise beim Start. Falls es fehlt: Lade das [Microsoft Build of OpenJDK](https://learn.microsoft.com/en-us/java/openjdk/download) herunter.
[Direkter Download-Link](https://aka.ms/download-jdk/microsoft-jdk-17.0.18-windows-x64.msi)

### 3.2 Android SDK installieren

1. Öffne Rider
2. Gehe zu `File` -> `Settings` -> `Languages & Frameworks` -> `Android SDK`.
3. Wenn dort steht "Android SDK is missing", klicke auf **Edit** und lass Rider es in einen Standardordner (z.B.
   `C:\Users\DeinName\AppData\Local\Android\Sdk`) installieren.
4. Wähle im Reiter **SDK Platforms** mindestens **Android 14.0 (API 34)** aus.
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

Rider selbst verwaltet den Emulator nicht. Das macht der Android Studio Device Manager, der mit dem Android SDK installiert wird.
Beim ersten Build für Android als Zielsystem installiert Rider den Emulator automatisch.

- **Emulatoren starten/stoppen:** Rechte Toolbar → Device Manager
  - Erstelle ein neues Device (z.B. Pixel 5, API 34). 
- **Logcat (Logfiles):** Linke Toolbar -> Logcat

### 3.5 Troubleshooting

Rider nutzt das Tool ADB (Android Debug Bridge), um deine MAUI‑App auf den Emulator zu deployen.

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

### 3.7 Bekannte Bugs

- Bug in Rider: "Failed to upload application APK file to device"
  https://youtrack.jetbrains.com/issue/RIDER-132740/Failed-to-upload-application-APK-file-to-device

The issue is fixed and will be available in Rider 2025.3.3.
Early adopters can try the 2025.3 Nightly starting tomorrow (10.02.2026).

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

## 5. Testumgebung hinzufügen

### 5.1 Vorbereitung: Plattformunabhängigen Code in eine Class Library auslagern:
1. Class Library `Privault.Core` anlegen:
   1. Rechtsklick auf die Solution 'Privault' -> Add -> New Project.
   2. Wähle Class Library (Bibliothek).
   3. Name: `Privault.Core`.
   4. Framework: .NET 8.0.
2. `Privault.Core`/`Class1.cs` löschen
3. Rechtsklick auf `Privault` -> Add -> Reference -> Haken bei `Privault.Core` setzen.
4. Alles, was keine UI ist (also keine XAML-Dateien oder plattformspezifischen Code benötigt), von `Privault` nach `Privault.Core` verschieben.
   - Models/
   - Services/ (bis auf ConfigService.cs und GuardService.cs)
5. In `MauiProgram.cs` diese `using`-Statements hinzufügen:
   - `using Privault.Core.Services;`
   - `using Privault.Core.Services.Contracts;`
6. NuGet-Pakete installieren/deinstallieren 
   - In `Privault.Core` installieren:
      - `CommunityToolkit.Mvvm` 8.4.0
      - `sqlite-net-sqlcipher` 1.9.172
      - `Konscious.Security.Cryptography.Argon2` 1.3.1
      - `Plugin.Fingerprint` 2.1.5
      - `Microsoft.Extensions.Http` 10.0.2
      - `zxcvbn-core` 7.0.92 (misst die Passwortstärke basierend auf Wörterbüchern und Muster)
   - In `Privault` deinstallieren:
      - `Konscious.Security.Cryptography.Argon2`    
         Es verbleiben:
          - `CommunityToolkit.Maui` 9.1.1
          - `CommunityToolkit.Mvvm` 8.4.0
          - `Plugin.Fingerprint` 2.1.5
          - `sqlite-net-sqlcipher` 1.9.172
 
**Wichtig:** Das Projekt `Privault.Core` darf keine Referenzen auf `Microsoft.Maui` oder `CommunityToolkit.Maui` enthalten.

### 5.2 Projekt für die Tests anlegen
1. Neues Projekt `Privault.Tests` erstellen:
    1. Rechtsklick auf die Solution 'Privault' im Explorer.
    2. Add -> New Project.
    3. Wähle Unit-Test Project (Typ: xUnit), Target Framework: net8.0
    4. Name: `Privault.Tests`.
2. `Privault.Tests` / `UnitTest1.cs` löschen:
3. Rechtsklick auf `Privault.Tests` -> Add -> Reference -> Haken bei `Privault.Core` setzen.
4. NuGet-Pakete installieren:
    - `Moq` 4.20.72: Mocking-Framework für .NET

---

## 6. Troubleshooting
- Fehlermeldung: "additional components need to be installed"
  - Der .NET-Installer hat zwar die Basis (.NET SDK) installiert, aber nicht die spezifischen Pakete für Android und Windows UI (die sogenannten **Workloads**).
  - **Lösung: **
    ```powershell
    dotnet workload restore
    ```

- Fehlermeldung: "Warnung beim Build: Versions- oder verteilungsspezifische Laufzeitbezeichner gefunden: alpine-arm, alpine-arm64, alpine-x64. Betroffene Bibliotheken: SQLitePCLRaw.lib.e_sqlcipher."
  - **Lösung:**
    Paket für `Privault.Core` isntalliert:
    ```powershell
    dotnet add package SQLitePCLRaw.bundle_e_sqlcipher --version 2.1.11
    ```

- Fehlermeldung "Warnung beim Build: Dependency sqlite-net-sqlcipher 1.9.172 is vulnerable"
  - Das Paket ist verwundbar. Die gemeldete Schwachstelle ist CVE‑2022‑46908, ein Problem in SQLite 3.39.2. Behoben in SQLite 3.41.2.
  - Betrifft nur das SQLite‑Kommandozeilenprogramm. Anwendungen, die SQLCipher als Library nutzen (wie MAUI‑Apps), sind nicht betroffen.
  - **Lösung:**
    Betrifft nicht die App -> Warnung ignorieren (rechte Maustaste -> Ignore).

- Nach Update von RIDER 2025.3 auf 2026: Build für Android geht, aber Deploing nicht.
  Fehlermeldung: "Die Ressourcendatei "C:\Users\frank\Source\Rider\Privault\Privault\obj\project.assets.json" weist kein Ziel für "net8.0-android34.0" auf."
  - **Lösung: **
    ```powershell
    dotnet workload repair
    dotnet workload install maui
    dotnet workload install android
    dotnet workload restore
    ```
 
---

## 7. Ordnerstruktur
<pre>
/Privault/ (Solution)
  ├── bin/                          # Shell-Scripte
  ├── Docs/                         # Projektdokumentation (Markdown)
  ├── Host/                         # Backend (PHP)
  │    ├── coverage/                # Automatisch generierte Code-Coverage-Daten
  │    │    ├── clover.xml          # Clover-Report (XML) für IDE 
  │    │    └── data.json           # Coverage-Rohdaten
  │    ├── docs/                    # Serverdokumentation
  │    ├── logs/                    # Log-Protokolle
  │    ├── migrations/              # SQL-Skripte für Schema-Updates
  │    ├── public/                  # Web-Root (Ziel der Subdomain)
  │    │    ├── api/                # Webservice (.htaccess-Routing)
  │    │    │    ├── .htaccess      # Apache Rewrite-Regeln (Request an index.php weiterleiten)
  │    │    │    └── index.php      # Front-Controller
  │    │    ├── dev/                # Geschützter Bereich (Debug-/Admin-Skripte)
  │    │    │    ├── .htaccess      # Apache Zugriffsschutz
  │    │    │    ├── .htpasswd      # Apache Passwortdatei
  │    │    │    └── index.php      # Adminseite
  │    │    ├── .htaccess           # Apache Sicherheitsregeln
  │    │    └── index.html          # Startseite
  │    ├── src/                     # PHP-Quellcode (PSR-4-ähnlich)
  │    │    ├── Controller/         # Controller-Klassen
  │    │    ├── Core/               # Framework-Kern
  │    │    └── Middleware/         # Request/Response-Middleware
  │    ├── routes.php               # Zentrale Routenregistrierung
  │    ├── secrets.example.php      # Beispiel-Konfiguration (dient als Vorlage für config.php)
  │    ├── config.php               # Lokale Konfiguration mit Zugangsdaten/Secrets (nicht im Git-Repository)
  │    └── sqlca.pem                # CA-Zertifikat für TLS zur DB (z.B. Hetzner), s. https://docs.hetzner.com/de/konsoleh/account-management/databases/mysql/
  ├── Privault/                     # .NET MAUI App (C#)
  │    ├── Helpers/                 # UI-spezifische Hilfsklassen
  │    ├── Platforms/               # OS-spezifischer Code (Biometrie, Keystore)
  │    ├── Resources/               # Assets (Bilder, Fonts, Styles)
  │    │    └── Styles/             # Layout der Seiten 
  │    │         ├── Themes/        # Farben
  │    │         └── Styles.xaml    # Baupläne
  │    ├── Services                 # Plattformabhängige Business-Logik (z.B. ConfigService.cs)
  │    ├── Views/                   # XAML-Oberflächen
  │    ├── App.xaml                 # App-Root: globale Resources/Styles und Einstiegspunkt der MAUI-App
  │    ├── AppShell.xaml            # Shell-Navigation: Routen, Flyout/Tab-Struktur und Navigations-Container
  │    ├── MauiProgram.cs           # DI-Setup & App-Konfiguration: Services registrieren, Fonts/Toolkit, Plattform-Hooks
  │    └── Privault.csproj          # Projektdatei der MAUI-App: TargetFrameworks, Ressourcen, NuGet-Pakete, Build-Settings
  ├── Privault.Core/                # Class Library für die Kernlogik (Wichtig: UI‑frei und plattformunabhängig)
  │    ├── Models/                  # Datenstrukturen  
  │    │    ├── Dtos/               # Data Transfer Objecte für die Kommunikation mit der Web-API
  │    │    ├── Entities/           # SQLite-Tabellen
  │    │    ├── Payloads/           # Verschlüsselte Daten-Container
  │    │    └── Results/            # Interne Service-Rückgabewerte
  │    ├── Services/                # Business-Logik (plattformfrei)
  │    │    └── Contracts/          # Interfaces (auch die der plattformabhängigen Services)
  │    ├── ViewModels/              # UI-Logik (plattformfrei)
  │    ├── AppVersion.cs            # Stellt Versionsinformationen der Anwendung bereit.
  │    └── Privault.Core.csproj     # Projektdatei der Core-Library: Abhängigkeiten, Build-Settings (muss MAUI-frei bleiben)
  ├── Privault.Tests/               # Unit-Tests und Integrations-Tests
  │    ├── Services                 # Tests für Services
  │    ├── ViewModels               # Tests für ViewModels
  │    ├── AppVersionTestscs        # Test für AppVersion
  │    └── Privault.Tests.csproj    # Testprojektdatei: xUnit/Moq/Test SDK, Referenzen auf Privault.Core
  ├── Privault.Web                  # Blazor WebAssembly (Blazor WASM)
  │    ├── Pages                    # Webseiten
  │    ├── Components               # Komponenten
  │    └── Services                 # UI-Logik
  ├── .gitignore                    # Vom Git-Repository auszuschließende Dateien
  ├── global.json                   # Pinnt die verwendete .NET SDK-Version für reproduzierbare Builds (CI/Dev-Setup)
  ├── LICENSE                       # Lizenzhinweis   
  ├── Privault.sln                  # Solution-Datei
  └── README.md                     # Landingpage für das Git-Repository   
</pre>

---

## 8. Konfiguration / Preferences

Die Speicherorte hängen vom Betriebssystem ab, da .NET MAUI die nativen Mechanismen nutzt.

### 8.1 Unter Windows (Entwicklungsumgebung)
- Basisverzeichnis: `%AppData%\Local\Packages\[Package_GUID]`
   - `%AppData%`: C:\Users\DEIN_NAME\AppData\
   - `[Package_GUID]`: Suche in `%LOCALAPPDATA%\Packages` nach "privault" (beginnt meist mit dem Package-Namen, z.B. `com.companyname.privault_...` )
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
- **`version`**: Repräsentiert die Schema-Version der lokalen SQLite-Datenbank (Singleton-Speicher).

### 9.2 Tabellen auf dem Server (MySQL)
- **`vaults`**: Enthält die Tresornamen.
- **`users`**: Speichert Benutzernamen-Hashes, `Salts`, `Public-Keys` und den verschlüsselten `Private-Key`.
- **`entries`**: Speichert die verschlüsselten Einträge.
- **`permissions`**: Enthält die verschlüsselten `Entry-Keys`. Speichert, welcher Benutzer auf welchen Eintrag zugreifen kann.
- **`tombstones`**: Protokolliert gelöschte Einträge, damit Clients diese beim Pull-Sync entfernen können.
- **`attachments`**: Speichert die verschlüsselten Dateianhänge.
- **`version`**: Repräsentiert die API-Version. Wird erhöht, wenn ein Endpunkt oder das Datenbankschema geändert wird (Singleton-Speicher).

---

## 10 Biometrie-Unterstützung

### 10.1 Android:
1. Initialisierung in `Platforms/Android/MainActivity.cs`:
    ```csharp
    // ...
    using Plugin.Fingerprint;
    // ...
    public class MainActivity : MauiAppCompatActivity
    {
        protected override void OnCreate(Bundle? savedInstanceState)
        {
            base.OnCreate(savedInstanceState);
            // Dem Fingerprint-Plugin sagen, dass diese Activity für Dialoge genutzt werden soll
            CrossFingerprint.SetCurrentActivityResolver(() => this);
        }
    }
    ```
2. Berechtigung in `Platforms/Android/AndroidManifest.xml` innerhalb des `<manifest>`-Tags setzen:
    ```xml
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="android.permission.USE_FINGERPRINT" />
    ```

### 10.2 iOS
1. `Platforms/iOS/Info.plist` (und falls vorhanden `Platforms/MacCatalyst/Info.plist`) diesen Key hinzufügen:

```xml
<key>NSFaceIDUsageDescription</key>
<string>PriVault benötigt FaceID, um deinen Tresor sicher zu entschlüsseln.</string>
```
### 10.3 Windows
Keine Einrichtung notwendig.

---

## 11. Autofill-Service einrichten

Was ist mit iOS und Windows?

1. **iOS:** Du brauchst **keinen Code** unter `Platforms/iOS`. iOS macht das über "AutoFill" von Haus aus. Du musst lediglich in deiner `Info.plist` das Entitlement `com.apple.developer.associated-domains` aktivieren und dort deine Server-Domain eintragen (`webcredentials:dein-server.de`). iOS gleicht dann die Domain der Website im Safari mit den URLs in deinem Tresor ab.
2. **Windows:** Windows hat kein systemweites Autofill für Drittanbieter-Apps. Dort wird PriVault als normale App genutzt, und der Benutzer nutzt "Copy & Paste". Die Integration erfolgt dort eher über Browser-Erweiterungen (Edge/Chrome Store), was jedoch ein komplett anderes Projekt (JavaScript/HTML) wäre.
3. **Android:** Android hat einen eigenen Autofill-Service. Folgende Dateien habe ich hinzugefügt bzw. erweitert:
- `Platforms/Android/PrivaultAutofillService.cs` (neu) - Dieser Dienst fungiert als Brücke zwischen dem Android-System und deiner `Privault.Core`-Logik.
- `Platforms/Android/AndroidManifest.xml` (erweitert)
- `Platforms/Android/Resources/xml/autofill_service_config.xml` (neu)

**TODOS:**
- Der Autofill-Service darf aus Sicherheitsgründen oft keine komplexe UI anzeigen. 
- Wenn der Tresor gesperrt ist, musst du eine `IntentSender`-Operation zurückgeben, die deine App kurz im Vordergrund öffnet ("Biometrie-Check"), und dann das Passwort zurück an die ursprüngliche App liefert.
- Unter Einstellungen -> System -> Sprachen & Eingabe -> Autofill-Dienst (Pfad variiert je nach Android-Version) kann "PriVault" als Autofill-Dienst ausgewählt werden.
- Die `ParseStructure`-Logik (das Finden der Felder) muss vertieft werden.

--- 

## 12. Upgrade von .NET 8 auf .NET 10

**Hinweise zu den .NET-Versionen:**

* .NET 8.0:
    * LTS (Long-Term Support) bis November 2026.
    * Extrem stabil und alle NuGet-Pakete, die wir brauchen, laufen garantiert darauf.
* .NET 9.0:
    * STS (Standard-Term Support), Support nur bis Mai 2025 – kein Langzeit-Support!
* .NET 10.0:
    * Noch sehr frisch (Release November 2025).
    * Wird wieder ein LTS-Release sein, also langfristig unterstützt bis 2028.
    * Es könnte sein, dass manche Drittanbieter-Bibliotheken noch Updates brauchen.
    * Allerdings: Tooling (MAUI, Rider, SDKs, Emulatoren) ist oft noch nicht komplett stabil oder angepasst.

1. `global.json` anpassen:

   Da diese Datei aktuell dein Projekt auf Version 8 "festnagelt", musst du sie öffnen und die Version ändern.

    * **Alt:** `"version": "8.0.xxx"`
    * **Neu:** `"version": "10.0.100"` (oder welche 10er-Version du dann installiert hast).

   *Alternativ:* Du kannst die Datei einfach löschen, dann nimmt Rider automatisch die neueste installierte Version (was
   dann .NET 10 sein sollte).

2. Projektdatei (`.csproj`) ändern:

   Öffne die Datei `Privault.csproj` (du kannst in Rider einfach auf das Projekt doppelklicken oder Rechtsklick -> Edit).

   Suche nach dem Tag `<TargetFrameworks>`.
   Du musst dort einfach alle `net8.0` durch `net10.0` ersetzen:
   ```xml
   <TargetFrameworks>net10.0-android;net10.0-ios;net10.0-maccatalyst</TargetFrameworks>
   <TargetFrameworks Condition="$([MSBuild]::IsOSPlatform('windows'))">$(TargetFrameworks);net10.0-windows10.0.19041.0
   </TargetFrameworks>
   ```

3. NuGet Pakete aktualisieren:
    * Das aktualisiert das Toolkit auf Version 13.x+ (die .NET 10 braucht)
      `dotnet add package CommunityToolkit.Maui`
    * Die anderen auch gleich mitziehen (optional, aber empfohlen)
      `dotnet add package CommunityToolkit.Mvvm`
      `dotnet add package sqlite-net-sqlcipher`

4. Aufräumen (Clean & Rebuild)
    * Lösche manuell die Ordner `bin` und `obj` in deinem Projektverzeichnis.
    * Starte Rider neu.
    * Führe **Rebuild Solution** aus.