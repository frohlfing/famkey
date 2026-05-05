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
  - Android SDK: API-Level 36 als compileSdk (Gradle-Override, siehe Abschnitt 3.7); targetSdk wird vom Flutter SDK gesteuert.
  - Kotlin: 2.3.0, Android Gradle Plugin (AGP): 8.13.1 (siehe Abschnitt 3.7).
  - Emulator: Pixel 5 (API 34) wird als Standard-Testgerät empfohlen.
- **Testumgebung:** Das integrierte Dart/Flutter Test-Framework:
  - Unit-Tests: package:test
  - Widget-Tests: package:flutter_test
- **Lokaler Test-Server**:** XAMPP mit Xdebug, PHP 8.4 oder aktueller
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

## 2. Setup der IDE unter Windows 

### 2.1 Android Studio mit Flutter (inkl. dart) einrichten

1. Android Studio installieren
   https://developer.android.com/studio?hl=de

2. Flutter SDK installieren
   https://docs.flutter.dev/install/manual
   c:\flutter gespeichert

3. bin-Ordner des Flutter-SDK-Verzeichnisses zur Umgebungsvariable Path hinzufügen:
   Press Windows + Pause/Break → Advanced System Settings → Environment Variables.
   Edit PATH Variable
   Under User variables, select Path → Edit → New.
   Add the path to the bin folder

4. Android Studio öffnen
5. Flutter-Plugin installieren
6. Android Studio neustarten

### 2.2 Windows Developer Mode aktivieren

Damit du die App auf deinem eigenen Windows-PC testen/ausführen kannst, musst du Windows in den Entwicklermodus
schalten.
1. Windows-Einstellungen öffnen -> **System** -> **Für Entwickler**.
2. Schalter **"Entwicklermodus"** auf **Ein**.

### 2.3 Neues Projekt in Android Studio anlegen

- New Flutter Project auswählen
    - Flutter-Pojekt
    - Projektname: `FamKey` (muss snake_case sein!)
    - Ordner: `C:\Users\frank\Source\AndroidStudio\FamKey`
    - Organization: `de.frohlfing.famkey` (Umgekehrte Domain!)
      Wichtig! Dies wird zum eindeutigen Package-Namen für Android und zur Bundle-ID für iOS.
      Der Standardwert `com.example` darf nicht für die Veröffentlichung verwendet werden.
    - Android language: `Kotlin`

### 2.4 Verwendete Abhängigkeiten (die Dart/Flutter-Pakete)

Alle Abhängigkeiten werden in der Datei pubspec.yaml im Projektstamm verwaltet.
- `flutter_riverpod`: State-Management
- `sqflite_sqlcipher`: Datenbank inkl. Verschlüsselung
- `argon2_ffi`: Für das sichere Hashen des Master-Passworts
- `local_auth`: Für den Zugriff auf FaceID und Fingerabdruck
- `webcrypto`: Für RSA
- `dargon2_flutter`: Für Argon2

Du fügst sie über die Kommandozeile hinzu:
```shell
flutter pub add flutter_riverpod
flutter pub add sqflite_sqlcipher
flutter pub add argon2_ffi
flutter pub add local_auth
flutter pub add webcrypto
flutter pub add dargon2_flutter
```
Anschließend wird automatisch ein `flutter pub get` ausgeführt, um die Pakete herunterzuladen.

#### Webcrypto

Einmalig ausführen (baut BoringSSL für native Plattformen): 
```shell
dart run webcrypto:setup
```

```
Code wird generiert:
- Bibliothek "C:/Users/frank/Source/AndroidStudio/FamKey/.dart_tool/webcrypto/Debug/webcrypto.lib" 
- und Objekt "C:/Users/frank/Source/AndroidStudio/FamKey/.dart_tool/webcrypto/Debug/webcrypto.exp"
  
Package webcrypto now configured for use in your project.
This is only necessary for using package:webcrypto in unit tests and scripts, not for usage in applications.
```

