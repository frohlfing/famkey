# Import-Formate

Folgende Dateiformate werden für den Import unterstützt.

---

## Bitwarden JSON

- Spezifikation: https://gist.github.com/ctrlcmdshft/fe6baead7be858ca08666f34da028163
- Beispieldatei: [Bitwarden JSON KI-generiert.json](Beispieldateien/Bitwarden%20JSON%20KI-generiert.json)

### Voraussetzung

- Die Datei ist mit UTF-8 (Unicode) kodiert.
- Datums-/Zeitangaben sind im ISO 8601-Format [@!RFC3339] angegeben (`YYYY-MM-DDTHH:mm:ss` bzw `YYYY-MM-DDTHH:mm:ssZ`).
- Die JSON-Datei ist unverschlüsselt.

### Mapping

- `url`
  Die UUID ist eine global eindeutige 36 Zeichen lange Zeichenfolge (Universally Unique Identifier v4, z.B. `3a0b4a0c-2b8c-4b0c-9a3e-1f4b2a9c7e12`) und kann direkt übernommen werden.

- `category`:
    - Bitwarden speichert Ordner so:
      ```json
      "folders": [
        { "id": "a1b2c3d4", "name": "Arbeit" }
      ]
      ```
    - Ein Item verweist darauf:
      ```json
      {
        "folderId": "a1b2c3d4",
        "name": "GitHub"
      }
      ```

- `title`, `username`, `password`, `url` `notes`:
  Diese Werte stehen in den jeweiligen Feldern eines Items (alle optional):
  ```json
  {
    "name": "GitHub",
    "login": {
      "username": "frank.dev",
      "password": "SuperPass123!",
      "uris": [
        { "uri": "https://github.com" }
      ]
    },
    "notes": "Zwei-Faktor aktiv."
  }
  ```

- `passwordTimestamp`:
  Bitwarden hat eine Passwort‑Historie:
  ```json
  "passwordHistory": [
    {
      "lastUsedDate": "2025-06-01T00:00:00.000Z",
      "password": "OldPass123"
    }
  ]
  ````
  Es wird der Zeitpunkt der letzten Passwortänderung übernommen.
  Fallback: `item.revisionDate`

- `favicon`:
  Bitwarden speichert keine Favicons.
  Das Favicon wird von der URL heruntergeladen (so, als wenn manuell ein neuer Eintrag angelegt wird).

- `creatorId` und `updaterId`:
  Hier wird de aktuelle angemeldete User genommen (so, als wenn manuell ein neuer Eintrag angelegt wird).

- `updatedAt`:
    - Zeitpunkt der letzten Änderung ist `item.revisionDate`
    - Fallback: `DateTime.now().toUtc()`

- Attachments:
    - Die Meta-Daten werden pro Eintrag angegeben:
      ```json
      "attachments": [
        {
          "id": "att1",
          "fileName": "vertrag.pdf",
          "size": 53211,
          "url": "https://api.bitwarden.com/attachments/att1"
        }
      ]
      ```
        - `uuid`: Wird neu generiert.
        - `filename`: aus `fileName`
        - `mime` wird aus der Dateiendung ermittelt.
        - `size` ergibt sich aus blob.length.
        - `thumbnail`: wird generiert (so, als wenn manuell ein neuer Eintrag angelegt wird)
        - `timestamp`: `item.revisionDate` des Eintrags (Bitwarden speichert KEINEN Timestamp für Dateianhänge).
    - Die Binärdaten sind NICHT eingebettet. Die Dateianhänge werden im Unterordner "attachments" erwartet. Das `url`-Attribute wird ignoriert.

---

## KeePass XML (2.x)

- Spezifikation: https://github.com/keepassxreboot/keepassxc-specs/blob/master/kdbx-xml/rfc.md
- Beispieldatei: [KeePass XML (2.x) KI-generiert.xml](Beispieldateien/KeePass%20XML%20%282.x%29%20KI-generiert.xml)

### Voraussetzung
 
- Die Datei ist mit UTF-8 (Unicode) kodiert.
- Datums-/Zeitangaben sind im ISO 8601-Format [@!RFC3339] angegeben (`YYYY-MM-DDTHH:mm:ss` bzw `YYYY-MM-DDTHH:mm:ssZ`).
- Die Zeichen `< > & " '` sind durch `&lt;` `&gt;` `&amp;` `&quot;` `&apos;` ersetzt.

### Mapping
    
- `url`
  Die UUID ist Base64-kodiert (z.B. `DzqV4eP8VE+rUTDqetpscA==`). Die Dekodierung ergibt 16-Bytes,  
  eine 32 Zeichen lange global eindeutige Hex-Zeichenfolge (im Beispiel `0f3a95e1e3fc544fab5130ea7ada6c70`), 
  mit Bindestrichen (8‑4‑4‑4‑12) ergibt das dann das UUID-v4-Format (`0f3a95e1-e3fc-544f-ab51-30ea7ada6c70`)
  
- `category`:
  Die Kategorie wird von `Group.Name` übernommen.
  
