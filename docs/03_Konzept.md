# 03 Technisches Konzept

Diese Dokumentation umfasst den ersten Entwurf der UI und Grundfunktionen der PriVault-Anwendung.

## 1. UI (Entwurf)

### 1.1 Loginseite
- **Tresorname:** Textfeld. Daneben ein Button, um einen bereits existierenden Tresor auswählen zu können.
- **Passwort:** Passwortfeld. Mit Eye-Button (Toggle Visibility)
  - **Passwortstärke:** Ein Balken rot/gelb/grün (wird nur gezeigt, wenn ein neuer Tresor angelegt wird)
  - **Fingerprint-Icon:** Wird nur gezeigt, wenn Biometrie aktiviert ist. Wenn Ja, kann das Passwortfeld leer bleiben.
- **Login-Button:** Öffnet den Tresor (bzw. legt einen neuen an) und navigiert zur Hauptseite. 
   Ist nur anklickbar, wenn ein Tresor und (sofern keine Biometrie möglich ist) das Passwort angegeben wurde.

### 1.1 Hauptseite
- **Menü:** Jeder Menüpunkt navigiert zu der entsprechenden Seite
  - Synchronisation
  - Importieren
  - Exportieren
  - Drucken
  - Report
  - Einstellungen
  - Logout
- **Plus-Button**: Öffnet die Editierseite zum Erstellen eines neuen Eintrags.
- **Suchfeld:** Volltextsuche über Kategorie, Titel, URL und Notiz.
- **Filter:** Nur eigene Einträge anzeigen (Ja/Nein).
- **Scrollbare Liste der Einträge gruppiert in Kategorien:** Die Kategorien lassen sich auf- und zuklappen lassen.
  Jedes Listen-Element zeigt Favicon, Titel und URL. Mit Klick darauf wird die Detailansicht geöffnet.

### 1.2 Detailansicht
Wird geöffnet durch Klick auf einen Listeneintrag.
- **Header:** Großer Titel, Kategorie und Favicon (wird automatisch aus der URL geladen). 
- **Edit-Button:** Öffnet die Bearbeitungsseite zum Ändern des Eintrags.
- **Zurück-Button:** Navigiert zur Hauptseite.
- **Felder (Read-Only):**
    - **URL:** Mit Copy-Button und Link-Button (öffnet Browser).
    - **Benutzername:** Mit Copy-Button.
    - **Passwort:** Standardmäßig maskiert (`******`). Mit Eye-Button (Toggle Visibility) und Copy-Button.
      - **Passwortstärke:** Ein Balken rot/gelb/grün.
      - **Passwortalter:** Berechnet aus Zeitstempel des Passworts.
    - **Notiz:** Mehrzeiliges Textfeld (Readonly). Sieht wie normaler Text aus, aber selektierbar (zum Kopieren).
- **Anhänge:** Button "Datei anhängen" mit Liste der eingefügten Dateien. 
    - Für jede Datei wird ein Thumbnail (bei Bildern) oder ein Icon (entsprechend dem Dateityp) angezeigt, daneben Dateiname, Größe und Änderungsdatum. 
    - Jede Datei kann geöffnet werden. 
    - Für jede Datei ein Button zum Löschen.
- **Teilen:** Button "Teilen mit" (zum Auswählen eines Freundes aus der Freundesliste) mit Liste der ausgewählten Freunde.
    - Wird nur anzeigen, wenn unter "Einstellungen" mindestens ein Freund in die Freundesliste eingefügt wurde.
    - Jeder Freund wird angezeigt mit Namen und Fingerprint. 
    - Wenn der Freund nicht verifiziert ist, wird ein Warnhinweis angezeigt. 
    - Für jeden Freund ein Switch "Mit Schreibrecht". Daneben ein Button zum Löschen.
- **Metadaten:** Ersteller, Bearbeiter, Änderungsdatum

### 1.3 Bearbeitungsseite
Wird von der Hauptseite (Eintrag hinzufügen) oder von der Detailansicht (Eintrag bearbeiten) aufgerufen. 
- **Zurück-Button:** Navigiert im Bearbeitungsmodus zur Detailansicht, im Einfügemodus zur Hauptseite. 
     Wurde etwas geändert, Nachfrage, ob gespeichert werden soll.    
- **Save-Button:** Speichert die Änderungen und navigiert zur Detailansicht.
- **Felder (Input):**
    - **Kategorie:** Textfeld. Daneben ein Button, um bereits existierende Kategorien auswählen zu können.
    - **Titel:** Textfeld.
    - **URL:** Textfeld.
    - **Benutzername**: Textfeld.
    - **Passwort:** Passwortfeld. Daneben Eye-Button und Generator-Button, der ein Zufallspasswort einfügt.
      - **Passwortstärke:** Ein Balken rot/gelb/grün.
    - **Notiz**: Mehrzeiliges Textfeld.

