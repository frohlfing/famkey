# 05 API-Spezifikation

* **Service:** PriVault v1 REST-API 
* **Sync-Protokollversion:** 1
* **Datum:** 09.03.2026
* **Autor:** Frank Rohlfing
 
## 1. API-Token

Der Zugriff wird durch einen globalen API-Token gesichert.
Jeder Request muss den API-Token mitliefern. Bevorzugt im Header per `Bearer`:
```http
Authorization: Bearer {api_token}
```
```shell
curl https://{host}/api/users \
  -H "Authorization: Bearer {api_token}"
```

Kompatibilität ist zusätzlich gegeben über:

- Custom Header: `X-API-Token: {api_token}`  (verbreitet, aber nicht standardisiert)
  ```shell
  curl https://{host}/api/users \
    -H "X-API-Token: {api_token}" 
  ```
  
- Query-Parameter: `?api_token={api_token}`  (weniger sicher, da der Token in Logs zu sehen sein könnte)
  ```shell
  curl https://{host}/api/users?api_token={api_token}
  ```
  
- Basic Auth (Passwort = API-Token. klassisch für User/Passwort, aber nicht Best Practice für Tokens)
  ```shell
  curl https://{host}/controller/users \
    -v -u :{api_token} 
  ```
  `curl` überträgt den -u-Parameter `username:password` Base64‑kodiert im Header `Authorization: Basic`:,
  ```shell
  curl https://{host}/controller/users \
    -H "Authorization: Basic amRvZUBleGFtcGxlLmNvbTpwYSQkdzByZA=="
  ```

Fehlt der Token oder ist er falsch, antwortet der Server mit `401 Unauthorized`.

* Beispiel mit Curl:
    ```shell
    curl /version
      -H "Authorization: Bearer {api_token}"
    ```

## 2. RSA-Signatur

