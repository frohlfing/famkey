# 03 Technisches Konzept

Diese Dokumentation umfasst den ersten Entwurf der UI und Grundfunktionen der PriVault-Anwendung.

## 1. UI (Entwurf)

### 1.1 Hauptansicht
- **Header:**
    - **Suchfeld:** Volltextsuche über Titel, Benutzername und URL.
    - **Sync-Indikator:** Kleines Icon (Wolke), das den Verbindungsstatus anzeigt (Grün = Synchron, Gelb = Lädt, Rot =
      Offline).
    - **Setup-Button (Zahnrad):** Navigiert zu den Einstellungen.
- **Body:**
    - **Liste der Einträge:** Scrollbare Liste.
    - **Listen-Element:** Zeigt Favicon (links) und Titel (fett) + Untertitel (z.B. Benutzername oder URL).
- **Footer / Floating Action Button (FAB):**
    - **New-Button (+):** Erstellt einen leeren Eintrag.

### 1.2 Detailansicht
Wird geöffnet durch Klick auf einen Listeneintrag.
- **Header:** Großer Titel & Icon.
- **Felder (Read-Only):**
    - **URL:** Klickbar (öffnet Browser).
    - **Benutzername:** Daneben ein **Copy-Button**.
    - **Passwort:** Standardmäßig maskiert (`******`). Daneben **Copy-Button** und **Eye-Button** (Toggle Visibility).
    - **Notiz:** Mehrzeiliges Textfeld.
    - **Anhänge:** Liste der Dateinamen (Klick = Öffnen/Speichern).
    - **Geteilt mit:** Liste der E-Mail-Adressen, die Zugriff haben.
    - **Metadaten:** "Zuletzt geändert: [Datum]".
- **Aktionen (Unten):**
    - **Edit-Button:** Wechselt in den Edit-Mode.
    - **Delete-Button:** Löscht Eintrag (mit "Sind Sie sicher?"-Dialog).
    - **Back-Button:** Zurück zur Hauptansicht.

### 1.3 Bearbeiten / Neuer Eintrag (Edit Mode)
- **Felder (Input):**
    * Titel, URL, Benutzername, Notiz (Textfelder).
    - **Passwort:** Textfeld + **Generator-Button** (Würfel/Zauberstab), der ein starkes Zufallspasswort einfügt.
    - **Anhänge:** Button "Datei anhängen".
    - **Teilen:** Eingabefeld "E-Mail Adresse" + Button "Hinzufügen" (prüft Public Key auf Server).
- **Aktionen:**
    - **Save:** Speichert (AES-Verschlüsselung + Upload).
    - **Cancel:** Verwirft Änderungen.

### 1.4 Einstellungen
- **Account:**
    * Anzeige: Eingeloggter Benutzer (E-Mail).
    * Aktion: **Master-Passwort ändern** (Erfordert altes PW -> Re-Encryption des Private Keys).
- **Server / Host:**
    * Eingabefelder für API-URL (Hetzner Webspace).
- **Sicherheit:**
    - **Biometrie:** Switch (An/Aus).
    - **Auto-Logout:** Slider oder Eingabe (z.B. "Nach 60 Sekunden Inaktivität").
    - **Selbstzerstörung:** Switch + Eingabe ("Lösche lokale Datenbank nach 10 Fehlversuchen").
- **Daten-Management:**
    - **Import:** CSV-Datei importieren.
    - **Export:** Datenbank entschlüsselt als CSV exportieren (Warnhinweis!).

## 2. Grundfunktionen

### 2.1 Tresor anlegen und User registrieren
1. Nutzer gibt Tresor-Namen ("Familie") und Benutzernamen ("Frank") ein.
2. App generiert lokal:
    - `VaultHashName` (SHA256-Hash)
    - `UserHashName` (SHA256-Hash)
    - `User-UUID` (V4).
    - `Salt` (Random).
    - `MasterKey` (via Argon2).
    - `RSA-KeyPair`.
3. App verschlüsselt `RSA-Private-Key` mit `MasterKey`.
4. App sendet `Register`-Request an Server (mit API-Token).
   
