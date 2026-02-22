# 02 Kryptografie

Dieses Dokument beschreibt anerkannte kryptografische Verfahren. Ziel ist es, die Sicherheitsmechanismen so zu erklären, 
dass sie ohne tiefgreifende Kryptografie-Kenntnisse implementiert und gewartet werden können.

---

## 1. Verschlüsselungsverfahren

### 1.1 AES
- Symmetrische Verschlüsselung (Hin- und rückwärts mit demselben Schlüssel)
- **Einsatz:** Verschlüsselung der eigentlichen Daten (Passwörter, Notizen, Dateien) und des "Wrapped Private Key".
- **Warum:** Extrem schnell, sicher und effizient für große Datenmengen.

### 1.2 RSA
- Asymmetrische Verschlüsselung
- **Einsatz:** Zum Teilen von Passwörtern und zum Sichern des symmetrischen Keys.
- **Private Key:** Liegt **nur** auf meinen Geräten (verschlüsselt in der DB). Dient zum Entschlüsseln.
- **Public Key:** Liegt auf dem Server, jeder darf damit Daten *für mich* verschlüsseln.
- **Fingerprint:** Ein Hashwert des **RSA-Public-Keys** (meist per SHA-256 generiert).

### 1.3 Hybrid-Verschlüsselung (Envelope Encryption)
Wir kombinieren symmetrische und asymmetrische Verfahren für das Teilen von Einträgen:
1. Der Eintrag wird mit einem zufälligen AES-Key (`Entry-Key`) verschlüsselt.
2. Der `Entry-Key` wird mit dem RSA-PubKey des Empfängers verschlüsselt.
3. Vorteil: Daten müssen beim Teilen nicht neu verschlüsselt werden, nur der winzige Schlüssel.

### 1.3 Kryptografische Hashfunktion

### 1.3.1 SHA-256, SHA‑512
SHA ist eine Hashfunktion.
- Eigenschaften:
  - Deterministisch: Gleicher Input → gleicher Output.
  - Einwegfunktion: Rückrechnen praktisch unmöglich.
  - Feste Länge: 
    - SHA‑256 generiert immer 32 Byte (256 Bit)
    - SHA‑512 generiert immer 64 Byte (512 Bit)
  - Kollisionsresistent: Zwei gleiche Hashes extrem unwahrscheinlich (auch bei SHA‑256)
  - Schnell
- Einsatz: Prüfsummen, Fingerprints, Signatur

### 1.3.2 HKDF‑SHA256
HKDF‑SHA256 ist eine Key‑Derivation‑Function, die SHA‑256 als Baustein nutzt.
- Eigenschaften:
  - Deterministisch: Gleicher Input → gleicher Output.
  - Einwegfunktion: Rückrechnen praktisch unmöglich.
  - Konfigurierbare Länge: Wir wählen 32 Byte.
  - Kollisionsresistent: Zwei gleiche Hashes extrem unwahrscheinlich.
  - Kontexttrennung über das info‑Feld
  - Schnell
  - Eine Variante ist HKDF‑SHA512, aber HKDF‑SHA256 ist Standard und völlig ausreichend (Sicherheitsunterschied praktisch irrelevant).
- Einsatz: Generierung von AES-Schlüssel aus bereits hochentropische (kryptografisch starke) Inputs (z.B. RSA‑Keys)
 
### 1.3.3 Argon2id
Argon2id ist eine passwortbasierte Key‑Derivation‑Function (PBKDF).
- Eigenschaften von Argon2:
  - Deterministisch: Gleicher Input → gleicher Output.
  - Einwegfunktion: Rückrechnen praktisch unmöglich.
  - Konfigurierbare Länge: Wir wählen 32 Byte.
  - Kollisionsresistent: NEIN, zwei unterschiedliche Inputs könnten den gleichen Output generieren.
  - Schutz vor Brute‑Force: Benötigt absichtlich viel RAM‑ und CPU, um Brute‑Force zu erschweren.
  - Argon2id kombiniert Argon2i (gegen Side‑Channel‑Angriffe optimiert) und Argon2d (gegen GPU‑Brute‑Force optimiert)