Troubleshooting:
- CMake fehlt. 
  - Android Studio → SDK Manager → SDK Tools → CMake → ✅ installieren
  - Den Pfad zur Windows-Umgebungsvariable PATH hinzufügen:
    `C:\Users\frank\AppData\Local\Android\Sdk\cmake\<version>\bin\`
- NASM (Netwide Assembler) fehlt – wird von BoringSSL für die optimierten Crypto-Routinen benötigt.
   - https://www.nasm.us/pub/nasm/releasebuilds/3.02rc6/win64/ (neueste Version, x.xx.xx-installer-x64.exe) herunterladen und installieren
   - Den Pfad zur Windows-Umgebungsvariable PATH hinzufügen: `C:\Users\frank\AppData\Local\bin\NASM`


### 2.5 SQLCipher-DLL für Windows

SQLCipher (basiert auf SQLite 3.51.2) wird benötigt, um unter Windows die SQLite-DB verschlüsseln zu können.

- Download: https://github.com/utelle/SQLite3MultipleCiphers/releases/tag/v2.2.7 (`sqlite3mc-2.2.7-sqlite-3.51.2-win64.zip`)
- `sqlite3mc_x64.dll` aus dem Archiv nach `C:\Users\frank\Source\AndroidStudio\FamKey\` kopieren

### 2.6 Datenbank-Tool für Android Studio

Database Navigator 3.7.2.0 von Oracle 
https://docs.oracle.com/en/database/oracle/database-navigator/3.7/dbnug/introduction-oracle-database-navigator.html

Ein SQLCipher‑fähiger JDBC‑Treiber kann hier heruntergeladen werden:
https://github.com/Willena/sqlite-jdbc-crypt/releases/download/3.51.2.0/sqlite-jdbc-3.51.2.0.jar
Speicherort: C:\Users\frank\Source\AndroidStudio\FamKey\drivers\sqlite-jdbc-3.51.2.0.jar 

Als Client-DB wird diese SQLite-Datei verwendet:
`jdbc:sqlite:/Users/frank/AppData/Roaming/de.frohlfing.famkey/FamKey/vaults/test1.db3`  
- Master-Passwort: 4711
- Parameter für Database Navigator:
  ```ini
  cipher=sqlcipher
  hexkey_mode=SSE
  key=65e4917e2035121562eba4b67827e3b5e21a6d10c01000d8354ae3c64f447f22
  ```
- oder per JDBC-URL mit Query-Parametern
  `/Users/frank/AppData/Roaming/de.frohlfing.famkey/FamKey/vaults/test1.db3?cipher=sqlcipher&hexkey_mode=SSE&key=65e4917e2035121562eba4b67827e3b5e21a6d10c01000d8354ae3c64f447f22`
  
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

### 2.7 HTML-Renderer

- in Yaaml eintragen:
   ```yaml
   flutter_inappwebview: ^6.1.5
   ```
- Android: Netzwerk-Ausnahme verbieten
   In `apps/FamKey/android/app/src/main/AndroidManifest.xml` darf **kein** `android:usesCleartextTraffic="true"` gesetzt sein. Standardmäßig ist es false — gut so.
- iOS:  App Transport Security aktiv lassen
   In `Info.plist` darf **kein** `NSAllowsArbitraryLoads = true` gesetzt sein.

### 2.8 App-Icon

1. `flutter_launcher_icons` installieren (einmalig): 
    - `pubspec.yaml` erweitern
        ```yaml
        dev_dependencies:
          flutter_launcher_icons: ^0.13.1
        
        flutter_launcher_icons:
          image_path: "assets/icons/app_icon.png"
          android: true
          ios: false
          web:
            generate: true
            image_path: "assets/icons/app_icon.png"
          windows:
            generate: true
            image_path: "assets/icons/app_icon.png"
        ```
   - Pakete aktualisieren: `flutter pub get`

2. Icon (1024 x 1024) unter `assets/icons/app_icon.png` ablegen
3. Icons generieren: `flutter pub run flutter_launcher_icons`
   Das erzeugt automatisch: 
     - Android adaptive icons (`mipmap-*`)
     - Windows `.ico`
     - Web `favicon.png`, `manifest.json`, `icons/`
     - iOS Assets

## 3. Einrichtung der IDE für Android-Apps

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

Hardware-Profile für den Emulator
https://developer.samsung.com/galaxy-emulator-skin/galaxy-s.html

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

- APK auf Emulator deployen (siehe `/FamKey/bin/deploy-FamKey.ps1`):
  ```shell
  C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe uninstall com.companyname.FamKey | Out-Null
  C:\Users\frank\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r C:\Users\frank\Source\Rider\FamKey\FamKey\bin\Debug\net8.0-android\android-x64\com.companyname.FamKey-Signed.apk
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