**Anmerkungen:**
Um Konflikte zwischen verschiedenen Tresoren auf demselben Client zu vermeiden:
- Jeder Tresor erhält eine **eigene SQLite-Datei**: `MandantName.db3`.
- Beim Login wählt der Nutzer den Tresor-Namen aus.
- Inkonsistenzen (z.B. falsches Salt in Preferences) führen zum sofortigen Löschen der lokalen Datei und Erzwingen einer Neuregistrierung/Onboarding.

### 2.2 Favicons
Favicons werden beim Erstellen/Bearbeiten einmalig geladen und als Base64-String direkt im verschlüsselten Blob gespeichert.

### 2.3 Dateianhänge
Dateianhänge werden mit dem Entry-Key verschlüsselt und separat hochgeladen. Beim Öffnen werden sie in den Cache entschlüsselt und nach Gebrauch sicher gelöscht.

### 2.4 Synchronisation
- Methode: "Last Edit Wins" (basierend auf UTC-Zeitstempel)
- Weicht die Systemzeit des Geräts mehr als 5 Minuten von der Serverzeit (UTC) ab, verweigert der Server aufgrund der RSA-Signaturprüfung (`X-Timestamp`-Header) die Synchronisation.
- Das Backend dient als "dummer" Speicher für verschlüsselte Blobs. Es validiert keine Dateninhalte, sondern nur Berechtigungen.
- Der Sync erfolgt in zwei Schritten:
    1. Server-Version prüfen: 
        - Wenn AppVersion.syncProtocolVersion < serverVersion.minSyncProtocolVersion: App ist veraltet
        - Wenn AppVersion.syncProtocolVersion > serverVersion.syncProtocolVersion: Server ist veraltet
    2. Benutzer prüfen: 
        - Benutzer registrieren, wenn sein Name nicht auf dem Server im angegebenen Tresor existiert. 
        - Ansonsten sicherstellen, dass die UUID und die Schlüssel des Benutzers passen. 
          Wenn nicht: Adoptionsprozess starten (s. 2.5).
    3. Freundesliste vom Server herunterladen und lokale Liste aktualisieren.
        - Falls ein Freund einen neuen Fingerprint hat, werden seine Entry-Keys gelöscht und das Vertrauen entzogen.
        - Sync abbrechen, wenn die Umschlüsselung eines Entry-Keys noch aussteht.
    4. **Pull:** Einträge vom Server herunterladen, die sich seit der letzten Synchronisation geändert haben.
    5. **Push:** Veränderte Einträge hochladen.
    6. Aktualisierte Freundesliste an den Server hochladen
    7. Zeitpunkt der Synchronisation (UTC, Serverzeit) lokal speichern.
- Sicherheitskonzept:
    - **Globaler API-Token:** Jede Anfrage muss im Header per `Bearer` ein API-Token mitsenden. Ohne Token antwortet der Server mit 401. Dies verhindert das Scannen des Servers durch Bots. (`Bearer` ist sehr verbreitet, z.B. bei OAuth2, JWT, Sanctum, Passport.)
    - **Rate Limiting:** Um Denial-of-Service oder Speicher-Flooding zu verhindern, limitiert der Server die Anzahl neuer/geänderter Einträge (`entries`) pro Stunde (konfigurierbar, Default: 200).
- Mandantenfähigkeit: Das System unterstützt mehrere isolierte Tresore auf demselben Server.
    - **Identifikation:** Ein Tresor wird durch seinen **Namen** (z.B. "Familie", "Firma") identifiziert.
    - **Isolation:** Ein Sync-Vorgang ruft immer nur Daten für eine spezifische `vault_id` ab.

### 2.5 Adoption (Onboarding mit Zweitgerät oder Master-Key auf dem Server ist aktueller)
1. Nutzer gibt Tresor-Namen und Benutzernamen ein.
2. **Check:** App fragt Server: "Gibt es User 'Frank' in Tresor 'Familie'?"
3. **Antwort Ja:** Server liefert `User-UUID`, `Salt` und `EncryptedPrivateKey`.
4. **Benutzer-UUID übernehmen:** 
    - Falls die lokale `User-UUID` von der des Servers abweicht, aktualisiert die App die Lokale.