Die Identität des Benutzers wird durch eine kryptografische RSA-Signatur bewiesen.
Für geschützte Endpunkte sind folgende Header zwingend erforderlich:
- `X-User-Uuid`: Die UUID des anfragenden Benutzers.
- `X-Timestamp`: Aktuelle Unix-Zeit (UTC). Maximal 5 Minuten Abweichung zulässig.
- `X-Signature`: RSA-Signatur (Base64) über den String `{user_uuid}:{timestamp}` (Padding: PKCS#1 v1.5).

## 3. Rate-Limit

Die Anzahl der Anfragen ist aus Sicherheitsgründen pro Zeitraum limitiert.
Nur eine bestimmte Anzahl von Anforderungen pro Zeitfenster ist zulässig.

Im Antwortheader werden das Rate-Limit, das Restkontingent und Restzeit angegeben:

```
X-RateLimit-Limit: 60      # Schwelle
X-RateLimit-Remaining: 8   # Restkontingent
X-RateLimit-Reset: 12      # Sekunden bis Reset
```

Dies bedeutet:
- Max. 60 Requests pro Zeitfenster sind möglich.
- Es sind noch 8 Requests im aktuellen Zeitfenster übrig.
- In 12 Sekunden wird das Kontingent wieder zurückgesetzt.

Im Debug-Modus (DEBUG=true) kann `X-RateLimit-Limit` mittels Request-Header überschrieben werden (0 == kein Limit).
Das Zeitfenster beträgt 1 Minute.

## 4. Statuscodes

**200er-Bereich:** Die Anfrage war erfolgreich.
- 200 - OK: Die Abfrage der Ressource war erfolgreich.
- 201 - Created: Die Ressource wurde erfolgreich erstellt.
- 204 - No Content: Die Antwort beinhaltet keine Daten (z.B. bei der Löschung einer Resource).
- 206 - (*) Partial Content: Die Antwort beinhaltet nur einen Teil der angefragten Liste.

**400er-Bereich:** Die Anfrage war nicht erfolgreich.
- 400 - Bad Request: Die Anfrage ist fehlerhaft aufgebaut (Syntaxfehler in JSON).
- 401 - Unauthorized: Fehlender/ungültiger API-Token oder RSA-Signierung
- 403 - Forbidden: Fehlende Berechtigung
- 404 - Not Found: Die Angefragte Resource wurde nicht gefunden.
- 405 - Method Not Allowed: Die angegebene HTTP-Methode ist für die Resource nicht erlaubt.
- 409 - Conflict: Eine neue Resource soll angelegt werden, existiert aber bereits.
- 413 - Payload Too Large: Payload ist zu groß (z. B. Attachment-Upload).
- 422 - Unprocessable Entity: Pflichtfelder fehlen/ungültig.
- 429 - Too Many Requests: Wenn das Rate-Limit (z. B. >200 Einträge/h) überschritten wurde.

**500er-Bereich:** Ein Ausnahmefehler ist aufgetreten.
- 500 - Internal Server Error: Unerwarteter Serverfehler.
- 501 - (*) Not Implmented: Die Funktion befindet sich noch in der Entwicklung.
- 503 - (*) Service Unavailable: Service momentan nicht verfügbar (aufgrund geplanter Wartungsarbeit).

(*) wird derzeit nicht gebraucht, könnte aber in zukünftigen Versionen verwendet werden

## 5. Format

**Request:**

Die Kommunikation erfolgt im JSON-Format.
- Jeder Request sollte den Header `Accept: application/json` enthalten. Der Client signalisiert dadurch, dass er eine Antwort im JSON-Format erwartet.
- Bei Anforderungen mit Body (`POST`, `PUT`, `PATCH`) muss der `Content-Type` auf `application/json` gesetzt sein. `GET` und `DELETE` haben in der Regel keinen Body, daher ist dort kein `Content-Type` erforderlich.
- Bei Parametern und JSON-Keys wird zwischen Groß- und Kleinschreibung unterschieden.

**Response:**

- Der `Content-Type` der Antwort ist in der Regel `application/json`.
- Im Erfolgsfall (2xx) werden die Daten direkt im Body zurückgegeben.
- Im Fehlerfall (4xx, 5xx) wird ein JSON-Objekt mit folgenden Attributen zurückgegeben:
    - `error`: Kurze, standardisierte Fehlertext. 
    - `message`: Interne/entwicklerfreundliche Nachricht. Wird nur im Debug-Mode (`DEBUG=true`) an den Client gesendet.
    - `status`: HTTP-Statuscode. Wird nur im Debug-Mode (`DEBUG=true`) an den Client gesendet.

    Beispiel:
    ```
    {
       "error": "No query results for entity [User]."
    }
    ```

## 6. Datentypen

Die API akzeptiert JSON-Werte und gibt diese zurück.
Dies können Zeichenfolgen in Anführungszeichen, Zahlen, Objekten, Arrays, true, false oder null sein.

**Nummerische Werte**
Der standardmäßige numerische Typ in JavaScript, Python und PHP reicht aus, um Ganzzahlen der ID darzustellen.
Bei einer statischen Sprache wie C#, in der ganzzahlige Typen explizit deklariert werden, wird eine 64-Bit-Ganzzahl 
empfohlen (`long`-Typ statt `int`).

**Zeitangaben:**
Zeitangaben verwenden die UTC-Zeit mit einer Präzision von 3 Nachkommastellen.
Sie werden als ISO 8601 Zeichenketten formatiert dargestellt (mit 3 oder 6 Ziffern nach dem Sekunden-Teil).
- Beispiel: `2026-01-14T17:13:41.542Z`
- oder:`2026-01-14T17:13:41.542000Z`

## 7. Listen

Listen lassen sich - sofern bei [Endpunkte](#9-endpunkte) beschrieben - durch Angaben von GET-Parametern filtern und sortieren.

**Suche:**

Für Listenendpunkte kann Parameter `search` verwendet werden, um nur die Ressourcen aus der Gesamtmenge zu filtern,
bei denen mindestens ein Attribut den angegebenen Suchbegriff beinhaltet (ganz oder teilweise).

Beispiel:
```
https://{host}/api/users?search=foo \\
```

Es können auch mehrere Suchbegriffe mit einem Leerzeichen getrennt angegeben werden.
Es werden dann nur die Ressourcen herausgesucht, die alle genannten Suchbegriffe beinhalten.
Beachte, dass die Suchbegriffe URL-kodiert übertragen werden müssen, wodurch aus dem Leerzeichen ein Plus-Zeichen wird.

Beispiel:
```
https://{host}/api/users?search=foo+bar \\
```

**Pagination:**

Die Anzahl der Einträge pro Seite kann mit Parameter `per_page` bestimmt werden.
Die abzufragende Seite wird mit Parameters `page` angegeben. Die Zählung der Seiten beginnt bei 1.

Beispiel:
```
https://{host}/api/users?per_page=50&page=3 \\
```

Ein Listenendpunkt könnte limitiert sein. In dem Fall ist die maximale Anzahl Einträge pro Seite dokumentiert.
Wenn nicht alle der angefragten Einträge übermittelt wurden, wird der Statuscode 206 gesetzt (statt 200).

**Sortierung:**

Listen können durch den Parameter `sort_by` sortiert werden.
Als Wert wird ein Attribut der abgefragten Ressource erwartet.
Die Sortierrichtung kann mit `sort_order=desc` bzw. `sort_order=asc` angeben werden.

Beispiel:
```
https://{host}/api/users?sort_by=phone&sort_order=desc \
```

**Antwort:**

Die Antwort von Listenendpunkten besteht aus folgenden Attributen:

-   `items`: Die Liste mit den angefragten Resourcen.
- Optional (falls Parameter `per_page` gegeben ist oder bei Statuscode 206):
    -   `current_page`: Die Nummer der aktuellen Seite.
    -   `last_page`: Die Nummer der letzten Seite.
    -   `per_page`: Die Anzahl der Listeneinträge pro Seite.
    -   `total`: Die Anzahl aller Listeneinträge.

Beispiel:

```
Status: 206 Partial Content
{
  "items": [
    /* list of resources */
  ],
  "current_page": 2,
  "last_page":    3,
  "per_page":     10,
  "total":        23
}
```

## 8. Bulk-Aktionen

Ein Bulk-Endpunkt verarbeitet in einem Request mehrere Ressourcen einer Collection.

* Sync:
  `sync` ist eine Bulk-Aktion auf der Collection `entries` des Benutzers.
  - `GET /users/{user_uuid}/entries/sync` liefert alle seit `since` geänderten Entries sowie Löschungen.
  - `POST /users/{user_uuid}/entreis/sync` wendet ein Batch von Änderungen und Löschungen auf dem Server an (Last-Write-Wins).

## 9. Endpunkte

| Resource   | HTTP-Verb  | Endpunkt                        | RSA-Schutz | Parameter                                                                                                                                                                                                                                                 | Antwort bei Erfolg                                                                                                                                                                                                                                                           | Beschreibung                                                                  |
|------------|------------|---------------------------------|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------| 
| version    | GET        | /version                        | nein       |                                                                                                                                                                                                                                                           | (200) { service: "PriVault", sync_protocol_version, min_sync_protocol_version }                                                                                                                                                                                              | Liefert die API-Version und die minimal erforderliche Client-Minor-Version.   |
| user       | GET        | /users/{user_uuid}              | nein       |                                                                                                                                                                                                                                                           | (200) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? }                                                                                                                                                                      | Liefert die Benutzerdaten anhand seiner UUID.                                 |
|            | GET        | /users                          | nein       | QUERY: vault_hash, user_hash                                                                                                                                                                                                                              | (200) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? } oder null                                                                                                                                                            | Sucht einen Benutzer in einem bestimmten Tresor anhand seines Namens-Hashes.  |
|            | POST       | /users                          | nein       | BODY: { user_uuid, vault_hash, user_hash, salt, public_key, encrypted_private_key }                                                                                                                                                                       | (201) { user_uuid, vault_uuid, user_hash, salt, public_key, encrypted_private_key, encrypted_friends? }                                                                                                                                                                      | Registriert einen neuen Benutzer im Tresor (legt den Tresor ggf. an).         |
|            | PUT        | /users/{user_uuid}/password     | ja         | BODY: { salt, encrypted_private_key }                                                                                                                                                                                                                     | (204) -                                                                                                                                                                                                                                                                      | Aktualisiert Salt und Private Key nach Änderung des Master-Passworts.         |
|            | PUT        | /users/{user_uuid}/friends      | ja         | BODY: { encrypted_friends }                                                                                                                                                                                                                               | (204) -                                                                                                                                                                                                                                                                      | Speichert die verschlüsselte Freundesliste des Benutzers.                     |
|            | GET        | /users/{user_uuid}/public_keys  | ja         |                                                                                                                                                                                                                                                           | (200) [{ user_uuid, public_key }, ... }]                                                                                                                                                                                                                                     | Liefert die öffentlichen RSA-Schlüssel aller Benutzer im Tresor.              |
| entry      | GET        | /users/{user_uuid}/entries/sync | ja         | QUERY: since (optional)                                                                                                                                                                                                                                   | (200) { updates: [{ entry_uuid, encrypted_data, encrypted_key, access_level, attachment_uuids, friends: [{ user_uuid, encrypted_key, access_level }, ...], creator_uuid, updater_uuid, updated_at }, ...],<br/>deletes: [{ entry_uuid, deleted_at }, ...],<br/>server_time } | Bulk-Aktion: Liefert alle Änderungen seit der letzten Synchronisation (Pull). |
|            | POST       | /users/{user_uuid}/entries/sync | ja         | BODY: { updates: [{ entry_uuid, encrypted_data, encrypted_key, access_level, attachment_uuids, friends: [{user_uuid, encrypted_key, access_level}, ...], creator_uuid, updater_uuid, updated_at }, ...],<br/>deletes: [{ entry_uuid, deleted_at }, ...] } | (204) -                                                                                                                                                                                                                                                                      | Bulk-Aktion: Synchronisiert clientseitige Änderungen (Push).                  |
| attachment | GET        | /attachments/{attachment_uuid}  | ja         |                                                                                                                                                                                                                                                           | (200) { attachment_uuid, entry_uuid, encrypted_meta, encrypted_content }                                                                                                                                                                                                     | Lädt die verschlüsselten Metadaten und den Inhalt eines Anhangs.              |
|            | PUT        | /attachments/{attachment_uuid}  | ja         | BODY: { entry_uuid, encrypted_meta, encrypted_content }                                                                                                                                                                                                   | (204) -                                                                                                                                                                                                                                                                      | Speichert einen neuen Anhang (Metadaten & Inhalt) auf dem Server.             |
| vault      | DELETE     | /vaults                         | nein       | QUERY: vault_hash                                                                                                                                                                                                                                         | (204) -                                                                                                                                                                                                                                                                      | Löscht einen Test-Tresor und bereinigt veraltete Test-Tresore.                |