### 3.7 Gradle-Konfiguration

#### Was ist Gradle?

**Gradle** ist das Build-System für Android-Apps. Es übernimmt:
- Kompilieren von Kotlin/Java-Quellcode
- Verlinken nativer C/C++-Bibliotheken (NDK/CMake)
- Verpacken der App als APK/AAB
- Auflösen von Abhängigkeiten (ähnlich wie `pub get` in Flutter/Dart)

Flutter selbst startet Gradle im Hintergrund, wenn du `flutter run` oder `flutter build apk` ausführst.
Die Konfiguration liegt in drei Dateien unter `android/`:

| Datei                  | Zweck                                                       |
|------------------------|-------------------------------------------------------------|
| `settings.gradle.kts`  | Plugin-Versionen (AGP, Kotlin) und Projektstruktur          |
| `build.gradle.kts`     | Globale Build-Einstellungen für alle Subprojekte            |
| `app/build.gradle.kts` | App-spezifische Einstellungen (minSdk, targetSdk, ABI, ...) |

Die Endung `.kts` steht für **Kotlin DSL** (Kotlin Script). Ältere Projekte nutzen noch Groovy (`.gradle`).

#### Versionsanforderungen

Die Gradle-Versionen sind nicht beliebig — Flutter-Pakete setzen bestimmte Mindestversionen voraus.

**Aktuell verwendete Versionen** (`android/settings.gradle.kts`):
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.1" apply false   // Android Gradle Plugin (AGP)
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}
```

**Warum diese Versionen?**
- `shared_preferences_android >= 2.4.23` setzt **Kotlin 2.3.0** und **AGP 8.13.1** voraus.
  Ältere Versionen führen zu Java-Kompilierungsfehlern beim Build.
- Kotlin 2.3.0 hat die veraltete `kotlinOptions`-DSL entfernt. In `android/app/build.gradle.kts`
  muss deshalb der neue Stil verwendet werden:
  ```kotlin
  // Neu (Kotlin 2.3.0+):
  kotlin {
      compilerOptions {
          jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
      }
  }
  // Nicht mehr: kotlinOptions { jvmTarget = "17" }
  ```

#### compileSdk-Override für Subprojekte (`android/build.gradle.kts`)

Flutter-Plugins bringen eigene `build.gradle`-Dateien mit, die oft einen veralteten `compileSdkVersion`
deklarieren. Transitive AndroidX-Abhängigkeiten (z.B. von `webcrypto`) erfordern jedoch mindestens
API 36. Der folgende Block in `android/build.gradle.kts` hebt alle Library-Subprojekte automatisch
auf mindestens API 36 an, ohne deren Quellcode zu ändern:

```kotlin
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class)?.apply {
            if ((compileSdk ?: 0) < 36) compileSdk = 36
        }
    }
}
```

### 3.8 Arm64-only-Geräte (Samsung Galaxy S25 und neuer)

Das Samsung Galaxy S25 (und neuere Flagship-Geräte) unterstützen **ausschließlich arm64-v8a** — kein 32-Bit-ABI.

Der ABI-Filter in `android/app/build.gradle.kts` schränkt den Build explizit auf arm64 ein, damit kein
überflüssiger x86/armeabi-Code eingebaut wird:

```kotlin
defaultConfig {
    ndk {
        abiFilters += setOf("arm64-v8a")
    }
}
```

### 3.9 Argon2 auf Android — manuell kompilierte Native Library

#### Hintergrund

Dies ist ein **bekannter Bug in `dargon2_flutter`**, der durch den AGP-Upgrade ausgelöst wird:
- GitHub Issue: https://github.com/tmthecoder/dargon2/issues/26
- Fehlermeldung: `dlopen failed: library "libargon2-arm.so" not found`

`dargon2_flutter` bindet Argon2 über FFI ein: Dart ruft direkt eine native C-Bibliothek
(`libargon2-arm.so`) auf. Diese Bibliothek wird normalerweise durch einen CMake-Build im Paket
selbst erzeugt (`dargon2_flutter_mobile` → `android/CMakeLists.txt`). Unter AGP 8.13.1 läuft
dieser CMake-Build nicht mehr durch — die `.so` fehlt komplett im APK. Die App startet zwar, aber
beim Login greift der Fallback `EmptyDArgon2Flutter`, der alle Methoden mit `UnimplementedError` wirft.

**Diagnose:** Im Build-Output fehlt nur die Argon2-Library:
```
build/app/intermediates/merged_native_libs/debug/.../lib/arm64-v8a/
  libflutter.so        ✓
  libwebcrypto.so      ✓
  libsqlite3.so        ✓
  libargon2-arm.so     ✗  ← fehlt