- Einsatz: Generierung von AES-Schlüssel aus schwache, kurze, menschliche Passwörter

---

## 2. Biometrie (Hardware-basierter Keystore)

Biometrische Merkmale (Fingerabdruck, Gesicht) sind **keine** Passwörter. Sie sind unscharf ("Fuzzy") und können nicht direkt als kryptografischer Schlüssel verwendet werden (da sich der Hash jedes Mal leicht ändern würde).
Stattdessen nutzen wir das **"Key Wrapping"**-Verfahren mit der Hardware-Sicherheitsarchitektur des Geräts (Secure Enclave auf iOS, TEE auf Android).

### 2.2 Aktivierung
**Phase A:** Anna klickt auf "Biometrie aktivieren"
Voraussetzung: Anna hat sich gerade erfolgreich mit ihrem Passwort eingeloggt. Der `Master-Key` (32 Byte AES) liegt im RAM (Arbeitsspeicher).
1. **Zugriff auf den Keystore:** Die App ruft das Betriebssystem (Android Keystore / iOS Keychain):
   *"Erstell mir bitte einen geheimen Schlüssel (nennen wir ihn `Bio-Hardware-Key`). Dieser Schlüssel darf den
   Sicherheitschip NIEMALS verlassen und darf nur benutzt werden, wenn der User seinen Finger authentifiziert."*
2. **Verschlüsselung des Master-Keys:** Die App übergibt den `Master-Key` (aus dem RAM) an den Keystore.
    - Kommando: *"Verschlüssele diese Daten mit dem `Bio-Hardware-Key`."*
    - Der Keystore macht das intern und gibt einen verschlüsselten Datenblob zurück (nennen wir ihn `Biometric-Blob`).
3. **Speichern:** Die App speichert diesen `Biometric-Blob` im persistenten Speicher des Handys (z.B. `SecureStorage` in MAUI oder in der SQL-DB).
4. **Aufräumen:** Der `Master-Key` wird aus dem RAM gelöscht (Zeroing).

### 2.3 Unlock (Login) 
**Phase B:** Anna öffnet die App später nochmal
1. **Start:** App startet. Anna sieht den "Login mit Fingerabdruck"-Button.
2. **Laden:** App lädt den `Biometric-Blob` aus dem Speicher.
3. **Anfrage an Keystore:** App sendet den Blob an den Keystore: *"Bitte entschlüssele diesen Blob mit dem `Bio-Hardware-Key`."*
4. **Die Hardware greift ein (User Interaction):** Der Keystore antwortet der App noch nicht. Stattdessen blendet das Betriebssystem (Android/iOS) den System-Dialog ein ("Bitte Finger auflegen").
    - Anna scannt Finger.
    - Hardware prüft Finger.
    - Wenn OK: Der Chip im Handy gibt den Schlüssel intern frei.
5. **Entschlüsselung:** Der Keystore entschlüsselt den Blob und gibt den **reinen `Master-Key`** an deine App zurück.
6. **Zugriff:** Deine App hat jetzt den `Master-Key` im RAM, genau so, als hätte Anna ihr langes Passwort getippt. Jetzt kannst du die lokale SQLite-Datenbank öffnen und den `Priv_Anna` entschlüsseln.

--- 

## 3 Auto-Fill (Sicheres Übertragen in den Browser)

Um Zugangsdaten sicher in Login-Formulare (Chrome, Safari, Apps) zu übertragen, nutzen wir **keine** Zwischenablage (Clipboard), da diese von anderen Apps ausgelesen werden können. Stattdessen integrieren wir uns als System-Dienst.

### 3.1 Mobile (Android & iOS)**
Hier fungiert das Betriebssystem als vertrauenswürdiger Vermittler (Broker).
- **Android:** `AutofillService`
- **iOS:** `AuthenticationServices` (Credential Provider Extension)

