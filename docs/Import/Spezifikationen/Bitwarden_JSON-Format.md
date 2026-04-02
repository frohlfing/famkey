# Bitwarden JSON-Format

Nachfolgend findest Du eine umfassende Liste aller Felder, die im Bitwarden-JSON-Format für den Import und Export enthalten sein können. Diese Liste basiert auf der Bitwarden-CLI-Dokumentation und dem JSON-Importformat, wie es unter https://bitwarden.com/help/import-data/#bitwarden-import-format angegeben ist.

Quelle: https://gist.github.com/ctrlcmdshft/fe6baead7be858ca08666f34da028163

### Wurzelfelder (Root Fields)
- `encrypted`: Boolean (optional; z. B. `false` für unverschlüsselt, normalerweise in Organisations-Exports vorhanden).
- `folders`: Array von Ordner-Objekten (persönliche Tresore; leer `[]` oder weggelassen bei Organisations-Tresoren).
- `collections`: Array von Sammlungs-Objekten (Organisations-Tresore; leer `[]` oder weggelassen bei persönlichen Tresoren).
- `items`: Array von Eintragsobjekten (erforderlich; die eigentlichen Tresordaten).

### Ordnerobjekt-Felder (im `folders` Array)
- `id`: String (UUID, erforderlich für die Referenzierung in Einträgen, z.B. `12345678-1234-1234-1234-1234567890ab`).
- `name`: String (erforderlich).

### Sammlungsobjekt-Felder (im `collections` Array, nur Organisations-Tresore)
- `id`: String (UUID, erforderlich, z.B. `12345678-1234-1234-1234-1234567890ab`).
- `organizationId`: String (UUID, erforderlich, z.B. `12345678-1234-1234-1234-1234567890ab`).
- `name`: String (erforderlich).
- `externalId`: String oder null (optional).

### Eintragsobjekt-Felder (im `items` Array)

#### Allgemeine Felder (alle Eintragstypen)
- `id`: String (UUID, optional; wird beim Import automatisch generiert, falls weggelassen, z.B. `12345678-1234-1234-1234-1234567890ab`).
- `organizationId`: String oder null (erforderlich für Organisations-Einträge, null für persönliche Einträge).
- `folderId`: String oder null (referenziert die Ordner-ID, nur für persönliche Tresore).
- `type`: Integer (erforderlich; 1 = Anmeldung, 2 = Sichere Notiz, 3 = Karte, 4 = Identität).
- `reprompt`: Integer (optional; 0 = keine erneute Abfrage, 1 = erneute Abfrage des Master-Passworts; Standard ist 0).
- `name`: String (erforderlich).
- `notes`: String oder null (optional; wird für Notizen verwendet, insbesondere bei "Sicheren Notizen").
- `favorite`: Boolean (optional; z. B. `true` oder `false`).
- `fields`: Array von benutzerdefinierten Feld-Objekten (optional). Jedes Feld-Objekt enthält:
    - `name`: String (erforderlich).
    - `value`: String (erforderlich).
    - `type`: Integer (erforderlich; z. B. 0 = Text, 1 = Verborgen, 2 = Boolean, 3 = Verknüpft).
- `collectionIds`: Array von Strings oder null (nur Organisations-Tresore; referenziert Sammlungs-IDs).
- `revisionDate`: String (ISO 8601, optional; z. B. `"2025-10-24T12:00:00.000Z"`).
- `creationDate`: String (ISO 8601, optional; z. B. `"2025-01-01T00:00:00.000Z"`).
- `deletedDate`: String oder null (optional; ISO 8601 oder null).
- `passwordHistory`: Array von Passworthistorie-Objekten (optional). Jedes Objekt enthält:
    - `lastUsedDate`: String (ISO 8601, erforderlich; z. B. `"2025-06-01T00:00:00.000Z"`).
    - `password`: String (erforderlich).

#### Typ-spezifische Unterobjekt-Felder
Jeder Eintrag enthält genau ein typ-spezifisches Unterobjekt, basierend auf seinem `type`-Wert. Diese können für minimale Importe leer sein `{}`, enthalten aber in vollständigen Exports zusätzliche Felder.

1. **Anmeldung (`type: 1`, Unterobjekt: `login`)**
    - `username`: String oder null (optional).
    - `password`: String oder null (optional).
    - `totp`: String oder null (optional; TOTP-Seed für Zwei-Faktor-Authentisierung).
    - `uris`: Array von URI-Objekten (optional). Jedes URI-Objekt enthält:
        - `uri`: String (erforderlich).
        - `match`: String oder null (optional; URI-Übereinstimmungstyp, z. B. "default", "host").

2. **Sichere Notiz (`type: 2`, Unterobjekt: `secureNote`)**
    - Keine Felder erforderlich (immer `{}`; der Inhalt wird im übergeordneten Feld `notes` gespeichert).

3. **Karte (`type: 3`, Unterobjekt: `card`)**
    - Keine Felder für minimalen Import erforderlich (`{}`), aber vollständige Exports können enthalten:
        - `cardholderName`: String oder null (optional).
        - `brand`: String oder null (optional; z. B. "Visa").
        - `number`: String oder null (optional).
        - `expMonth`: String oder null (optional).
        - `expYear`: String oder null (optional).
        - `code`: String oder null (optional; CVV-Code).

4. **Identität (`type: 4`, Unterobjekt: `identity`)**
    - Keine Felder für minimalen Import erforderlich (`{}`), aber vollständige Exports können enthalten:
        - `title`: String oder null (optional).
        - `firstName`: String oder null (optional).
        - `middleName`: String oder null (optional).
        - `lastName`: String oder null (optional).
        - `address1`: String oder null (optional).
        - `address2`: String oder null (optional).
        - `address3`: String oder null (optional).
        - `city`: String oder null (optional).
        - `state`: String oder null (optional).
        - `postalCode`: String oder null (optional).
        - `country`: String oder null (optional).
        - `phone`: String oder null (optional).
        - `email`: String oder null (optional).
        - `username`: String oder null (optional).

### Hinweise
- **Mindestanforderungen**: Für Einträge sind beim Import nur `type`, `name` und ein leeres typ-spezifisches Unterobjekt (z. B. `"login": {}`) erforderlich. Andere Felder sind optional, werden aber in Exports einbezogen, wenn sie vorhanden sind.
- **Ausgeschlossene Felder**: Anhänge sind in JSON-Exporten/-Importen nicht enthalten; verwende das Format `--format zip` für Anhänge.
- **Verschlüsseltes JSON**: Wenn `--format encrypted_json` verwendet wird, ist die gesamte JSON-Struktur verschlüsselt, aber das Schema bleibt nach der Entschlüsselung dasselbe.
- **Kontextspezifische Felder**:
    - `folders` und `folderId` werden nur in Exporten/Importen für persönliche Tresore verwendet.
    - `collections`, `collectionIds` und `organizationId` werden nur in Exporten/Importen für Organisationen verwendet.

Diese Liste wurde aus der Bitwarden-Importformat-Dokumentation und dem Verhalten des CLI-Exports abgeleitet, um sicherzustellen, dass alle möglichen Felder abgedeckt sind. Wenn Du einen bestimmten Teilbereich oder weitere Erläuterungen benötigst, sag mir einfach Bescheid!