- `title`, `username`, `password`, `url` `notes`:
  Diese Werte stehen in den  `<String>`‑Elementen eines Eintrags, die jeweils einen `<Key>` und einen `<Value>` enthalten. 
  Beispiel:
    ```xml
    <String>
    <Key>Password</Key>
    <Value>SuperPass123!</Value>
    </String>
    ```
  Die exakten Keys sind: `Title`, `UserName`, `Password`, `URL`, `Notes`

- `passwordTimestamp`:
  Der Passwort‑Zeitstempel eines Eintrags ist der `LastModificationTime` des letzten `History`‑Eintrags, der ein Passwort enthält.
  Wenn keine History existiert: Dann ist der Passwort‑Zeitstempel = `LastModificationTime` des Eintrags selbst (aus `Times`).

- `favicon`:
  Das Favicon wird von der URL heruntergeladen (so, als wenn manuell ein neuer Eintrag angelegt wird).
 
- `creatorId` und `updaterId`: 
  Hier wird de aktuelle angemeldete User genommen (so, als wenn manuell ein neuer Eintrag angelegt wird).
  
- `updatedAt`:
  Zeitpunkt der letzten Änderung ist `LastModificationTime` (falls nicht vorhanden: `CreationTime`) des Eintrags (aus `Times`).
  Fallback: `DateTime.now().toUtc()`

- Attachments:
  - Die Binärdaten stehen global in `<Meta><Binaries>` (Base64‑kodiert, optional komprimiert mit `GZip`). Beispiel:
    ```xml
    <Binary ID="0" Compressed="False">VGhpcyBpcyBhIHBkZiBmaWxlLg==</Binary>
    <Binary ID="1" Compressed="True">sGCIFVKpER6BwMinQjSewelKQFBaYbeUZA==</Binary>
    ```
  - Der Eintrag referenziert die Datei über `<Binary>` (`Ref` -> `ID`):
    ```xml
    <Binary>
      <Key>github_backup_codes.pdf</Key>
      <Value Ref="1" />
    </Binary>
    ```
  - `uuid`: Wird neu generiert.
  - `mime` wird aus der Dateiendung ermittelt.
  - `size` ist die Größe der Binärdaten.
  - `thumbnail`: wird generiert (so, als wenn manuell ein neuer Eintrag angelegt wird)
  - `timestamp`: `LastModificationTime` des Eintrags (KeePass speichert KEINEN Timestamp für Dateianhänge).

---

## 1Password 1PUX (8.x)

- Spezifikation: https://support.1password.com/1pux-format/
- Beispieldatei: [1Password 1PUX Offizielles Beispiel.1pux](Beispieldateien/1Password%201PUX%20Offizielles%20Beispiel.1pux)

### Voraussetzung

- Die `.1pux`-Datei ist ein Standard-ZIP-Archiv.
- Das Archiv ist unverschlüsselt.
- Die Hauptdatendatei `export.data` im Archiv ist mit UTF-8 kodiert und JSON-basiert.
- Datums-/Zeitangaben sind im ISO 8601-Format [@!RFC3339] angegeben.

### Mapping

- `uuid`
  Die UUID ist eine global eindeutige 26 Zeichen lange Zeichenfolge (z.B. `a5wucxN2oG24S3tZ2gE5mMUA5A`) und wird aus `item.uuid` übernommen.

- `category`:
  Die Kategorie wird aus dem Namen des Tresors (`vault.name`) übernommen, in dem sich der Eintrag befindet.

- `title`:
  Wird aus dem Feld `item.title` übernommen.

- `username`, `password`, `notes`:
  Diese Werte befinden sich im `fields`-Array eines Items. Sie werden über ihren Zweck (`purpose`) identifiziert.
  ```json
  "fields": [
    { "id": "username", "purpose": "USERNAME", "value": "frank.dev" },
    { "id": "password", "purpose": "PASSWORD", "value": "SuperPass123!" },
    { "id": "notes",    "purpose": "NOTES",    "value": "Zwei-Faktor aktiv." }
  ]
  ```

- `url`:
  Die URL wird aus dem `urls`-Array eines Items übernommen. Es wird die erste URL aus der Liste verwendet.
  ```json
  "urls": [
    { "url": "https://github.com", "primary": true }
  ]
  ```

- `passwordTimestamp`:
  1Password speichert keine separate Passworthistorie im Export.

- `favicon`:
  1Password speichert keine Favicons im Export.

- `updatedAt`:
  Zeitpunkt der letzten Änderung ist `item.updatedAt` (ein Unix-Zeitstempel, z.B. `1585333569`; Fallback: `item.createdAt`)

- Attachments:
    - Die Metadaten der Anhänge befinden sich im `files`-Array eines Items:
      ```json
      "files": [
        {
          "id": "axeeN2oG24S3tZ2gE5m....",
          "name": "vertrag.pdf",
          "size": 53211,
          "path": "files/axeeN2oG24S3tZ2gE5m...._vertrag.pdf"
        }
      ]
      ```
    - Die Binärdaten sind NICHT in der JSON-Datei eingebettet. Der Parser erwartet die Dateien im Unterordner `files` innerhalb des 1PUX-Archivs. 
      Der `path` aus den Metadaten verweist auf die entsprechende Datei.

---

Weitere Formate könnten später hinzukommen. Dann könnte dieses Repo nützlich sein:
https://github.com/roddhjav/pass-import/tree/master