**Der Ablauf:**
1. **Erkennung:** Der User tippt in Chrome auf `amazon.de` in das User-Feld.
2. **Anfrage:** Das OS erkennt das Feld und fragt registrierte Provider (PriVault): *"Hast du Credentials für `amazon.de` (oder Package `com.amazon.mShop`)?"*
3. **Suche:** PriVault (läuft als Hintergrund-Service) prüft die Metadaten der verschlüsselten Datenbank (Indexsuche auf URL).
4. **Authentifizierung:**
   - Falls die DB gesperrt ist, fordert PriVault über das OS eine Biometrie-Freigabe an.
   - PriVault entschlüsselt den Eintrag im geschützten Speicherbereich.
5. **Übergabe:** PriVault baut ein Antwort-Objekt (`Dataset` in Android) und übergibt es direkt an das OS-Framework.
6. **Ausfüllen:** Das OS fügt die Daten in die Ziel-App ein. Die Ziel-App (Browser) sieht die Daten erst in diesem Moment.

### 3.2. Desktop (Windows / macOS)**
Da Desktop-Betriebssysteme kein einheitliches globales Auto-Fill-System für alle Browser bieten, nutzen wir hier zwei Strategien:
- **Variante A (Browser Extension - Empfohlen):**
  Eine schlanke Browser-Erweiterung kommuniziert via **Native Messaging** mit der laufenden PriVault-Desktop-App.
    - Vorteil: Erkennt URL exakt, schützt vor Phishing.
    - Nachteil: Muss für jeden Browser (Chrome, Edge, Firefox) separat bereitgestellt werden.
- **Variante B (Auto-Type - Fallback):**
  Die App simuliert Tastatureingaben.
    - **Ablauf:** User wählt Eintrag -> Klickt "Auto-Type" -> App minimiert sich -> App sendet `User` + `TAB` + `Passwort` + `ENTER` an das zuletzt aktive Fenster.
    - *Sicherheits-Risiko:* Sendet blind an das aktive Fenster (könnte theoretisch abgefangen werden), ist aber universell kompatibel.

---

## 4 Anwendung in PriVault

PriVault nutzt eine mehrstufige Hierarchie, um Sicherheit und Flexibilität (z. B. beim Teilen von Daten) zu kombinieren.

### 4.1: Master-Passwort & Master-Key
- **Input:** Das vom Nutzer gewählte Master-Passwort.
- **Verfahren:** **Argon2id** (Key Derivation Function).
- **Zweck:** Erzeugt aus dem Passwort einen 256-Bit **Master-Key** (mittels AES-256-GCM).
- **Sicherheit:** Ein zufälliges 16-Byte **Salt** pro Benutzer verhindert Rainbow-Table-Angriffe. Argon2id ist speicherintensiv konfiguriert, um Brute-Force-Angriffe (z. B. via GPU) massiv zu verlangsamen.

### 4.2 RSA-KeyPair (Identität / Fingerprint)
Jeder Benutzer besitzt ein RSA-4096-Schlüsselpaar.
- **Private Key:** Wird mit dem **Master-Key** via AES-256-GCM verschlüsselt und in der DB gespeichert. Er dient zum Entschlüsseln des Entry-Keys.
- **Public Key:** Liegt im Klartext auf dem Server. Er ermöglicht es anderen Benutzern, Daten *für diesen Benutzer* zu verschlüsseln.

### 4.3 Envelope Encryption des Entry-Keys
Jeder Tresoreintrag hat einen eigenen, zufällig generierten 256-Bit AES-Schlüssel (den **Entry-Key**), mit dem der eigentliche Inhalt (Payload) verschlüsselt wird.
Das Umschlag-Verfahren ermöglicht das Teilen von diesen verschlüsselten Einträgen:
1. **Verschlüsseln:** Der Payload wird mit dem symmetrischen **Entry-Key** verschlüsselt.
2. **Verpacken:** Der Entry-Key wird für jeden berechtigten Nutzer individuell mit dessen **RSA-Public-Key** verschlüsselt. Diese "Schlüssel-Umschläge" liegen in der Tabelle `permissions`.
3. **Entschlüsseln:** Ein Nutzer lädt den verschlüsselten Payload und seinen persönlichen Umschlag herunter. Er öffnet den Umschlag mit seinem **RSA-Private-Key**, erhält den Entry-Key und entschlüsselt damit die Daten.

