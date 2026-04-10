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
- ✅ Fehler in Datei loggen


- ❌ Konzept für Suchen und filtern optimieren:
- In Tabelle `settings` Feld `encyptedMetaKey` hinzufügen (AES-Schlüssel für Meta-Angaben eines Eintrags - Vorteil: viel schneller als für jeden einzelnen EIntrag RSA anwenden zu müssen (ist notwendig für SHaren)
- In Tabelle `entries` Feld `meta` hinzufügen. Hier wird ein `entryMetaPayload` gespeichert. Beinhaltet category, title, url und notes. Wird in der Session abgelegt
- In Tabelle `entries` Felder category, title, url und notes löschen
- Evtl notes in meta zum suchindex umwandeln (kleinbuchstaben, doppelte Leerzeichen und doppelte wörter raus)

- ❌ App-Icon anpassen
 
- ❌ Entwickler-Menü freischalten (5x auf App-Version klicken)
- ❌ DB-Viewer im Entwickler-Menü hinzufügen

- ❌ Unter Einstellungen ein Button zum Anzeigen/Löschen der Logdatei
- ❌ Logdatei automatisch klein halten (Löschstrategie?) 
- ❌ Bei AppError.unknown auf Logfile hinweisen (beim Import, in der Snackbar, ...).

- ❌ Auto-Sperre (Ja/Nein, wenn Ja: nach x Sekunden)
- ❌ Selbstzerstörung (Daten löschen beim x. Fehlversuch)

- ❌ Notfall-Reset

- ✅ Keepass-XML-Import
- ❌ Bitwarden-JSON-Import
- ❌ 1Password-Import
- ❌ Generic-CSV-Import

- ❌ CSV-Export

- ❌ Auto-Fill

- ❌ Skripte zum Deployen, siehe https://copilot.microsoft.com/shares/hAWk4uv75JWVbYepVZiCg

- ❌ Passkeys-Unterstützung (https://keepassxc.org/docs/KeePassXC_UserGuide#_passkeys, https://fidoalliance.org/passkeys/)

- ❌ Darknet-Check: Prüfung, ob die Passwörter in Passwort-Leak-Datenbanken auftauchen (https://haveibeenpwned.com/)
- ❌ Report über die Passwortstärke und -Alter aller Einträge
 
- ❌ PDF-Generierung ("Notfall-Bogen" zum Ausdrucken, siehe https://copilot.microsoft.com/shares/W5xBgDcNnvejZCq5qXtid)

- ❌ Zusätzlicher Schutz mit TOTPs (Time-based One-Time Passcodes) aus gängigen Authenticator-Apps (zweiter Factor)

- ❌ Dialog, um den Passwortgenerator aus der Bearbeitungsseite einstellen zu können
- ❌ Sicheres Passwortfeld (direkt als byte array speichern), siehe https://copilot.microsoft.com/shares/gk2UA94MU96n6LiRoyyB1
 
### 1.5 Meilenstein 5: Androide App
- ✅ Emulator installieren
- ❌ Layout anpassen
- ❌ Unit-Tests
- ❌ App Store-Bereitstellung

### 1.6 Meilenstein 6: WebAssembly
- ❌ Damit auch die iPhones und iPads die App verwenden können, ohne dass ich ein Entwickler-Abo von Apple kaufen muss (100 €/Jahr). 
  Siehe Copilot-Chat .NET MAUI Deployment für Windows & Android 

## 2. Todos / Feinschliff
- todos erledigten
- Tresor umbenennen, ohne den Server zu tangieren (vault_uuid)
- Benutzer umbenennen, ohne den Server zu tangieren (bei Freunde umbenennen?)
- Tresor löschen (Optionen: a) nur lokal, b) nur auf dem Server, c) lokal + auf dem Server) -> User auf dem Server löschen, wenn es der letzte ist, Tresor löschen
- Detailansicht: Notiz muss ein Editierfeld sein, damit man den Text markieren und kopieren kann
- Detailansicht: "Geteilt mit" nur anzeigen, wenn in Einstellungen mindestens ein Freund eingefügt wurde

## 3. Bugs
- 🐞 Bearer geht nicht, warum? (taucht beim Server nicht im Header auf)
- 🐞 Android: Systembutton funktionieren nicht
- 🐞 Android: Biometrie funktioniert nicht 
