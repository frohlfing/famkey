# 04 Entwicklungsplan

## 1. Meilensteine

### 1.1 Meilenstein 1: Basisfunktion
- ✅ Technologie-Stack definieren
- ✅ Sicherheitskonzept erstellen
- ✅ Flutter-Projekt anlegen
- ✅ CryptoService (Argon2, AES, RSA) implementieren
- ✅ SQLite-Layer mit SQLCipher aufsetzen
- ✅ UI mit Basisfunktionen erstellen (Login, Hauptseite, Detail, Settings)
- ✅ Passwort-Generator
- ✅ Passwort-Meter
- ✅ Passwortalter anzeigen
- ✅ Favicon erstellen
- ✅ Icons der Webseiten speichern und anzeigen
- ✅ Dateianhänge (Bilder direkt anzeigen, sonst Büroklammer-Icon als Link)
- ✅ App-Icon anpassen

### 1.2 Meilenstein 2: Backend & Sync
- ✅ API-Referenz definieren
- ✅ XAMPP (mit PHP 8.4 oder aktueller) und Xdebug (für PHP-Debugging) installieren
- ✅ MySQL DB auf dem Server erstellen
- ✅ Microframework für Webservice in PHP erstellen
- ✅ Sync-Algorithmus integrieren
- ✅ Verbindungsparameter in Einstellungen speichern
- ✅ Sync-Test-Button unter Einstellungen
- ✅ Teilen-Funktion (Family Sharing)
- ✅ Master-Passwort ändern
- ✅ Automatische Referenzseite bauen
- ✅ Landingpage der Webseite erstellen
- ✅ Versionierungs- & Migrationsstrategie entwerfen und implementieren
- ✅ Tresor umbenennen
- ✅ Benutzer umbenennen
- ✅ Tresor löschen (Optionen: a) nur lokal, b) nur auf dem Server, c) lokal + auf dem Server) 
 
### 1.3 Meilenstein 3: Tests
- ✅ Test-Umgebung einrichten
- ✅ Tests für Services bauen
- ✅ Automatischen Coverage-Report für Backend bauen, der bei clientseitigen Webservice-Tests generiert wird.
- ✅ Tests für ViewModels bauen
 
### 1.4 Meilenstein 4: Advanced Features
- ✅ Theme-Unterstützung (System/Dark/Light)
- ✅ Biometrie (Einloggen per Fingerabdruck oder Gesichtserkennung)
- ✅ Loggen (in Datei; Logdatei automatisch klein halten); unter Settings ein Button zum Anzeigen der Logdatei
- ✅ Drucken (Markdown-Generierung)
- ✅ Export (ZIP-File)
- ✅ Import: FamKey, Keepass, Bitwarden, 1Password-Import
- ✅ Report (Darknet-Check https://haveibeenpwned.com/, Passwortstärke und -Alter)
- ✅ Auto-Sperre nach x Sekunden
- ✅ Zwischenablage nach x Sekunden leeren
- ✅ Notfall-Reset
- ✅ Auto-Fill (unter Android per Systemfunktion, unter Windows per Auto-Type, für Web keine Unterstützung)
 
### 1.5 Meilenstein 5: Androide App
- ✅ Emulator  installieren
- ✅ Layout anpassen

### 1.6 Meilenstein 6: WebAssembly (WASM)
- ✅ Platform-Weichen (nativ/web) erstellen, wo notwendig
- ✅ Web-App testen
 
### 1.7 Meilenstein 7: Homepage
- ✅ Homepage erstellen
- ✅ Sync-Server für Multi-Tenant-Betrieb (pro Organisation einen virtuellen Server)
- ✅ Deployment-Skript erstellen, Apps und WASM auf der Homepage bereitstellen

### 1.8 Meilenstein 8: Version 1.1
- ❌ Entwickler-Menü freischalten (5x auf App-Version klicken)
- ❌ DB-Viewer im Entwickler-Menü hinzufügen
- ❌ Passkeys-Unterstützung (https://keepassxc.org/docs/KeePassXC_UserGuide#_passkeys, https://fidoalliance.org/passkeys/)
- ❌ Zusätzlicher Schutz mit TOTPs (Time-based One-Time Passcodes) aus gängigen Authenticator-Apps (zweiter Factor)
- ❌ PlayStore-Bereitstellung

## 2. Todos / Feinschliff
- DetailActionStatus -> DetailStatus
- MasterPasswordFormData -> MasterPasswordForm
- userName oder username

## 3. Bugs
- 🐞 Bearer geht nicht, warum? (taucht beim Server nicht im Header auf)
- 🐞 Web: Import funktioniert nicht unter Web 
- 🐞 Nativ: Liste in Main filtern. Eintrag löschen -> Filter wird ignoriert