### 4.4 Das Zero-Knowledge-Prinzip
Das fundamentale Sicherheitsversprechen von PriVault lautet: **Der Server kennt niemals Daten im Klartext.**
- Alle Verschlüsselungsvorgänge finden auf dem Client statt.
- Der Server fungiert als rein passiver Speicher für verschlüsselte Blobs. Er validiert keine Dateninhalte, sondern prüft lediglich die Authentizität der Anfragen.
- Das Master-Passwort wird niemals über das Netzwerk übertragen.

### 4.5. Speicher-Hygiene (RAM-Management)
In einer Managed-Umgebung wie .NET ist die sichere Löschung von Daten komplex:
- **Strings:** Sind in C# unveränderlich (immutable). Ein Passwort-String verbleibt im RAM, bis der Garbage Collector ihn überschreibt.
- **Byte-Arrays:** Werden für Schlüssel bevorzugt verwendet. Mittels `ICryptoService.WipeKey()` werden sensible Arrays nach Gebrauch explizit mit Nullen überschrieben.
- **UI-Controls:** Um das Risiko zu minimieren, werden Login-Pages nach erfolgreichem Login schnellstmöglich aus dem Speicher entfernt.

---

## 5. Bedrohungsanalyse (Was tun, wenn...) 

| Szenario                       | Risiko                              | Technische Maßnahme                                                           | Benutzer-Maßnahme                                                                           |
|:-------------------------------|:------------------------------------|:------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------|
| **Server Hack**                | Datenbank-Dump wird gestohlen.      | **Zero-Knowledge:** Angreifer sieht nur AES-Blobs. Ohne Passwort/Key wertlos. | Keine Panik. Ggf. Passwort ändern.                                                          |
| **Handy Diebstahl (Gesperrt)** | Zugriff auf lokale DB.              | **Argon2id:** Verlangsamt Brute-Force extrem.                                 | **Notfall-Reset** am PC durchführen (Key Rotation).                                         |
| **Handy Diebstahl (Offen)**    | Zugriff auf unverschlüsselte Daten. | **App-Timeout / Biometrie-Zwang** für kritische Aktionen.                     | Passwörter der Dienste (Amazon, Bank) ändern. Gerät aus "Trusted Devices" entfernen (Kill). |
| **API-Token Leak**             | Server-Flooding / DoS.              | **Rate-Limiting:** Max X neue Einträge pro Stunde. API-Token-Pflicht.         | API-Token auf Server und Clients ändern.                                                    |

a) Android-Handy verloren/gestohlen. App gesperrt.
b) Windows-PC verloren/gestohlen. App gesperrt. Festplatte per Bitlocker verschlüsselt.
c) Windows-PC verloren/gestohlen. App gesperrt. Kein Bitlocker.
d) Handy oder PC verloren/gestohlen. App war offen.
e) Provider des Servers (Hetzner) wurde gehackt
f) API-Token ist bekannt geworden

**a/b/c) Gerät verloren (Verschlüsselt/Gesperrt):**
- **Risiko:** Brute-Force auf die lokale DB.
- **Maßnahme:** Argon2id schützt (Zeitfaktor).
- **Zusatz-Maßnahme:** **Key Rotation (Notfall-Reset)** am verbleibenden Gerät durchführen. Damit wird der geklaute Datenstand "eingefroren". Selbst wenn der Dieb das Passwort knackt, kann er keine *neuen* Änderungen mehr vom Server laden oder entschlüsseln, da der Server nun neue Schlüssel verwendet.