Alle Attribute sind verpflichtend, sofern nicht ausdrücklich als "optional" gekennzeichnet.

## 10. Tests

Mit `X-Test` im Request-Header schaltet der Server in den Test-Betrieb.  
Die Daten können dann durch DELETE /test wieder gelöscht werden.

Mit `X-Coverage` im Header wird der Request für einen Code-Coverage-Report protokolliert.

# Anhang

## A1. Endpunkte einer RESTful-Resource

**Leitlinien für den Endpunkt-Name:**

- Der Pfad setz sich zusammen aus:
    - Collection/Ressourcensammlung (Substantiv, keine Verben),
    - optional Ressourcen-ID/UUID
    - optional Subresource (z.B. /password oder changes)
      `/users`, `/users/{id}` statt `/register`, `/user/id={id}`.
- Filter in Query.
- HTTP-Methoden semantisch nutzen:
    - GET liest eine Ressource aus einer Collection.
    - POST legt eine neue Ressource in einer Collection an.
    - PATCH ersetzt einige (bis alle) Attribute einer bestimmten Resource in einer Collection
    - PUT überschreibt eine Resource vollständig (erstellt sie, wenn nicht vorhanden) in einer Collection
    - DELETE löscht eine bestimmte Resource aus einer Collection

Ausnahme Bulk-Aktion:
Eine Bulk-Aktion ist ein Endpunkt, der mehrere Ressourcen in einem
Rutsch verarbeitet (liest, erstellt, ändert oder löscht).