```

#### Lösung: Library manuell per NDK kompilieren

Die C-Quellen sind im pub cache vorhanden. Wir kompilieren die Library selbst mit dem NDK-Compiler
und legen sie als `jniLibs`-Datei ins Projekt. Android nimmt `jniLibs` direkt — ohne CMake.

**Schritt 1 — NDK SDK Tools installieren** (falls noch nicht geschehen):  
Android Studio → SDK Manager → SDK Tools → NDK (Side by side) → ✅ installieren

**Schritt 2 — Library kompilieren** (Git-Bash oder WSL, aus dem Projektverzeichnis):
```bash
NDK="$HOME/AppData/Local/Android/Sdk/ndk/28.2.13676358"
PKG_VER="dargon2_flutter_mobile-3.3.0"
SRC="$HOME/AppData/Local/Pub/Cache/hosted/pub.dev/$PKG_VER/android/Argon2"
CLANG="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang"

mkdir -p android/app/src/main/jniLibs/arm64-v8a

"$CLANG" -shared -fPIC -O2 \
  -o android/app/src/main/jniLibs/arm64-v8a/libargon2-arm.so \
  "$SRC/src/argon2.c" "$SRC/src/core.c" "$SRC/src/encoding.c" \
  "$SRC/src/ref.c" "$SRC/src/thread.c" "$SRC/src/blake2/blake2b.c" \
  -I"$SRC/include/"
```

- NDK-Version anpassen (`ndk/28.2.13676358`) falls eine andere installiert ist.  
- Verfügbare Versionen: `ls "$HOME/AppData/Local/Android/Sdk/ndk/"`

**Schritt 3 — `extractNativeLibs` aktivieren** (`android/app/src/main/AndroidManifest.xml`):

```xml
<application
    android:label="FamKey"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:extractNativeLibs="true">
```

Ohne dieses Flag lädt AGP 8.x native Libraries direkt aus dem APK (ohne sie zu entpacken).
Das setzt page-alignment und unkomprimierte Speicherung voraus — Bedingungen, die unsere
manuell kompilierte Library nicht automatisch erfüllt. Mit `extractNativeLibs="true"` werden
alle `.so`-Dateien beim App-Install nach `/data/app/<package>/lib/arm64/` entpackt, und
`dlopen('libargon2-arm.so')` findet sie zuverlässig per Name.

**Schritt 4 — Neu bauen:**
```bash
flutter clean 
flutter run -d <device-id>
```

#### Wartung

Die fertige `android/app/src/main/jniLibs/arm64-v8a/libargon2-arm.so` ist im Repository
eingecheckt. Wiederholen wenn:
- `dargon2_flutter_mobile` auf eine neue Version aktualisiert wird (neue C-Quellen)
- Das NDK auf eine neue Version aktualisiert wird
- Ein neues Ziel-ABI hinzukommt (z.B. `x86_64` für Emulator-Support)

---

## 4. Einrichtung der IDE für WebAppliance (WASM)

### 4.1 WasmDatabase

Für die WasmDatabase müssen diese beiden Dateien in den `web`-Ordner kopiert werden:

- `drift_worker.js` - Quelle: https://github.com/simolus3/drift/releases/tag/drift-2.31.0
- `sqlite3.wasm` - Quelle: https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4

Die Versionsnummern müssen exakt mit den Flutter-Paketen übereinstimmen!
Versionen aus `pubspec.lock` lesen:
```shell
Select-String -Path pubspec.lock -Pattern "^\s+(sqlite3|drift):" -A 2
````
Oder einfach `pubspec.lock` in Android Studio öffnen und nach dem Paketnamen suchen.

Bei einem Update der Flutter-Pakete dürfen diese beiden Dateien nicht vergessen werden.

### 4.2 Origin-Private File System (OPFS)