**d) Gerät verloren (App war offen / Dieb hat Zugriff):**
- **Risiko:** Dieb exportiert alle Passwörter im Klartext.
- **Maßnahme:** **Keine technische.** Wenn der Dieb drin ist, ist er drin.
- **Schadensbegrenzung:** Sofortiges Ändern aller wichtigen Passwörter (Banking, E-Mail).
- **App-Schutz:** **Kill-Switch (API-Ebene).** Du löschst den User/Device auf dem Server. Die App auf dem gestohlenen Gerät wird beim nächsten Sync merken "Ich wurde gelöscht" und löscht sich lokal (sofern der Dieb noch online geht).

**e) Hetzner gehackt:**
- **Risiko:** Datenbank-Dump geklaut.
- **Schutz:** Zero-Knowledge. Der Hacker hat nur AES-Blobs. Er braucht dein Master-Passwort UND den Salt (der liegt auch in der DB). Er müsste Brute-Force auf den `EncryptedPrivateKey` machen.
- **Maßnahme:** Keine sofortige nötig, aber PW-Änderung empfohlen.

**f) API-Token bekannt:**
- **Risiko:** DoS (Server voll müllen), Download der verschlüsselten Blobs.
- **Maßnahme:** Ändern des `API_TOKEN` in `config.php` und in den Einstellungen aller Clients.

---

## 6. Angriffs-Szenarien

### 6.1 Szenario "Verlust des Handys (iOS / Android)"

Hier unterscheiden wir zwei Angriffsvektoren: Den forensischen Angriff auf Dateien und den Versuch, die App über die
Oberfläche zu öffnen.

#### 6.1.1 Der forensische Angriff (Datei-Extraktion)

* **Angriff:** Der Dieb schließt das Handy an einen PC an und extrahiert die `sqlite.db`.
* **Schutz:** Die Datenbank ist mit **AES-256 (SQLCipher)** verschlüsselt.
* **Hürde:** Der Dieb muss das Master-Passwort per Brute-Force erraten (Argon2id bremst ihn auf wenige
  Versuche/Sekunde).

#### 6.1.2 Der UI-Angriff (Dieb hat Geräte-PIN)

* **Szenario:** Der Dieb hat dir beim Entsperren über die Schulter geschaut (Shoulder Surfing) und kennt deinen Geräte-PIN (z.B. "2580"). Er entsperrt das Handy und öffnet die PriVault-App.
* **Angriff auf Biometrie:**
    * Die App fragt nach FaceID/Fingerabdruck. Das schlägt fehl (falsches Gesicht).
    * Android/iOS bieten dann oft den **Geräte-PIN als Fallback** an.
    * Gibt der Dieb hier "2580" ein, gibt der Keystore den Schlüssel frei -> **Zugriff erfolgreich.**
* **Schutzmaßnahmen:**
    1. **Starkes Master-Passwort erzwingen:** Biometrie in der App deaktivieren oder so konfigurieren, dass sie *nicht*
       die Geräte-PIN als Fallback akzeptiert (Einstellung: `UserAuthenticationRequired` im Keystore auf `True` setzen –
       das blockiert oft den PIN-Fallback, je nach OS-Version).
    2. **Timeout:** App verlangt zwingend das Master-Passwort (nicht Biometrie) nach z.B. 24 Stunden oder Neustart.
    3. **Selbstzerstörung:** App löscht lokale Daten nach 10 Fehlversuchen.
        * *Hinweis:* Hilft gegen neugierige Finder. Ein Profi kann dies umgehen, indem er vorher das Dateisystem
          kopiert, aber auf einem ungerooteten iPhone/Android ist das Kopieren von App-Daten für Diebe oft schwierig bis
          unmöglich._

### 6.2: Szenario "Verlust des Laptops (Windows)"

Ein Dieb stiehlt den Laptop. Windows ist durch "Windows Hello" (PIN/Gesicht) geschützt.

#### 6.2.1 Der Festplatten-Angriff

* **Angriff:** Dieb baut Festplatte aus.
* **Schutz:** **BitLocker**. Ohne Wiederherstellungsschlüssel sind die Daten Datenmüll. Ist BitLocker *aus*, greift die
  SQLCipher-Verschlüsselung der App (siehe A1).

