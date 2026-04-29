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
- ✅ Laragon mit Xdebug (für PHP-Debugging) installieren
- ✅ MySQL DB auf dem Serve erstellen
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
- ✅ Import: PriVault, Keepass, Bitwarden, 1Password-Import
- ✅ Report (Darknet-Check https://haveibeenpwned.com/, Passwortstärke und -Alter)
- ✅ Auto-Sperre nach x Sekunden
- ✅ Zwischenablage nach x Sekunden leeren
- ✅ Notfall-Reset
- ✅ Auto-Fill (unter Android per Systemfunktion, unter Windows per Auto-Type, für Web keine Unterstützung)
- ❌ Entwickler-Menü freischalten (5x auf App-Version klicken)
- ❌ DB-Viewer im Entwickler-Menü hinzufügen
- ❌ Skripte zum Deployen, siehe https://copilot.microsoft.com/shares/hAWk4uv75JWVbYepVZiCg
- ❌ Passkeys-Unterstützung (https://keepassxc.org/docs/KeePassXC_UserGuide#_passkeys, https://fidoalliance.org/passkeys/)
- ❌ Zusätzlicher Schutz mit TOTPs (Time-based One-Time Passcodes) aus gängigen Authenticator-Apps (zweiter Factor)
 
### 1.5 Meilenstein 5: Androide App
- ✅ Emulator installieren
- ✅ Layout anpassen
- ❌ PlayStore-Bereitstellung

### 1.6 Meilenstein 6: WebAssembly (WASM)
- ✅ Damit auch die iPhones und iPads die App verwenden können, ohne dass ich ein Entwickler-Abo von Apple kaufen muss (100 €/Jahr).
- ❌ WASM auf dem Sync-Server bereitstellen

## 2. Todos / Feinschliff
- todos erledigten

## 3. Bugs
- 🐞 Bearer geht nicht, warum? (taucht beim Server nicht im Header auf)
- 🐞 Web: Import funktioniert nicht unter Web 
- 🐞 Nativ: Liste in Main filtern. Eintrag löschen -> Filter wird ignoriert