OPFS ist ein persistentes, origin-gebundenes Dateisystem im Browser.
Dateipfade werden als Verzeichnisstruktur im OPFS abgebildet.

Voraussetzung: Die App muss mit den COOP/COEP-Headern ausgeliefert werden,
damit SharedArrayBuffer und Atomics verfügbar sind (für den Drift-Worker).

Konfiguration in Android Studio:
- `Run` → `Edit Configurations` → `Add New Configuration` → `Flutter`
- In das Feld `Additional run args` dies einfügen:
```
-d chrome
  --web-header=Cross-Origin-Opener-Policy=same-origin
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```
Das OPFS selbst funktioniert auch ohne diese Header.

Per Terminal starten:
```shell
flutter run -d edge --web-header="Cross-Origin-Opener-Policy=same-origin" --web-header="Cross-Origin-Embedder-Policy=require-corp"
```

Verfügbare Browser anzeigen:
```shell
flutter devices
```

Dateien im OPFS anzeigen (in der Entwicklungskonsole des Browsers (F12)):
```javascript
const root = await navigator.storage.getDirectory();
const driftDir = await root.getDirectoryHandle('drift_db');
for await (const [name, handle] of driftDir.entries()) {
  console.log(name, handle.kind);
}
```

---

## 5. Backend (PHP) unter Windows

Für die Entwicklung unter Windows dient **XAMPP** als Webserver.

### 5.1 Lokalen Webserver einrichten

1. XAMPP installieren.
   https://www.apachefriends.org/download.html