4. **RSA-Key übernehmen:**
    - App fordert Master-Passwort.
    - App berechnet `MasterKey` (mit dem Salt vom Server!).
    - App versucht, `EncryptedPrivateKey` zu entschlüsseln.
    - *Erfolg:* Identität bestätigt. Schlüssel im RAM. Sync startet.
    - *Fehler:* Passwort falsch.

### 2.6 Teilen mit Freunden
Zu unterscheiden ist:
- **Benutzer:** Der Nutzer der App.
- **Freund:** Die Person, die der Benutzer zum Teilen in die App hinzugefügt hat.
- Zugriffsebene (access_level):
  - 0: Kein Zugriff.
  - 1: Leserecht (CanRead).
  - 2: Lese- und Schreibrecht (CanWrite).
  - 3: Vollzugriff (Owner: Löschen, Rechte verwalten, Anhänge verwalten).
- Vorgang:
  1. App lädt `User-UUID` und `PublicKey` von Tinka vom Server.
  2. App zeigt Fingerprint an ("Verifiziere Tinka: A1-B2-C3...").
  3. App nimmt den unverschlüsselten `EntryKey` von Eintrag X (liegt im RAM).
  4. App verschlüsselt `EntryKey` mit `Tinka-PublicKey`.
  5. App lädt neue Permission (`entry_uuid`, `tinka_uuid`, `encrypted_key`) hoch.

### 2.7 Freund löschen (verstecken)
Wenn ein Freund bereits Zugriffsrechte auf einen Eintrag hat, dieser aber "entfreundet" wird, 
kann er nicht gelöscht werden, da die Information an das Zweitgerät und an den Ex-Freund synchronisiert werden muss.
Stattdessen werden alle Entry-Keys geleert und der Freund wird als "versteckt" markiert.

Regelwerk, wann EntkryptedKey (verschlüsselter Entry-Key) gesetzt ist und wann nicht:
1) Wenn User.IsHidden = true, dann AccessLevel = 0
2) Wenn AccessLevel = 0, dann EntkryptedKey = empty
3) Wenn RSA-Key geändert wird, EntkryptedKey = empty
4) Wenn IsVerified auf True gesetzt wird, oder wenn für einen Eintrag AccessLevel >= 1 gesetzt wird, dann werden alle leeren EntkryptedKey gesetzt, sofern AccessLevel >= 1 ist

### 2.8 Master-Passwort ändern
1. User gibt **Neues Passwort** ein.
2. App generiert **Neues Salt**.
3. App berechnet **Neuen Master-Key**.
4. App nimmt den (bereits entschlüsselten) RSA-Private-Key aus dem RAM und verschlüsselt ihn mit dem **Neuen Master-Key**.
5. **Kritischer Schritt (lokal):** App führt `PRAGMA rekey` auf der Datenbank aus (verschlüsselt die Datei neu).
6. **Kritischer Schritt (Server):** App lädt das neue `UserEntity` (Neues Salt + neuer Encrypted Key) auf den Server hoch.
7. Konsequenz für andere Geräte (das Master-Passwort auf allen Gräten muss dasselbe sein):
   - Wenn du das Passwort am PC änderst:
     1. PC hat `Salt_Neu`.
     2. Server hat `Salt_Neu`.
     3. Handy hat noch `Salt_Alt`.
   - Wenn das Handy das nächste Mal synct (`SyncAsync`), passiert Folgendes:
     1. `CheckUserExists` liefert `Salt_Neu`.
     2. Der Check if `(remoteUser.Salt != localUser.SaltBase64)` schlägt an.
     3. Die Exception "Sicherheits-Konflikt" wird geworfen.
     4. Der User am Handy muss den "Notfall-Reset / Adoption" durchführen (also das neue Passwort eingeben), um wieder syncen zu können.

### 2.9 Notfall-Reset (Key Rotation)
Bei Verlust eines Geräts oder Verdacht auf Passwort-Diebstahl:
1.  Der Nutzer ändert das Master-Passwort an einem vertrauenswürdigen Client (PC).
2.  Der Client generiert ein **neues RSA-Schlüsselpaar**.
3.  Der Client lädt alle Schlüssel (`permissions`) herunter, entschlüsselt sie mit dem alten Key und verschlüsselt sie mit dem neuen Key (Re-Encryption).
4.  Der Client lädt die neuen Schlüssel und den neuen User-Datensatz (neues Salt/Encrypted PrivKey) hoch.
5.  `updated_at` in der `users`-Tabelle wird aktualisiert.
6.  **Andere Clients:** Erkennen beim Sync den Zeitstempel-Unterschied und verweigern den Dienst, bis der Nutzer das **neue** Passwort eingibt.