#### 6.2.2 Der "Schwache Hello PIN"-Angriff

* **Szenario:** Du nutzt eine simple 4-stellige PIN für Windows ("1234"). Der Dieb errät diese.
* **Angriff:**
    * Dieb loggt sich in Windows ein.
    * Er startet PriVault.
    * PriVault fragt nach Biometrie (Hello). Da der Dieb eingeloggt ist, gilt er für Windows oft als "authentifiziert"
      oder er gibt erneut "1234" ein.
    * Der TPM-Chip gibt den Schlüssel frei -> **Zugriff erfolgreich.**
* **Schutz:**
    * **Verantwortung des Users:** Eine starke Windows-PIN / Passwort nutzen!
    * **App-Design:** Kritische Aktionen (Passwort anzeigen/kopieren) sollten eine **erneute** Authentifizierung
      verlangen oder das Master-Passwort (nicht Hello) anfordern ("Re-Prompt").

#### 6.2.3 Selbstzerstörung (Auto-Wipe) unter Windows

* **Funktion:** Löschen der `sqlite.db` nach X Fehlversuchen in der App-Oberfläche.
* **Grenzen:** Unter Windows hat der User (und damit der Dieb) vollen Zugriff auf den Dateimanager.
* **Bypass:** Der Dieb kopiert einfach den Ordner `%AppData%\Privault` an einen sicheren Ort, bevor er anfängt zu raten.
  Wenn die App sich löscht, kopiert er die Datei zurück und probiert weiter.
* **Fazit:** Selbstzerstörung ist auf dem Desktop ein reines Komfort-Feature gegen Neugierige, kein harter Schutz.

### 6.3 Szenario "Hack bei Hetzner"

Der Hacker hat Zugriff auf die Datenbank.

**Schutz:**  
Zero-Knowledge-Architektur. Hetzner speichert nur verschlüsselte Blobs.

**Was der Hacker hat:**
*   `Entries`: Haufenweise AES-verschlüsselter Datenmüll. Ohne Key unknackbar.
*   `Permissions`: Haufenweise RSA-verschlüsselter Datenmüll.
*   `Public Keys`: Die sind öffentlich, bringen ihm aber nichts zum Entschlüsseln.

**Was der Hacker tun kann:**
Er kann Daten **löschen** (Vandalismus). Er kann nichts **lesen**.

---

## 7. Glossar

| Begriff                 | Variable (Code)     | Erklärung                                                                                               |
|:------------------------|:--------------------|:--------------------------------------------------------------------------------------------------------|
| **Tresor / Mandant**    | `Vault` / `VaultId` | Der Container für eine Gruppe von Benutzern (z.B. "Familie"). Definiert den Scope.                      |
| **Master-Passwort**     | `MasterPassword`    | Das Geheimnis im Kopf des Nutzers. Wird nie gespeichert.                                                |
| **Master-Key**          | `MasterKey`         | `Argon2id(Passwort, Salt)`. Der 32-Byte Schlüssel zum Öffnen der lokalen SQLCipher-DB.                  |
| **Salt**                | `Salt`              | Zufallswert pro Benutzer. Öffentlich. Verhindert Rainbow-Tables.                                        |
| **RSA-Schlüsselpaar**   | `KeyPair`           | Die Identität des Nutzers. `Public` liegt auf Server, `Private` liegt verschlüsselt auf Server & lokal. |
| **Entry-Key**           | `EntryKey`          | Ein zufälliger AES-Key (32 Byte), unique pro Eintrag. Damit sind die Daten verschlüsselt.               |
| **Encrypted Entry Key** | `EncryptedKey`      | Der `EntryKey`, verpackt in einen RSA-Umschlag (für einen spezifischen User). Liegt in `permissions`.   |
| **Data Blob**           | `Data`              | Das eigentliche JSON (Passwort, Url...), verschlüsselt mit dem `EntryKey`.                              |