### 1.4 Einstellungen
Wird über das Menü auf der Hauptseite aufgerufen.
Hier sind alle Einstellungen einsehbar. Zum Bearbeiten der jeweiligen Einstellung wird ein Button gezeigt, der einen modalen Dialog öffnet.
Ausnahme sind Ja/Nein-Optionen. Diese können direkt auf der Seite durch einen Switch geändert werden.
- **Zurück-Button:** Navigiert zur Hauptseite.
- **Optionen:**
  - **Tresor:**
      - Speicherort der Tresore: Wird nur angezeigt, kann nicht geändert werden.
      - Tresorname: Kritische Operation, weil auch der Syncserver betroffen ist. Erfordert daher das Master-Passwort.
  - **Login:**
      - Button "Master-Passwort ändern": Kritische Operation, weil eine Umschlüsselung der SQLite-Datei erfolgt. Erfordert bisheriges Passwort.
      - Switch "Biometrie verwenden": Erlaubt das Entsperren des Tresors via FIngerprint oder Gesichtserkennung.
  - **Timeouts:**
      - Automatische Sperre: z.B. "Nach 3 Minuten Inaktivität" (Optionen: Sofort, 1, 2, 3, 4, 5, 10 Minuten, Nie)
      - Zwischenablage leeren: z.B. "Nach 30 Sekunden" (Optionen: 10 s, 30 s, 60 s, 90 s, Nie)
  - **Sync-Server:**
      - Benutzername: Dieser Name wird bei Freunden in der Freundesliste angezeigt. 
      - Serveradresse: Der zugehörige Dialog hat auch ein Button zum Testen der Verbindung. Hier muss auch der API-Token angegeben werden. 
  - **Freunde:** (Freundesliste, die in der Detailansicht angezeigt wird, wenn ein Freund zum Teilen eines Eintrags ausgewählt wird.)
     - Mit Button zum Freund hinzufügen (Sucht den Namen der Person auf dem Server).
     - Liste der Freunde, jeweils mit Namen und Fingerprint. 
     - Für jeden hinzugefügten Freund ein Switch "Verifiziert" und ein Lösch-Button.
  - **Passwortgenerator:** Änderung aller Parameter über denselben Dialog.
      - Länge
      - Sonderzeichen
      - Lesbarkeit optimieren (I, l, O, 0 ausschließen)
  - **Designt:**
      - Theme: System, Hell, Dunkel
      - Umbenannte Kategorie (Dient als Platzhalter, falls keine Kategorie angegeben wurde)
  - **Systemeinstellungen:**
      - Button "Biometrie": Öffnet Systemeinstellungen für Fingerabdruck- oder Gesichtserkennung. 
      - Button "Autofill": Öffnet Hilfeseite für das automatische Ausfüllen
      - Button "App.Info": Zeigt Systemdetails dieser App an
- **Button "Tresor löschen":** Wird bewusst als letztes angezeigt.
    
## 2. Grundfunktionen

### 2.1 Tresor anlegen und User registrieren
1. Nutzer gibt neuen Tresornamen und Master-Passwort ein.
2. App generiert lokal:
    - `User-UUID` (V4).
    - `Salt` (Random).
    - `MasterKey` (via Argon2).
    - `RSA-KeyPair`.
3. App verschlüsselt `RSA-Private-Key` mit `MasterKey`.
4. App legt SQLite-Datei an (verschlüsselt mit SQLCipher bei Mobil- und Desktop-App, nicht bei Webbrowser-Appliance)

### 2.2 Favicons
Favicons werden beim Erstellen/Bearbeiten einmalig geladen und als Base64-String direkt im verschlüsselten Blob gespeichert.

### 2.3 Dateianhänge
Dateianhänge werden mit dem Entry-Key verschlüsselt und separat hochgeladen. Beim Öffnen werden sie in den Cache entschlüsselt und nach Gebrauch sicher gelöscht.

### 2.4 Synchronisation
- Methode: "Last Edit Wins" (basierend auf UTC-Zeitstempel)
- Weicht die Systemzeit des Geräts mehr als 5 Minuten von der Serverzeit (UTC) ab, verweigert der Server aufgrund der RSA-Signaturprüfung (`X-Timestamp`-Header) die Synchronisation.
- Das Backend dient als "dummer" Speicher für verschlüsselte Blobs. Es validiert keine Dateninhalte, sondern nur Berechtigungen.
- Tresorname, Benutzername und sonstige Klarnamen werden als SHA256-Hash gespeichert.   
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
5. **RSA-Key übernehmen:**
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
  1. App lädt `User-UUID` und `PublicKey` z.B. von Tinka vom Server.
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