### 2.10 Fingerprint-Check (Identitäts-Wechsel eines Freundes)
**Szenario:** Tinka verliert ihr Handy und führt einen Notfall-Reset (neues RSA-Paar) durch.
1. Frank startet den Sync.
2. **App-Logik:** `PullRemoteSettings` stellt fest: Tinka's Public-Key auf dem Server weicht vom lokalen ab.
3. **Reaktion:**
   - Sync bricht sofort ab (Sicherheitsstopp).
   - Tinka wird lokal als "Unverifiziert" markiert (Automatischer Vertrauensentzug, Warnsymbol ⚠️).
   - Alle für Tinka verschlüsselten Entry-Keys werden lokal gelöscht (da nutzlos).
4. **Behebung:** Frank muss Tinka manuell neu verifizieren. Dabei werden die Entry-Keys der geteilten Einträge mit Tinka's neuem Public-Key neu verschlüsselt.

### 2.11 Auto-Fill (Mobile & Desktop)
Der Auto-Fill-Prozess läuft isoliert vom Haupt-UI ab und erfordert native Schnittstellen.

**Mobile (Android & iOS):**
   1. **Trigger:** Das Betriebssystem (OS) erkennt ein Login-Formular in einer anderen App oder im Browser.
   2. **Anfrage:** Das OS weckt den `SecureVault AutofillService` (Android) bzw. die `CredentialProviderExtension` (iOS) auf und übermittelt die **Domain** (z.B. "paypal.com") oder die **App-ID** (z.B. "com.paypal.android").
   3. **Lookup:**
      - Der Service öffnet die verschlüsselte lokale DB (benötigt Zugriff auf den *Shared Key* via Keystore).
      - Er sucht in der Tabelle `entries` nach Einträgen, wo die URL zur Domain passt.
   4. **Authentifizierung:** Falls die DB gesperrt ist, fordert der Service über das OS eine Biometrie-Prüfung an.
   5. **Response:** Der Service entschlüsselt die passenden Credentials und gibt sie strukturiert an das OS zurück. Das OS füllt die Felder.

**Windows/macOS:**
   - **V1 (Browser Extension):** Eine separate Chrome/Edge-Extension kommuniziert via "Native Messaging Host" mit der laufenden SecureVault-App, um Credentials für die aktuelle URL abzufragen.
   - **V2 (Auto-Type Legacy):** Der User klickt in SecureVault auf "Einfügen". Die App wechselt den Fokus zum letzten Fenster und simuliert Tastaturanschläge (`Username` -> `TAB` -> `Passwort` -> `ENTER`).

### 2.12 Browser-Extension (Desktop)
**Szenario:** Login auf einer Webseite am PC.
1. Eine schlanke Extension kommuniziert via **Native Messaging** mit der laufenden PriVault-App.
2. Die App liefert nach Freigabe die passenden Daten an die Extension.
3. **Fallback (Auto-Type):** Falls keine Extension möglich ist, simuliert die App Tastaturanschläge (`User -> TAB -> PW -> ENTER`).

### 2.13 Biometrie-Integration (Einloggen per Fingerabdruck oder Gesichtserkennung)
- **Ziel:** Login ohne Tippen, aber kryptografisch sicher.
- **Aktivierung:** App bittet den System-Keystore, den `Master-Key` (der im RAM liegt) mit einem hardware-gebundenen
  Schlüssel zu verschlüsseln (Wrap). Das Ergebnis (`Biometric-Blob`) wird lokal gespeichert.
- **Login:** App lädt `Biometric-Blob` und bittet Keystore um Entschlüsselung. Keystore fordert Fingerabdruck an. Bei
  Erfolg wird der `Master-Key` in den RAM zurückgegeben.

### 2.14 Selbstzerstörung
Nach X Fehlversuchen (einstellbar) löscht die App die lokale Datenbank physikalisch vom Gerät.

### 2.15 Import