Ich definiere:
`sync` ist eine Bulk-Aktion auf die Collection `entries`.
Mit `GET \sync` liest man alle veränderten Einträge aus.
Mit `POST \sync` schreibt man alle veränderten Einträge.

| Method      | URI (Beispiel)    | Name (Beispiel)   |
|-------------|-------------------|-------------------|
| GET, HEAD   | api/v1/users      | api.users.index   |
| POST        | api/v1/users      | api.users.store   |
| GET, HEAD   | api/v1/users/{id} | api.users.show    |
| PATCH, PUT  | api/v1/users/{id} | api.users.update  |
| DELETE      | api/v1/users/{id} | api.users.destroy |

**GET vs. HEAD:**

`GET` fordert die Daten einer Resource (impliziert auch den Header)
`HEAD` fordert lediglich den Header einer Resource.

Wir verwenden nur `GET`

**PATCH vs. PUT:**

* `PATCH` ersetzt partial, also nur die übermittelten Attribute.
* `PUT` überschreibt alle Attribute der Resource. Falls die Resource nicht existiert, wird sie erstellt.

**Method Override:**

HTML-Formulare unterstützen nativ nur die Methoden `GET` und `POST`.
Methoden wie `PUT`, `PATCH` oder `DELETE` sind im Standard‑Formular nicht direkt möglich.

Lösung: Innerhalb des Formulars gibst du ein verstecktes Feld an, das die gewünschte Methode enthält:

```html
<form action="/users/42" method="POST">
    <input type="hidden" name="_method" value="DELETE">
    <button type="submit">Löschen</button>
</form>
```

**Routen der HTML-Formulare:**

Diese Routen gehören nicht zur API.
Es sind die Standardrouten, mit denen die HTML-Formulare für eine Resource aufgerufen werden können.

| Method     | URI             | Name         |
|------------|-----------------|--------------|
| GET, HEAD  | users/create    | users.create |
| GET, HEAD  | users/{id}/edit | users.edit   |
| GET, HEAD  | users/{id}/copy | users.copy   |


## A2. Glossar

* **Resource**: Repräsentiert etwas, das über die API über eine ID adressierbar ist.
  Die Daten eines einzelnen Benutzers sind z.B. eine Resource.
* **Entity**, **Model**: Ist die konkrete Instanz einer Resource – also ein einzelnes Objekt mit seinen Daten.
  Frank ist z.B. eine Entität der Resource "User". Er hat **Attrribute** (z.B. `id`, `name`).