### 2.14 Selbstzerstörung – Warum PriVault diese Funktion nicht umsetzt

Viele Passwortmanager (z. B. mSecure) bieten an, die lokale Datenbank nach einer bestimmten Anzahl fehlgeschlagener 
Login-Versuche zu löschen. PriVault implementiert diese Funktion bewusst nicht, weil sie keinen echten Sicherheitsgewinn
bietet.

**Das strukturelle Problem**

Der Fehlversuchszähler muss lesbar sein, bevor das Passwort bekannt ist – denn genau dann soll er greifen. Was aber 
ohne Passwort lesbar ist, ist ohne Passwort auch **schreibbar**. Der Zähler würde in einer unverschlüsselten 
Konfigurationsdatei (SharedPreferences / Registrierung) liegen. Jeder mit physischem Gerätezugriff kann ihn in Sekunden 
zurücksetzen.

**Die Datenbankdatei kann kopiert werden**

Ein Angreifer mit etwas technischem Verstand kopiert die SQLite-Datei, bevor er den ersten Versuch unternimmt. Die 
Selbstzerstörung löscht nur das Original – die Kopie bleibt erhalten. Danach kann er offline und unbegrenzt Passwörter 
durchprobieren, ohne dass eine App-seitige Schutzfunktion greift.

**Die echte Schutzlinie ist kryptografisch**

PriVault nutzt Argon2id mit 64 MB Arbeitsspeicher, 4 Iterationen und 4-facher Parallelisierung als 
Key-Derivation-Funktion. Jeder Passwortversuch dauert auf einem normalen Rechner mehrere Sekunden; auf einer GPU-Farm 
ist der Angriff wegen der Speicheranforderung (memory-hard) ebenfalls sehr kostspielig. Ein starkes Master-Passwort 
macht Brute-Force praktisch unmöglich – unabhängig davon, ob eine Selbstzerstörungsfunktion existiert.

**Fazit**

Die Selbstzerstörung schützt ausschließlich gegen technisch unerfahrene Angreifer, die direkt in der laufenden App 
tippen, ohne vorher die Datenbankdatei zu sichern. Gegen jeden anderen Angreifer ist sie wirkungslos und vermittelt 
ein falsches Sicherheitsgefühl. PriVault setzt stattdessen auf die Auto-Sperre (Abschnitt 2.16), die den häufigeren 
Angriff – ein unbeaufsichtigtes, entsperrtes Gerät – tatsächlich adressiert.

### 2.15 Timeouts (Auto-Sperre und Zwischenablage leeren)

PriVault bietet zwei gerätespezifische Timeout-Einstellungen, die unabhängig vom Tresor im `ConfigService` (SharedPreferences) gespeichert werden. Da es sich um Geräte-Präferenzen handelt – ein Desktop-Nutzer wählt typischerweise längere Zeitspannen als ein Smartphone-Nutzer – wäre eine Speicherung in der verschlüsselten Tresor-Datenbank falsch: Sie würden beim Sync das Verhalten des anderen Geräts überschreiben.

**Auto-Sperre**

Nach einer konfigurierbaren Inaktivitätsdauer wird der Tresor automatisch gesperrt: Die Session wird gecleart und die App navigiert zur Login-Seite. "Inaktivität" bedeutet, dass der Nutzer keine Pointer- oder Tastaturinteraktion vorgenommen hat.

Technische Umsetzung: Ein `AutoLockService` (GetIt-Singleton) hält einen `Timer`. Ein `Listener`-Widget im Root der App ruft `resetTimer()` bei jeder Benutzeraktion auf. Läuft der Timer ab, werden Session gecleart und per `GlobalKey<NavigatorState>` zur Login-Seite navigiert.

Optionen: Sofort, 1, 2, 3, 4, 5, 10 Minuten, Nie. Default: Nie.

**Zwischenablage leeren**

Nach dem Kopieren eines Passworts oder Benutzernamens wird die Zwischenablage nach einer konfigurierbaren Zeit automatisch geleert. Dies schützt vor passivem Auslesen durch andere Apps (Clipboard-Manager, Sync-Dienste).

Technische Umsetzung: Ein `Timer` im `copyToClipboard()`-Aufruf, der nach der eingestellten Dauer `Clipboard.setData(ClipboardData(text: ''))` aufruft. Bei Tresor-Sperre oder Logout wird ein laufender Timer sofort abgebrochen und die Zwischenablage sofort geleert.

Optionen: 10 s, 30 s, 60 s, 90 s, Nie. Default: 30 s.

**Warum nicht "Sperren bei Sitzungssperre / Deckel zugeklappt"**