### 2.15 Backup, Import & Export
- **Import:** Massenimport bestehender Daten. Folgende Dateiformate werden für den Import unterstützt.
   - Bitwarden JSON (Spezifikation: https://gist.github.com/ctrlcmdshft/fe6baead7be858ca08666f34da028163)
   - KeePass XML (2.x) (Spezifikation: https://github.com/keepassxreboot/keepassxc-specs/blob/master/kdbx-xml/rfc.md)
   - 1Password 1PUX (Spezifikation: https://support.1password.com/1pux-format/)
   - Nicht spezifische CSV-Datei (wie bei KeePassXC)
   - Evtl., bietet KeePassXC an: Proton Pass JSON
   - Evtl., bietet 1Password an: Dashlane, LastPass, RoboForm
   - Wird NICHT unterstützt, weil Anhänge nicht enthalten sind: mSecure 6 CSV 
- **Export/Backup:** Unverschlüsselter Export (mit Warnhinweis) zur Datenportabilität oder verschlüsselter Export als Backup 
   - Format: Standard Zip-Archiv 
     - Datendatei: export.json (ähnlich wie Bitwarden, Binärdaten sind aber nicht eingebettet); oder CSV (Excel-Kompatibel, Vorteil: leicht einsehbar/editierbar)
     - Dateianhänge unter files (Vorteil: man kann sie direkt öffnen) 
- **HTML-/ oder PDF-Ausdruck:** Generierung eines Dokuments mit dem verschlüsselten Private-Key und dem Master-Passwort 
   (als Platzhalter zum Ausfüllen) zum physischen Ausdruck. Siehe KeePaxxXC, Exportieren -> HTML-Datei.

## 3. Versionierung

### App-Version
Wird in  `pubspec.yaml` gespeichert.
- Format `MAJOR.MINOR.PATCH` gemaß dem **Semantic Versioning-Schema** [SemVer](https://semver.org/):
   - MAJOR: Wird mit einem Redesign oder bei einem Migrations-Bruch erhöht.
   - MINOR: Wird mit einer Funktionsänderung erhöht und mit einer neuen Hauptversion auf 0 zurückgesetzt.
   - PATCH: Wird mit einer Fehlerbehebung (Bugfix) erhöht und mit einer neuen Nebenversion auf 0 zurückgesetzt.
- Buildnummer: Wird (theoretisch) mit jedem Build erhöht. Sie wird niemals zurückgesetzt. Dies ist auch der `versionCode` für den Google-Store. 

Angezeigte App-Version inkl. Buildnummer (aber ohne Patch-Nummer): z.B. "1.0+42")
 
### Datenbank-Schema-Version
- DB-Schema des Servers: Wird auf dem Server in der Tabelle `verions` gespeichert (ein Integer).
- DB-Schema des Tresors: Flutter nutzt zur Speicherung der Datenbank-Schema-Version den Standard-Mechanismus von SQLite: 
   Jede SQLite-Datenbankdatei hat einen Header-Bereich, in dem Metadaten gespeichert werden. 
   Eines dieser Felder ist die `user_version`, eine 32-Bit-Ganzzahl, die für genau diesen Zweck vorgesehen ist: die Version des Anwendungsschemas zu speichern.

Sollte die App eine ältere DB-Schema-Version öffnen, wird die DB automatisch aktualisiert.
Sollte die App eine neuere Datenbank öffnen, wird ein Hinweis mit der Bitte um Upgrade der App angezeigt und die DB sofort wieder geschlossen.

### Sync‑Protokollversion
- Sync‑Protokollversion des Servers: Wird auf dem Server in `config.php` gespeichert.
- Kleinste vom Server unterstützte Protokollversion: Wird auf dem Server in `config.php` gespeichert.
- Sync‑Protokollversion der App: Wird im Code gespeichert. 
 
Vor der Synchronisation wird die Protokollversion der App mit der Protokollversion des Servers verglichen:
   - Wenn client.syncProtocolVersion < server.minSupportedSyncProtocol → App zu alt
   - Wenn client.syncProtocolVersion > server.currentSyncProtocol → Server zu alt

## 4. Host-URLs
- https://privault.frank-rohling.de/api (für MAJOR = 1)
- https://privault{MAJOR}.frank-rohling.de/api (für MAJOR > 1)