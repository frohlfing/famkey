# 04 Entwicklungsplan

## 1. Meilensteine

### 1.1 Meilenstein 1: Basisfunktion
- ✅ Technologie-Stack definieren
- ✅ Sicherheitskonzept erstellen
- ✅ MAUI Projekt anlegen
- ✅ CryptoService (Argon2, AES, RSA) implementieren
- ✅ SQLite-Layer mit SQLCipher aufsetzen
- ✅ UI mit Basisfunktionen erstellen (Login, Hauptseite, Detail, Settings)
- ✅ Material-icons (https://fonts.google.com/icons)
- ✅ Passwort-Generator
- ✅ Passwort-Meter
- ❌ Anzeige, wie alt das Passwort ist.
- ✅ Favicon erstellen
- ✅ Icons der Webseiten speichern und anzeigen
- ✅ Dateianhänge (Bilder direkt anzeigen, sonst Büroklammer-Icon als Link)

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

### 1.3 Meilenstein 3: Tests
- ✅ Test-Umgebung einrichten
- ✅ Tests für Services bauen
- ✅ Automatischen Coverage-Report für Backend bauen, der bei clientseitigen Webservice-Tests generiert wird.
- ✅ Tests für ViewModels bauen
 
### 1.4 Meilenstein 4: Advanced Features
- ✅ Multi-Themes
- ✅ Versionierungs- & Migrationsstrategie entwerfen und implementieren
- ✅ Biometrie (Einloggen per Fingerabdruck oder Gesichtserkennung)
- ✅ Ladeanzeige einbauen für Operationen, die länger dauern könnten (Bildschirm für Eingaben sperren)
- ❌ Fehler loggen und unter Einstellungen ein Button zum Anzeigen/Löschen + Loglevel (Aus, Debug, Fehler)
- ❌ Konsolenanwendung: Hex-Code des Master-Keys ausgeben
- ❌ Dialog, um den Passwortgenerator aus der Detailansicht einstellen zu können (Einstellungen siehe Settings. Page)
- ❌ Auto-Sperre (Ja/Nein, wenn Ja: nach x Sekunden)
- ❌ Selbstzerstörung (Daten löschen beim x. Fehlversuch)
- ❌ Notfall-Reset
- ❌ Auto-Fill
- ❌ CSV-Import
- ❌ CSV-Export
- ❌ PDF-Generierung ("Notfall-Bogen" zum Ausdrucken, siehe https://copilot.microsoft.com/shares/W5xBgDcNnvejZCq5qXtid)
- ❌ Sicheres Passwortfeld (direkt als byte array speichern), siehe https://copilot.microsoft.com/shares/gk2UA94MU96n6LiRoyyB1
- ❌ Skripte zum Deployen, siehe https://copilot.microsoft.com/shares/hAWk4uv75JWVbYepVZiCg
- ❌ Report über die Passwortstärke aller Einträge
- ❌ Passkeys-Unterstützung (https://keepassxc.org/docs/KeePassXC_UserGuide#_passkeys, https://fidoalliance.org/passkeys/)
- ❌ Zusätzlicher Schutz mit TOTPs (Time-based One-Time Passcodes) aus gängigen Authenticator-Apps (zweiter Factor)
- ❌ Darknet-Check: Prüfung, ob die Passwörter in Passwort-Leak-Datenbanken auftauchen (https://haveibeenpwned.com/) 
 
### 1.5 Meilenstein 5: Androide App
- ❌ Emulator installieren
- ❌ Layout anpassen
- ❌ Unit-Tests
- ❌ App Store-Bereitstellung

### 1.6 Meilenstein 6: Blazor WebAssembly (Blazor WASM)
- ❌ Damit auch die iPhones und iPads die App verwenden können, ohne dass ich ein Entwickler-Abo von Apple kaufen muss (100 €/Jahr). Siehe Copilot-Chat .NET MAUI Deployment für Windows & Android 

## 2. Todos / Feinschliff
- erledigt :-)

## 3. Bugs
- 🐞 Bearer geht nicht, warum? (taucht beim Server nicht im Header auf)
- 🐞 Sync mit Freunden (Parameter fehlt)
- 🐞 Beim Umschalten zw. Dark und Light wird nicht imm alles getauscht (erst nach Neustart) 