Flutter's `AppLifecycleState` unterscheidet nicht zwischen "App minimiert" und "Bildschirmsperre" — beide Ereignisse liefern denselben Lifecycle-State. Um echte Sitzungssperren gezielt zu erkennen, wären native Platform-Channels nötig: auf Android ein `BroadcastReceiver` für `Intent.ACTION_SCREEN_OFF`, auf Windows ein Win32-Hook auf `WM_WTSSESSION_CHANGE`. Der Implementierungsaufwand ist auf beiden Plattformen erheblich.

Entscheidend ist aber ein Usability-Argument: Das Sperren bei jedem Hintergrundwechsel ist auf dem Smartphone störend — ein kurzer App-Wechsel (z. B. um einen Benutzernamen in einer anderen App nachzuschlagen) würde die Sitzung sofort beenden. Die Auto-Sperre mit frei wählbarer Inaktivitätsdauer deckt den praktisch relevanten Anwendungsfall besser ab, ohne den normalen Nutzungsfluss zu unterbrechen.

### 2.16 Backup, Import & Export
- **Import:** Massenimport bestehender Daten. Folgende Dateiformate werden für den Import unterstützt.
    - PriVault ZIP
   - Bitwarden JSON (Spezifikation: https://gist.github.com/ctrlcmdshft/fe6baead7be858ca08666f34da028163)
   - KeePass XML (2.x) (Spezifikation: https://github.com/keepassxreboot/keepassxc-specs/blob/master/kdbx-xml/rfc.md)
   - 1Password 1PUX (Spezifikation: https://support.1password.com/1pux-format/)
   - CSV (generisch, nicht spezifisch, wie bei KeePassXC)
   - Evtl., bietet KeePassXC an: Proton Pass JSON
   - Evtl., bietet 1Password an: Dashlane, LastPass, RoboForm
   - Wird NICHT unterstützt, weil Anhänge nicht enthalten sind: mSecure 6 CSV 
- **Export/Backup:** Unverschlüsselter Export (mit Warnhinweis) zur Datenportabilität oder verschlüsselter Export als Backup 
   - Format: Standard Zip-Archiv 
     - Datendatei: export.json (ähnlich wie Bitwarden, Binärdaten sind aber nicht eingebettet); oder export.csv (Excel-Kompatibel, Vorteil: leicht einsehbar/editierbar)
     - Dateianhänge unter files (Vorteil: man kann sie direkt öffnen)
     - Kann verlustfrei importiert werden.
- **HTML-/ oder PDF-Ausdruck:** Generierung eines Dokuments mit dem verschlüsselten Private-Key und dem Master-Passwort 
   (als Platzhalter zum Ausfüllen) zum physischen Ausdruck. Siehe KeePaxxXC, Exportieren -> HTML-Datei.
   - Evtl im eingebetteten Webbrowser 

### 2.17 Report

Der Sicherheitsbericht analysiert alle Einträge des Tresors und gliedert sich in vier Abschnitte:

- **Darknet-Check (HaveIBeenPwned):** Prüfung jedes Passworts per k-Anonymitäts-Modell (SHA-1-Präfix). Das Passwort verlässt das Gerät niemals im Klartext. Einträge mit kompromittierten Passwörtern werden mit Trefferanzahl aufgelistet (ein Klick öffnet die Detailseite).
- **Top 10 – Älteste Passwörter:** Einträge mit bekanntem Passwort-Datum, sortiert nach Alter. Farbliche Kennzeichnung (grün → rot).
- **Unbekanntes Passwort-Alter:** Einträge ohne Datum der letzten Passwortänderung (max. 10 angezeigt, Hinweis auf weitere).
- **Passwort-Altersverteilung:** Balkendiagramm mit Buckets (< 30 T., 30–90 T., 90–180 T., 180 T.–1 J., > 1 Jahr, Unbekannt).

**HIBP-Cache:** API-Antworten werden per SHA-1-Präfix lokal gecacht (Datei `hibp_cache.json` im App-Verzeichnis). Die Cache-Gültigkeit ist konfigurierbar (Standard: 1 Tag, Einstellung `hibp_cache_days` im `ConfigService`).

### 2.18 Anzeigen, Suche und Filterung der Einträge

Die Hauptseite listet alle Einträge des Tresors auf und ermöglicht eine Volltextsuche über
Kategorie, Titel, URL und Notizen. Da die SQLite-Datenbank der Web-Appliance technisch bedingt
unverschlüsselt im lokalen Speicher des Browsers abgelegt wird (eine Verschlüsselung der
Datenbankdatei ist im Browser-Umfeld nicht möglich), dürfen keine Klartextfelder persistent
gespeichert werden.

**Lösung: Lokales `encryptedIndex`-Feld**

Jeder Eintrag besitzt neben `encryptedData` (dem sync-fähigen, RSA-verschlüsselten Payload) ein
zweites verschlüsseltes Feld: `encryptedIndex`. Es enthält ein kleines JSON-Objekt mit den für
die Listenansicht und Suche benötigten Feldern (Kategorie, Titel, URL, Notizen, Favicon).

Eigenschaften von `encryptedIndex`:
- Verschlüsselung: AES-256-GCM, identisch zu `encryptedData`
- **Wird nicht synchronisiert** und nicht mit Freunden geteilt
- **Key-Ableitung:** Der AES-Schlüssel (`indexKey`) wird deterministisch per HKDF-SHA256 aus dem
  RSA-Private-Key abgeleitet (`info = 'entry-index-encryption'`), analog zur Freundesliste.
  Er muss daher nicht gespeichert werden und ist nach jedem Login sofort reproduzierbar.
- Der `indexKey` wird einmalig nach dem Login im `SessionService` gecacht.

**Lebenszyklus:**
- **Erstellen/Bearbeiten:** `encryptedIndex` wird zusammen mit `encryptedData` lokal geschrieben.
- **Pull-Sync:** Nach dem Herunterladen eines Eintrags wird `encryptedData` ohnehin entschlüsselt
  (um Kategorie, Titel etc. zu extrahieren). Dabei wird `encryptedIndex` direkt mitgeschrieben.
- **Notfall-Reset (Key Rotation):** Der RSA-Key wechselt → `indexKey` ändert sich → alle lokalen
  `encryptedIndex`-Felder werden nach dem Reset neu verschlüsselt. Da das Feld nicht gesynct
  wird, ist dies eine reine Lokaloperation.

**Suche und Filterung:**

Beim Öffnen des Tresors werden alle `encryptedIndex`-Felder entschlüsselt und die extrahierten
Daten im RAM gehalten (`MainNotifier._allEntries`). Suche und Filterung finden ausschließlich im
Code statt, nicht per SQL. Für die zu erwartenden Tresorgrössen (typischerweise unter 1000
Einträge) ist das performant.


### 2.19 Tresor löschen

Der Benutzer hat drei Löschoptionen, wählbar über einen Dialog in den Einstellungen:

- **Nur auf dem Server löschen:** Die Serverdaten werden gelöscht, `lastSyncAt` wird auf den Epoch-Wert zurückgesetzt (entspricht "noch nie synchronisiert"). Beim nächsten Sync wird der Tresor unter dem aktuellen lokalen Namen neu auf dem Server registriert. Nützlich, um die Serverseite zu bereinigen, ohne lokale Daten zu verlieren.
- **Nur auf diesem Gerät löschen:** Die lokale Datenbankdatei wird gelöscht. Die Daten auf dem Server bleiben erhalten.
- **Server und Gerät löschen:** Beides wird entfernt.

**Server-Löschlogik (Mandantentrennung):**
Wenn der Benutzer Serverdaten löscht, muss unterschieden werden, ob er der einzige Benutzer im Tresor ist:
- **Letzter Benutzer im Tresor:** Der gesamte Tresor wird gelöscht (kaskadierend: alle Einträge, Permissions, Anhänge, Tombstones).
- **Nicht der letzte Benutzer:** Nur der eigene Benutzer-Datensatz wird gelöscht. Der Tresor und die Daten der anderen Benutzer bleiben erhalten. Geteilte Einträge, auf die der Benutzer Zugriff hatte, verlieren lediglich seine Permission.

### 2.20 Tresor umbenennen

**Verhalten:** Eine Tresor-Umbenennung ist eine rein lokale Operation. Die Datenbankdatei und der Config-Eintrag werden umbenannt. Der Server erfährt zunächst nichts davon.

**Was beim nächsten Sync passiert:**
Beim nächsten Sync sucht der Client den Benutzer unter dem neuen Tresornamen auf dem Server (`findUser(newVaultName, userName)`). Der Server kennt diesen Namen noch nicht → der Client registriert den Benutzer unter dem neuen Tresornamen neu. Auf dem Server entsteht ein neuer, leerer Tresor. Alle Einträge werden beim folgenden Push vollständig hochgeladen.

**Was mit den alten Serverdaten passiert:**
Die Daten unter dem alten Tresornamen bleiben auf dem Server unverändert erhalten. Der Benutzer muss sie explizit löschen (Option "Nur auf dem Server löschen" in 2.19), wenn er das möchte.

**Hinweis-Dialog bei der Umbenennung:**
Wurde der Tresor bereits synchronisiert (`lastSyncAt > Epoch`), erhält der Benutzer beim Umbenennen einen Hinweis: *"Die Daten auf dem Server verbleiben unter dem bisherigen Tresornamen. Wenn du sie löschen möchtest, nutze vorher die Option 'Nur auf dem Server löschen' in den Einstellungen (s. 2.19)."*

**Warum dieser Ansatz statt eines `PATCH /vaults/name`-Endpunkts?**
Ein Rename-Endpunkt würde einen neuen RSA-geschützten Endpunkt, eine Schemaänderung (Rename-Erkennung auf dem Server) und komplexe Zweitgerät-Koordination erfordern. Der gewählte Ansatz ist einfacher und transparent: Der Tresorname ist dem Server ohnehin nur als anonymer Hash bekannt — für den Server ist der "neue" Tresor einfach ein neuer Mandant.

**Konsequenz für Zweites Gerät:**
Gerät 2 synct weiterhin mit dem alten Tresornamen, solange es nicht lokal umbenannt wird. Beide Geräte sind damit nach einer einseitigen Umbenennung auf verschiedenen Servermandanten. Das ist bewusst: Der Benutzer muss Gerät 2 selbst umbenennen, wenn er beide vereinheitlichen will.

### 2.21 Benutzernamen ändern

**Verhalten:** Anders als beim Tresornamen ist der Benutzername öffentlich sichtbar — Freunde sehen ihn. Eine Änderung muss daher auf dem Server propagiert werden.

**Ablauf:** Die Namensänderung wird lokal gespeichert. Beim nächsten Sync erkennt der Client, dass der lokale Name vom gesyncten Namen abweicht, und sendet den neuen Hash per `PATCH /users/{userUuid}/name` an den Server. Freunde sehen den neuen Namen nach ihrem nächsten Sync.

**Warum nicht den Namen einfrieren (wie beim Tresornamen)?**
Beim Tresornamen gibt es keine andere Person, die den Namen sieht — er ist rein lokal relevant. Der Benutzername hingegen ist der einzige Bezeichner, unter dem andere Benutzer eine Person auf dem Server suchen und finden können. Eine unsichtbare Umbenennung wäre für Freunde verwirrend und würde das Hinzufügen-per-Name funktional brechen.

**`syncedName` in der Users-Tabelle:**
Dieses Feld speichert den Benutzernamen, unter dem diese Person auf dem Server aktuell bekannt ist*.
- Für den Besitzer (`id == 1`): wird diese Information benötigt, um zu wissen, ob beim Sync der neue Name übermittelt werden muss (`name != syncedName` → `patchUserName` aufrufen).
- Für Freunde (`id > 1`): Um in der UI ein entsprechender Hinweis in der Freundeliste anzuzeigen (`name != syncedName` → "Bobby (ehemals Bob)".

---

## 3. Versionierung

### 3.1 App-Version
Wird in  `pubspec.yaml` gespeichert.
- Format `MAJOR.MINOR.PATCH` gemaß dem **Semantic Versioning-Schema** [SemVer](https://semver.org/):
   - MAJOR: Wird mit einem Redesign oder bei einem Migrations-Bruch erhöht.
   - MINOR: Wird mit einer Funktionsänderung erhöht und mit einer neuen Hauptversion auf 0 zurückgesetzt.
   - PATCH: Wird mit einer Fehlerbehebung (Bugfix) erhöht und mit einer neuen Nebenversion auf 0 zurückgesetzt.
- Buildnummer: Wird (theoretisch) mit jedem Build erhöht. Sie wird niemals zurückgesetzt. Dies ist auch der `versionCode` 
  für den Google-Store. 

Angezeigte App-Version inkl. Buildnummer (aber ohne Patch-Nummer): z.B. "1.0+42")
 
### 3.2 Datenbank-Schema-Version
- DB-Schema des Servers: Wird auf dem Server in der Tabelle `verions` gespeichert (ein Integer).
- DB-Schema des Tresors: Flutter nutzt zur Speicherung der Datenbank-Schema-Version den Standard-Mechanismus von SQLite: 
   Jede SQLite-Datenbankdatei hat einen Header-Bereich, in dem Metadaten gespeichert werden. 
   Eines dieser Felder ist die `user_version`, eine 32-Bit-Ganzzahl, die für genau diesen Zweck vorgesehen ist: 
   Die Version des Anwendungsschemas zu speichern.

Sollte die App eine ältere DB-Schema-Version öffnen, wird die DB automatisch aktualisiert.
Sollte die App eine neuere Datenbank öffnen, wird ein Hinweis mit der Bitte um Upgrade der App angezeigt und die DB 
sofort wieder geschlossen.

### 3.3 Sync‑Protokollversion
- Sync‑Protokollversion des Servers: Wird auf dem Server in `config.php` gespeichert.
- Kleinste vom Server unterstützte Protokollversion: Wird auf dem Server in `config.php` gespeichert.
- Sync‑Protokollversion der App: Wird im Code gespeichert. 
 
Vor der Synchronisation wird die Protokollversion der App mit der Protokollversion des Servers verglichen:
   - Wenn client.syncProtocolVersion < server.minSupportedSyncProtocol → App zu alt
   - Wenn client.syncProtocolVersion > server.currentSyncProtocol → Server zu alt

### 3.3 Host-URLs
- https://privault.frank-rohling.de/api (für MAJOR = 1)
- https://privault{MAJOR}.frank-rohling.de/api (für MAJOR > 1)

---

## 4. Identifikatoren: UUIDs und Hashes

Dieses Kapitel beschreibt, wie Tresore, Benutzer und Einträge eindeutig identifiziert werden. 

---

### 4.1 Wozu Hashwerte?

Tresorname und Benutzername sind Klarnamen. Der Sync-Server soll diese Klarnamen **nie** erfahren — er darf ausschließlich kryptografische Hashwerte speichern und vergleichen.

- `vaultHash = SHA256(vaultName)`
- `userHash = SHA256(userName)`

Da SHA256 eine Einwegfunktion ist, kann der Server aus dem Hash den Klarnamen nicht rekonstruieren. Trotzdem kann er prüfen, ob ein Tresor oder Benutzer bereits registriert ist, und Suchanfragen wie "Gibt es Benutzer X in Tresor Y?" beantworten.

Der Client berechnet die Hashes lokal und schickt sie an den Server. Der Server speichert und vergleicht nur Hashes. Klarnamen verlassen das Gerät nie.

---

### 4.2 Vault-UUID

**Wer erzeugt sie:** Der Server, beim ersten `registerUser`-Aufruf, wenn der Tresor noch nicht existiert.

**Warum der Server, nicht der Client?**
Der Client kommuniziert mit dem Server ausschließlich über `vaultHash` als Tresor-Identifikator. Die `vaultUuid` ist ein reines Server-Interna-Konzept: Sie ist der Primärschlüssel für die Mandantentrennung in der Serverdatenbank (`entries`, `users`, `permissions`, `tombstones` sind alle über `vault_uuid` partitioniert). Der Client kennt und braucht sie nicht — er routet immer über seinen `userUuid`, aus der der Server die `vault_uuid` ableitet.

**Mandantentrennung:**
Zwei Tresore sehen sich gegenseitig nie. Jede Datenbankabfrage auf dem Server filtert auf `vault_uuid`. Das ist der Kern der Mandantenisolation.

**Stabilität:**
Die `vaultUuid` ändert sich nie — auch nicht bei Umbenennung des Tresors (s. 2.19). Deshalb ist sie der geeignete Primärschlüssel auf dem Server: stabil, unabhängig vom Namen.

---

### 4.3 User-UUID

**Wer erzeugt sie:** Der Client, zufällig (UUID v4), beim Anlegen des Tresors — noch vor dem ersten Serverkontakt (Offline-first).

**Eindeutigkeit:** Die `userUuid` ist eindeutig pro Tresor-Benutzer-Kombination. Legt ein Benutzer zwei Tresore an, hat er zwei verschiedene `userUuid`s.

**Warum nicht deterministisch aus dem Benutzernamen?**
Ein deterministischer Ansatz (`userUuid = f(userName)`) würde bedeuten: wenn der Benutzer seinen Namen ändert, ändert sich die UUID. Da aber Freunde und Zweitgeräte die UUID als stabilen Fremdschlüssel verwenden (in `permissions`, im `FriendPayload`), würde eine UUID-Änderung alle diese Verknüpfungen zerreißen. Stabilität und Namensänderbarkeit lassen sich mit einem deterministischen Ansatz nicht gleichzeitig erfüllen.

**Warum nicht tresorübergreifend eindeutig (eine UUID für alle Tresore eines Benutzers)?**
Analysiert und verworfen: Es gibt keinen praktischen Vorteil für den Benutzer. Im Gegenteil entsteht ein Sicherheitsnachteil — eine globale UUID wäre eine Korrelations-ID, mit der ein Angreifer mit Zugriff auf zwei Tresore erkennen könnte, dass dieselbe Person in beiden aktiv ist. Das verletzt das Mandantentrennungsprinzip. Zusätzlich wäre ein neuer Auth-Header (`X-Vault-Hash`) und eine komplexere Server-Architektur nötig — ohne messbaren Mehrwert für den Nutzer.

**Zweitgerät (Adoption):**
Das Zweitgerät erzeugt beim Tresor-Anlegen ebenfalls eine zufällige `userUuid`. Beim ersten Sync findet der Server denselben `userHash` in demselben Tresor und liefert die bereits registrierte `userUuid` zurück. Das Zweitgerät übernimmt diese UUID (Adoption, s. 2.5). Danach sind beide Geräte unter derselben UUID bekannt.

---

### 4.4 Entry-UUID

**Wer erzeugt sie:** Der Client, zufällig (UUID v4), beim Erstellen eines neuen Eintrags.

**Bei Import aus Fremdformaten** (Bitwarden, KeePass, 1Password, CSV): Die UUID wird, sofern im Quellformat vorhanden, vom Quellsystem übernommen. Andernfalls wird sie deterministisch generiert oder neu vergeben.

**Bei Import aus dem PriVault-eigenen ZIP-Format** (Backup/Recovery): Die UUID aus der Exportdatei wird beibehalten. Das ermöglicht einen verlustfreien Round-Trip: Export → Import erzeugt denselben Datenbestand, und ein zweiter Import desselben Backups erzeugt Updates statt Duplikate (Last-Write-Wins greift auf denselben Schlüssel).

**Warum auch beim PriVault-Import keine neue UUID vergeben?**
Wenn beim Import immer neue UUIDs vergeben würden, wäre das Backup/Recovery-Szenario (Tresor exportieren → Tresor importieren) nicht idempotent. Jeder Import würde die Einträge duplizieren. Das ist für einen Passwort-Manager inakzeptabel.

**Konsequenz: entryUuid ist nur innerhalb eines Tresors eindeutig.**
Da dasselbe Backup in zwei verschiedene Tresore importiert werden kann, kann dieselbe `entryUuid` auf dem Server in zwei verschiedenen Tresoren vorkommen. Der Unique-Constraint auf dem Server lautet daher `UNIQUE(entry_uuid, vault_uuid)` — nicht global auf `entry_uuid` allein. Ein globaler Unique-Constraint würde beim Sync des zweiten Tresors mit 403 scheitern, obwohl die Operation korrekt ist.

---

### 5.5 Warum zusammengesetzter Primärschlüssel statt Auto-Inc-IDs?

**Ausgangslage:**
Durch die vault-scoped Eindeutigkeit der `entryUuid` (s. 4.4) entstehen auf dem Server mehrere zusammengesetzte Primärschlüssel:

- `entries`: PK `(uuid, vault_uuid)`
- `permissions`: PK `(entry_uuid, user_uuid, vault_uuid)`
- `tombstones`: PK `(entry_uuid, vault_uuid)`

Die Frage stellt sich, ob es sauberer wäre, stattdessen interne Auto-Inc-IDs (`id BIGINT AUTO_INCREMENT`) als PKs einzuführen.

**Argument für Auto-Inc-ID (Surrogate ID):**
Einspaltiger FK überall — kleiner, schneller, auf den ersten Blick einfacher. Standard-Muster in vielen relationalen Systemen. Integer-PKs benötigen weniger Speicher als VARCHAR(36)-Composites (8 Bytes vs. 72+ Bytes).

**Warum ein zusammengesetzter Primärschlüssel (Composite Key) die richtige Wahl ist:**

Auto-Inc-IDs lösen das Problem nicht — sie verlagern es nur. Ein `id`-Feld auf `entries` würde den UNIQUE-Constraint `(uuid, vault_uuid)` nicht ersetzen, sondern ergänzen: Die Geschäftsregel (*eine UUID darf pro Tresor nur einmal vorkommen*) muss trotzdem als separater Unique-Constraint im Schema abgebildet werden. Das Ergebnis wäre ein technischer PK *und* ein fachlicher Composite-Unique — mehr Komplexität, nicht weniger.

Hinzu kommt: `vault_uuid` müsste in `permissions` trotzdem erhalten bleiben, weil der Server bei jeder Operation den Tresor-Kontext kennen muss. Würde man `vault_uuid` aus `permissions` entfernen, bräuchte jede Query einen zusätzlichen JOIN durch `entries`, nur um die `vault_uuid` zu ermitteln.

Die Composite Keys sind also keine Notlösung, sondern die direkte Abbildung der fachlichen Invariante im Schema. Sie transportieren die Geschäftslogik in die Datenbankstruktur und machen fehlerhafte Queries — die z.B. nur auf `entry_uuid` ohne `vault_uuid` filtern — strukturell unmöglich.

**Maßstab:**
PriVault ist kein Hochlast-System. Ein typischer Tresor hat 100–2000 Einträge. Der Performanceunterschied zwischen einem 72-Byte-Composite-FK und einem 8-Byte-Integer-FK ist bei dieser Datenmenge vollständig irrelevant.