2. PowerShell-Skript ausführen, um die PHP-Version zu aktualisieren und um die Xdebug-Erweiterung zu installieren:
    ```shell
      .\bin\xampp_upgrade.ps1
    ``` 
   
    Das Skript automatisiert diese Schritte:

    a) Aktuelle PHP-Version installieren
        - PHP 8.5 herunterladen
            - Offizielle PHP‑Downloads:
                https://windows.php.net/download (z.B.: php‑8.5.5‑Win32‑vs17‑x64.zip)
                    - Thread Safe (TS)
                    - VS17 Build (Visual Studio 2022)
                    - x64
                    - ZIP‑Archiv, nicht MSI
                
        - XAMPP stoppen (Apache + MySQL).
        - Backup anlegen:
            `C:\xampp\php` → `C:\xampp\php-8.2-backup`
        - PHP‑8.5‑ZIP nach `C:\xampp\php` entpacken.
        - Alte php.ini übernehmen:
            `C:\xampp\php-8.2-backup\php.ini` → `C:\xampp\php\php.ini`
        -  C:\xampp\php\php.ini prüfen/anpassen
            ```
            extension_dir = "C:\xampp\php\ext"
        
            extension=curl
            extension=openssl
            extension=mbstring
            extension=fileinfo
            extension=gd
            extension=intl
            extension=pdo_mysql
        
            date.timezone = Europe/Berlin

            opcache.enable=1
            opcache.enable_cli=1
            opcache.memory_consumption=192
            opcache.interned_strings_buffer=16
            opcache.max_accelerated_files=10000
            opcache.jit_buffer_size=64M
            ```
        - Apache starten.

    b) Xdebug installieren:
        1. PHP-Info ausgeben: <?php phpinfo(); ?>
        2. [Xdebug Wizard](https://xdebug.org/wizard) ausführen und ermittelte DLL nach `C:\xampp\php\ext\php_xdebug.dll` kopieren.
        3. C:\xampp\php\php.ini ergänzen um diesen Abschnitt:
            ```ini
            [Xdebug]
            zend_extension = xdebug
            xdebug.mode = debug,develop,coverage
            xdebug.start_with_request = yes
            xdebug.client_port = 9003
            xdebug.log = "C:/xampp/apache/logs/xdebug.log"
            ```
        4. Apache neu starten
        5. In PHP-Info sollte nun Xdebug aufgeführt sein.

### 5.2. SSL-Zertifikat installieren.

```shell
cd C:\xampp\apache\bin

.\openssl.exe req -x509 -nodes -newkey rsa:2048 `
 -keyout "C:\xampp\apache\conf\ssl.key\famkey.test.key" `
 -out "C:\xampp\apache\conf\ssl.crt\famkey.test.crt" `
 -days 365 `
 -config "C:\xampp\apache\conf\openssl.cnf" `
 -subj "/CN=famkey.test" `
 -addext "basicConstraints=CA:FALSE" `
 -addext "subjectAltName=DNS:famkey.test"
```

Damit der Browser dem selbstsignierten Zertifikat vertraut, muss es in den Browser-Zertifikatsspeicher importiert werden:
- Doppelklick auf `C:\xampp\apache\conf\ssl.crt\famkey.test.crt`, 
   - Zertifikat installieren..., 
      - Lokaler Computer
      - Zertifikatsspeicher: Vertrauenswürdige Stammzertifizierungsstellen

### 5.3 VirtualHost hinzufügen

Datei `C:\xampp\apache\conf\extra\httpd-vhosts.conf` bearbeiten:

```
<VirtualHost *:80>
    ServerName famkey.test
    ServerAlias 192.168.178.21

    DocumentRoot "C:/Users/frank/Source/AndroidStudio/famkey/host/public"

    <Directory "C:/Users/frank/Source/AndroidStudio/famkey/host/public">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName famkey.test
    
    DocumentRoot "C:/Users/frank/Source/AndroidStudio/famkey/host/public"

    SSLEngine on
	SSLCertificateFile "C:/xampp/apache/conf/ssl.crt/famkey.test.crt"
	SSLCertificateKeyFile "C:/xampp/apache/conf/ssl.key/famkey.test.key"

    <Directory "C:/Users/frank/Source/AndroidStudio/famkey/host/public">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```
Apache neu starten

### 5.4 Eintrag in die Hosts-Datei

`C:\Windows\System32\drivers\etc\hosts` als Administrator öffnen:

```
127.0.0.1      famkey.test
```

Der Sync-Server ist jetzt erreichbar unter: https://famkey.test/
Zum Testen via Android-Handy funktioniert auch: http://192.168.178.21/ (ohne SSL).

### 5.5 MySQL-Datenbank anlegen

1. phpMyAdmin starten:
   http://localhost/phpmyadmin// (User: root, kein Passwort)

2. Datenbank hinzufügen
    - Database Name: famkey
    - Server connection collation: utf8mb4_unicode_ci

3. SQL-Datei Host/migrations/001_initial_schema.sql importieren

---

## 6. Troubleshooting

- Fehlermeldung "Warnung beim Build: Dependency sqlite-net-sqlcipher 1.9.172 is vulnerable"
  - Das Paket ist verwundbar. Die gemeldete Schwachstelle ist CVE‑2022‑46908, ein Problem in SQLite 3.39.2. Behoben in SQLite 3.41.2.
  - Betrifft nur das SQLite‑Kommandozeilenprogramm. Anwendungen, die SQLCipher als Library nutzen (wie Flutter‑Apps), sind nicht betroffen.
  - **Lösung:**
    Betrifft nicht die App -> Warnung ignorieren (rechte Maustaste -> Ignore).

- **Android-Build: `SharedPreferencesPlugin` Kotlin-Kompilierungsfehler**
  - Symptom: `error: cannot find symbol` / `error: incompatible types` in `SharedPreferencesPlugin.java`
  - Ursache: `shared_preferences_android >= 2.4.23` wechselte zur Kotlin-DSL und setzt Kotlin 2.3.0 / AGP 8.13.1 voraus.
  - Lösung: In `android/settings.gradle.kts` die Versionen erhöhen (siehe Abschnitt 3.7).

- **Android-Build: `error: jvmTarget: String` in `build.gradle.kts`**
  - Symptom: Gradle-Build schlägt mit `error: jvmTarget: String` fehl.
  - Ursache: In Kotlin 2.3.0 wurde die veraltete `kotlinOptions { jvmTarget = "17" }` DSL entfernt.
  - Lösung: Den Block ersetzen durch:
    ```kotlin
    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
    ```

- **Android-Build: `compileSdk` AAR-Metadaten-Fehler (z.B. bei `:webcrypto`)**
  - Symptom: `Dependency ... requires compileSdk >= 34, but the project uses 31`
  - Ursache: Manche Flutter-Plugins deklarieren einen zu niedrigen `compileSdkVersion`.
  - Lösung: `afterEvaluate`-Block in `android/build.gradle.kts` (siehe Abschnitt 3.7).

- **Android-Laufzeit: Splash-Screen bleibt hängen / App startet nicht**
  - Symptom: Nur der Splash-Screen ist zu sehen, kein Fortschritt.
  - Ursache: `DArgon2Flutter.init()` wirft synchron eine Exception (`Failed to load dynamic library 'libargon2-arm.so'`). Der Zone-Error-Handler fängt sie ab, aber da der Logger noch nicht initialisiert ist, bleibt der Fehler stumm — `runApp()` wird nie erreicht.
  - Lösung: `DArgon2Flutter.init()` in `main.dart` in einen `try/catch` einwickeln (mit `debugPrint`), damit der Fehler sichtbar ist und der App-Start weiterläuft.

- **Android-Laufzeit: Login schlägt mit `UnimplementedError` fehl**
  - Symptom: `dlopen failed: library "libargon2-arm.so" not found` im Log, Login schlägt fehl mit `UnimplementedError: hashPasswordBytes is not implemented`.
  - Ursache: Bekannter Bug in `dargon2_flutter` (https://github.com/tmthecoder/dargon2/issues/26). Der CMake-Build der nativen Library läuft unter AGP 8.13.1 nicht durch. Als Fallback greift `EmptyDArgon2Flutter`, das alle Methoden als `UnimplementedError` wirft.
  - Lösung: Library per NDK manuell kompilieren + `extractNativeLibs="true"` setzen (siehe Abschnitt 3.9).

---

## 7. Ordnerstruktur
<pre>
FamKey/                                        # Projekt-Root
 ├── android/                                  # Android-spezifische Dateien (Gradle, Manifest, Ressourcen)
 ├── assets/                                   # Assests der App (z.B. app_icon.png)
 ├── bin/                                      # PowerShell-Skripte (z.B. zum Bauen der Releases)
 ├── coverage/                                 # Entsteht durch flutter test --coverage
 ├── docs/                                     # Projektdokumentation (Markdown)
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
 │    │    ├── setup/                          # Setup-Skript zur Installation des Sync-Servers beim Hoster (der Ordner wird nach der Installation automatisch gelöscht)
 │    │    ├── .htaccess                       # Apache Sicherheitsregeln, URL-Rewriting
 │    │    ├── favicons.php                    # Favicon-Proxy
 │    │    └── index.html                      # Startseite
 │    ├── src/                                 # PHP-Quellcode (PSR-4-ähnlich)
 │    │    ├── Controller/                     # Controller-Klassen
 │    │    ├── Core/                           # Framework-Kern
 │    │    └── Middleware/                     # Request/Response-Middleware
 │    ├── config.example.php                   # Beispiel-Konfiguration (dient als Vorlage für config.php)
 │    ├── config.php                           # Lokale Konfiguration mit Zugangsdaten/Secrets (nicht im Git-Repository)
 │    ├── routes.php                           # Zentrale Routenregistrierung
 │    └── sqlca.pem                            # CA-Zertifikat für TLS zur DB (z.B. Hetzner), s. https://docs.hetzner.com/de/konsoleh/account-management/databases/mysql/
 ├── lib/                                      # App-spezifischer Flutter-Code
 │    ├── core/                                # Kern-Logik
 │    ├── database/                            # Datenbank-Schema und Entitites (Drift)
 │    │    ├── database.dart
 │    │    └── database.g.dart
 │    ├── features/                            # Feature-Module (Pages + Notifiers + States)
 │    │    ├── main/                           # Hauptseite 
 │    │    │    ├── export/                    # Export-Dialog
 │    │    │    ├── import/                    # Import-Dialog  
 │    │    │    ├── sync/                      # Dialog für die Synchronisierung
 │    │    │    ├── main_page.dart             # UI der Hauptseite
 │    │    │    ├── main_notifier.dart         # Logik der Hauptseit 
 │    │    │    └── main_state.dart            # Status der Hauptseite 
 │    │    ├── login/                          # Loginseite
 │    │    ├── detail/                         # Detailansicht
 │    │    ├── edit/                           # Editierseite
 │    │    └── settings/                       # Setupseite
 │    ├── models/  (oder besser /domain ?)     # Datenmodelle (Entities, DTOs, Payloads, Exceptions)
 │    │    ├── dtos/
 │    │    └── payloads/
 │    ├── services/                            # Services (z.B. Database, Crypto, etc.)
 │    │    ├── biometric_service.dart
 │    │    ├── config_service.dart
 │    │    ├── crypto_service.dart
 │    │    ├── database_service.dart
 │    │    ├── password_service.dart
 │    │    ├── session_service.dart
 │    │    └── web_service.dart
 │    ├── widgets/                             # Allgemeien Widgets (Stateless) 
 │    │    ├── confirm_dialog.dart
 │    │    ├── password_field.dart
 │    │    ├── snacl.dart
 │    │    └── text_dialog.dart
 │    └── main.dart                            # Einstiegspunkt der App
 ├── native/                                   # Native Bibliotheken (z.B. SQLite3MC)
 │    └── sqlcipher/                           # SQLCipher (SQLite mit Verschlüsselungsfunktion)
 │         └── windows/
 │              ├── sqlite3mc_x64.dll          # SQLite3 Multiple Ciphers 2.2.7 (basiert auf SQLite 3.51.2) 
 │              └── sqlite-jdbc-3.51.2.0.jar   # SQLCipher‑fähiger JDBC‑Treiber (für Database Navigator)
 ├── test/                                     # Widget- und Unit-Tests der App
 ├── web/                                      # Web-spezifische Dateien
 ├── windows/                                  # Windows-spezifische Runner + CMake
 ├── .gitignore                                # Vom Git-Repository auszuschließende Dateien
 ├── .metadata                                 # Flutter-Projekt-Metadaten
 ├── pubspec.yaml                              # Dependencies der App
 ├── analysis_options.yaml                     # Linting-/Analyzer-Regeln
 ├── env.example.ps1                           # Beispiel-Datei (dient als Vorlage für env.ps1)   
 ├── env.ps1                                   # Umgebungsvariablen für PowerShell-Skripte   
 ├── LICENSE                                   # Lizenzhinweis   
 ├── pubspec.yaml                              # Paketinformation
 └── README.md                                 # Landingpage für das Git-Repository
</pre>

---

## 8. Konfiguration / Preferences

Die Speicherorte hängen vom Betriebssystem ab, da Flutter die nativen Mechanismen nutzt.

### 8.1 Unter Windows (Entwicklungsumgebung)
- Basisverzeichnis: `%AppData%\Roaming\[Package]\FamKey`
 C:\Users\frank\AppData\Roaming\de.frohlfing.famkey\FamKey\vaults
   - `%AppData%`: Z.B. `C:\Users\frank\AppData`
   - `[Package]`: Z.B. `de.frohlfing.famkey`
- SQLite-Datei: `.\LocalState\Trresorname.db3`
- Konfiguration: `.\Settings\settings.dat`

**Wie man sie am schnellsten löscht (Empfohlen):**
Du musst nicht in den Dateien wühlen. Windows hat eine eingebaute Funktion dafür:
1.  Drücke `Windows-Taste`.
2.  Tippe den Namen deiner App (`FamKey`).
3.  Rechtsklick auf das App-Icon -> **App-Einstellungen** (App settings).
4.  Scrolle runter und klicke auf den Button **Zurücksetzen** (Reset).
*   *Das löscht Preferences UND die lokale Datenbank.*

**Hier wird der Name festgelegt:**
- `windows/runner/Runner.rc` — bestimmt den Pfad:
  - CompanyName → erster Ordner (`de.frohlfing.famkey`)
  - ProductName → zweiter Ordner (`FamKey`)

`windows/CMakeLists.txt` — bestimmt den EXE-Namen:
  - BINARY_NAME "FamKey" → `FamKey.exe`

### 8.2 Unter Android (Emulator / Gerät)
Die Preferences liegen in einer XML-Datei im geschützten Speicher (SharedPreferences).
- Basisverzeichnis: `/data/data/com.companyname.FamKey/shared_prefs/com.companyname.FamKey.xml`

**Wie man sie löscht:**
1.  Im Emulator/Handy lange auf das App-Icon drücken.
2.  Auf das **(i)** (App Info) tippen.
3.  Gehe zu **Speicher & Cache** (Storage).
4.  Tippe auf **Speicherinhalt löschen** (Clear Storage / Clear Data).

**Hier wird der Name festgelegt:**
- `android/app/src/main/AndroidManifest.xml` (Schlüssel: `android:label`)

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